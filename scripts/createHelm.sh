#!/bin/bash

##########################################################################
# Obj: O objetivo desse cript é automatizar o processo de adaptação dos recursos do Openshift para Helm, facilitando não só a adaptação para Helm mas o Deploy em Si da demanda de migração de Cluster
#       - Login no Openshift
#       - Coleta de saida de recursos YAML
#       - Tratamento e criação do values.yaml
#       - Clone do repositorio, ajuste de manifestos e pipeline
#       - Criação de branch de Deploy
#       - Push da branch de Deploy
#       - Pull Request (Trigger de CI)
# Req:
#	- tkn = Token do Openshift 
#	- az_tkn = PAT do Azure Devops
#	- Executar de uma maquina Agente (HML)
# By: Bruno Miquelini (bruno.santos@yaman.com.br)
# Data: 28/06/2024
#########################################################################

set +x # Desabilita saida em modo debug devido a valores senciveis
tkn=
oc_api=https://api.btvnd2hmlocp04.ops.hom.corp.btb:6443
az_project=""
dc_name=""
namespace=""
branch="master"
output_values="values.yaml"

urlencode() {
    local encoded
    encoded=$(jq -rn --arg v "$1" '$v|@uri')
    echo "$encoded"
}

bar() {
  echo
  echo
  echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
}
usage() {
    echo "##############################################################################################################################"
    echo "[!!] Ajuda de como utilizar a automação..."
    echo "Uso: $0 -a <azure_project> -d <dc_name> -n <namespace> [-b <branch>]"
    echo "      [!!] Branch default é a master, caso de falhas no build, verificar a ultima branch que foi aplicada com sucesso!"
    echo
    echo "azure_project = Projeto do Azure Devops"
    echo "dc_name = Nome do DeploymentConfig (Normalmente mesmo nome do repo)"
    echo "namespace = Namespace/Projeto do openshift que será aplicado"
    echo "branch [Opcional] = Nome da branch que o clone irá se basear para adaptação"
    echo "##############################################################################################################################"
    exit 1
}

login() {
    echo "##############################################################################################################################"
    bar
    echo "[+] Fazendo login no cluster $oc_api"
    set +x
    if oc login --server=$oc_api --token=$tkn ; then
      bar
      echo "  [!!] Login realizado com sucesso!"
    else
      bar
      echo "  [-] Falha ao realizar login no Openshift"
      exit 1
      bar
    fi
}

# Coletando as infomrações dos manifestos do cluster para comparação com o values.yaml
fetch_dc_and_hpa() {
    bar
    echo "[+] Coletando informações dos manifestos para adaptação..."
    oc get dc "$dc_name" -n "$namespace" -o yaml > dc_full.yaml
    oc get hpa "$dc_name" -n "$namespace" -o yaml > hpa_full.yaml

    container_port=$(yq e '.spec.template.spec.containers[0].ports[0].containerPort' dc_full.yaml)
    resources_limits_cpu=$(yq e '.spec.template.spec.containers[0].resources.limits.cpu' dc_full.yaml)
    resources_limits_memory=$(yq e '.spec.template.spec.containers[0].resources.limits.memory' dc_full.yaml)
    resources_requests_cpu=$(yq e '.spec.template.spec.containers[0].resources.requests.cpu' dc_full.yaml)
    resources_requests_memory=$(yq e '.spec.template.spec.containers[0].resources.requests.memory' dc_full.yaml)
    hpa_min_replicas=$(yq e '.spec.minReplicas' hpa_full.yaml)
    hpa_max_replicas=$(yq e '.spec.maxReplicas' hpa_full.yaml)

    {
        echo "projectName: $dc_name"
        echo "namespace: \"$namespace\""
        echo "dockerRegistry: default-route-openshift-image-registry.apps.btvnd2hmlocp04.ops.hom.corp.btb"
        echo "containerPort: $container_port"
        echo "hostSuffix: apps.hom.corp.btb"
        echo "commonLabels: {}"
        echo "commonAnnotations: {}"
        echo "nodeSelector: {}"
        echo "resources:"
        echo "  limits:"
        echo "    cpu: $resources_limits_cpu"
        echo "    memory: $resources_limits_memory"
        echo "  requests:"
        echo "    cpu: $resources_requests_cpu"
        echo "    memory: $resources_requests_memory"
        echo "#HPA"
        echo "replicas:"
        echo "  min: $hpa_min_replicas"
        echo "  max: $hpa_max_replicas"
        echo "metrics:"
        echo "  cpu:"
        echo "    enabled: true"
        echo "    averageUtilization: 80"
        echo "secrets:"
        yq e '.spec.template.spec.containers[0].env[] | select(.valueFrom.secretKeyRef) | "- name: " + .name + "\n  secretKeyRef:\n      key: " + .valueFrom.secretKeyRef.key + "\n      name: " + .valueFrom.secretKeyRef.name' dc_full.yaml
        echo "environment:"
        yq e '.spec.template.spec.containers[0].env[] | select(.value) | "- name: " + .name + "\n  value: \"" + .value + "\""' dc_full.yaml
    } | sed 's/\\n/\n/g' > "$output_values"
       bar
       echo "[+] Arquivo values.yaml criado com sucesso!"
}

# Fazer o patch da label e dos annotations que permitem os recursos atuais a serem gerenciados pelo Helm nos tres recursos (route, svc e dc)
patch_resources() {
    bar
    echo "[+] Fazendo patch das labels Helm no DC"
    oc patch dc "$dc_name" -n "$namespace" --type=json -p='[{"op": "add", "path": "/metadata/labels", "value": {"app.kubernetes.io/managed-by": "Helm"}}]i'
    oc patch dc "$dc_name" -n "$namespace" --type=json -p="[{'op': 'add', 'path': '/metadata/annotations/meta.helm.sh~1release-name', 'value': '$dc_name'}]"
    oc patch dc "$dc_name" -n "$namespace" --type=json -p="[{'op': 'add', 'path': '/metadata/annotations/meta.helm.sh~1release-namespace', 'value': '$namespace'}]"
    bar
    echo "[+] Fazendo patch das labels Helm no HPA"
    oc patch hpa "$dc_name" -n "$namespace" --type=json -p='[{"op": "add", "path": "/metadata/labels", "value": {"app.kubernetes.io/managed-by": "Helm"}}]'
    oc patch hpa "$dc_name" -n "$namespace" --type=json -p="[{'op': 'add', 'path': '/metadata/annotations/meta.helm.sh~1release-name', 'value': '$dc_name'}]"
    oc patch hpa "$dc_name" -n "$namespace" --type=json -p="[{'op': 'add', 'path': '/metadata/annotations/meta.helm.sh~1release-namespace', 'value': '$namespace'}]"
    bar
    echo "[+] Fazendo patch das labels Helm no SVC"
    oc patch svc "$dc_name" -n "$namespace" --type=json -p='[{"op": "add", "path": "/metadata/labels", "value": {"app.kubernetes.io/managed-by": "Helm"}}]'
    oc patch svc "$dc_name" -n "$namespace" --type=json -p="[{'op': 'add', 'path': '/metadata/annotations/meta.helm.sh~1release-name', 'value': '$dc_name'}]"
    oc patch svc "$dc_name" -n "$namespace" --type=json -p="[{'op': 'add', 'path': '/metadata/annotations/meta.helm.sh~1release-namespace', 'value': '$namespace'}]"
    echo "[+] Fazendo patch das labels Helm no ROUTE"
    oc patch route "$dc_name" -n "$namespace" --type=json -p='[{"op": "add", "path": "/metadata/labels", "value": {"app.kubernetes.io/managed-by": "Helm"}}]'
    oc patch route "$dc_name" -n "$namespace" --type=json -p="[{'op': 'add', 'path': '/metadata/annotations/meta.helm.sh~1release-name', 'value': '$dc_name'}]"
    oc patch route "$dc_name" -n "$namespace" --type=json -p="[{'op': 'add', 'path': '/metadata/annotations/meta.helm.sh~1release-namespace', 'value': '$namespace'}]"
}

# Clona o repositorio que será ajustado e configura
clone_and_setup_repo() {
    set +x
    if [ -z "$az_tkn" ]; then
        bar
        echo "[-] az_tkn não definido. Não é possível clonar o repositório."
        echo "export az_tkn=<PAT>"
        exit 1
    fi

    url_safe_project=$(urlencode "$az_project")
    set +x
    repo_url="https://$az_tkn@dev.azure.com/bancotoyota/$url_safe_project/_git/$dc_name"

    bar
    if [[ -d $dc_name ]] ; then
      bar
      echo "[!!] Diretorio $dc_name ja existe!"
      echo "  - Verifique se quer remover e atualizar, e rode novamente o script..."
      echo "  - rm -rf $dc_name"
      bar
      exit 1
    fi
    echo "[+] Clonando o repositorio $dc_name ..."
    set +x
    git clone -b $branch $repo_url --single-branch
    cd $dc_name || exit
    bar
    echo "[+] Criando a branch feature/oc-deploy-helm"
    git checkout -b feature/oc-deploy-helm

    mkdir -p charts/hml charts/prd
    mv "../$output_values" charts/hml/

    bar
    echo "[+] Criando manifesto do Azure Pipelines..."
    find . -name "azure*" -type f -delete

    if find . -name "pom.xml" -print -quit | grep -q "^"; then
        echo "  [!!] JAVA"
        cat > azure-pipelines.yml << EOF
resources:
  repositories:
  - repository: templates
    type: git
    name: Devops-Corporativo/templates-ci
    ref: feature/oc-deploy-helm

trigger:
- '*'

stages:
- template: pipeline.yaml@templates
  parameters:
    BuildType: Container
    PathDockerfile: source/Dockerfile
    Veracode: Yes
EOF
    elif find . -name "package.json" -print -quit | grep -q "^"; then
        package_json_path=$(find . -name "package.json" -print -quit)
        node_version=$(jq -r '.devDependencies["@types/node"]' "$package_json_path")
        echo "[!!] Node $node_version"
        cat > azure-pipelines.yml << EOF
resources:
  repositories:
  - repository: templates
    type: git
    name: Devops-Corporativo/templates-ci
    ref: feature/oc-deploy-helm

trigger:
- '*'

stages:
- template: pipeline.yaml@templates
  parameters:
    BuildType: Container
    PathDockerfile: Dockerfile
    Veracode: Yes
    nodeVersion: '$node_version'
    Language: Js
EOF
    fi
    bar
    echo "[+] Configurando git para fazer o push corretamente..."

    git config user.name "Host $HOSTNAME"
    git config user.email "$USER@$HOSTNAME.local"
    git status
    bar
    echo "[+] Fazendo o track dos arquivos..."
    git add .
    git status
    git commit -m "[add] Adicionando configuração de Helm e pipelines para deploy OCS"
    bar
    echo "[+] Fazendo o push das modificações para o repositorio..."
    git push --set-upstream origin feature/oc-deploy-helm
}

# Processando informações necessarias (Variaveis)
while getopts "a:d:n:b:" opt; do
    case $opt in
        a) az_project="$OPTARG" ;;
        d) dc_name="$OPTARG" ;;
        n) namespace="$OPTARG" ;;
        b) branch="$OPTARG" ;;
        *) usage ;;
    esac
done

# Cria pull request para a branch Master
create_pull_request() {
    url_safe_project=$(urlencode "$az_project")
    repo_id=$(curl -s -u ":$az_tkn" "https://dev.azure.com/bancotoyota/$url_safe_project/_apis/git/repositories/$dc_name?api-version=6.0" | jq -r '.id')

    pr_data=$(jq -n \
        --arg sourceBranch "refs/heads/feature/oc-deploy-helm" \
        --arg targetBranch "refs/heads/master" \
        --arg title "Deploy manifestos Helm Openshift da branch feature/oc-deploy-helm na branch master (new Openshift HML)" \
        --arg description "Pull request feature/oc-deploy-helm (new Openshift HML)" \
        '{
            "sourceRefName": $sourceBranch,
            "targetRefName": $targetBranch,
            "title": $title,
            "description": $description
        }')

    response=$(curl -s -u ":$az_tkn" -X POST -H "Content-Type: application/json" \
        -d "$pr_data" \
        "https://dev.azure.com/bancotoyota/$url_safe_project/_apis/git/repositories/$repo_id/pullrequests?api-version=6.0")

    pr_id=$(echo "$response" | jq -r '.pullRequestId')
    if [ "$pr_id" != "null" ]; then
        pr_url=$(echo "$response" | jq -r '.url')
        bar
        echo "[+] Pull request criado com sucesso: $pr_url"
    else
        response=$(echo $response | jq .message)
        bar
        echo "[-] Falha ao criar o pull request. Resposta da API: $response"
        exit 1
    fi
}

if [ -z "$az_project" ] || [ -z "$dc_name" ] || [ -z "$namespace" ]; then
    usage
fi

login
if fetch_dc_and_hpa; then
    clone_and_setup_repo
    patch_resources
    echo "[+] Realizado ajustes com sucesso!"
    echo "################################################################"
    bar
    echo "[+] Criando Pull Request para a branch master..."
    create_pull_request
    echo "[+] Execução concluida! "
    echo "  [!!] Valide o build e crie o taskgroup, não esquecendo de habilitar o uso do AccessToken no agente!"
    echo "  Boa Sorde!   _\/_"
    bar
else
    bar
    echo "[-] Falha ao realizar todos os passos da adaptação"
    echo "################################################################"
fi
