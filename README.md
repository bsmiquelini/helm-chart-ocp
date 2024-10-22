
# Helm Chart para Deploy de Aplicações em OpenShift

## Introdução

Este repositório contém um Helm Chart configurável para o deploy de aplicações em clusters OpenShift. O objetivo deste chart é facilitar o processo de deploy de aplicações, fornecendo uma estrutura flexível e reutilizável que pode ser clonada e utilizada em pipelines de CI/CD, especificamente no Azure DevOps. O chart suporta a configuração de vários recursos, como DeploymentConfig, HorizontalPodAutoscaler, Service, Route, PersistentVolumeClaim, entre outros, permitindo uma personalização completa através do arquivo `values.yaml`.

## Estrutura do Repositório

O repositório está organizado da seguinte forma:

```
my-chart/
  ├── charts/
  │   ├── hml/
  │   │   └── values.yaml
  │   ├── prd/
  │   │   └── values.yaml
  ├── templates/
  │   ├── _helpers.tpl
  │   ├── dc.yaml
  │   ├── hpa.yaml
  │   ├── route.yaml
  │   ├── service.yaml
  │   ├── is.yaml
  │   ├── pvc.yaml
  ├── scripts/
  │   ├── createTaskGroup.sh
  │   ├── getRepos.sh
  │   ├── createHelm.sh
  │   └── Deploy-Openshift-HELM.json
  ├── .git/
  ├── Chart.yaml
  ├── values.yaml
  └── README.md
```

## Pré-requisitos

- Helm instalado.
- Acesso a um cluster OpenShift.
- Azure DevOps configurado para clonar o repositório durante o pipeline.
- Para adicionar na pipeline habilitar no `Agent Job` a opção para acessar o `AccessToken`.
- Desabilitar no projeto a restrição de limitar acesso a repositorios das pipelines de Releases.

## Scripts de Apoio

### TaskGroup que suporta o Helm
- `scripts/Deploy-Openshift-HELM.json`

### Script para criação automática do Taskgroup
- `scripts/createTaskGroup.sh`


## Valores Configuráveis

O `values.yaml` fornece uma maneira de sobrescrever os valores padrão definidos no chart. Aqui estão alguns dos valores configuráveis importantes:

```yaml
# Esse arquivo values.yaml contem os valores defaults e pode ser utilizado como referencia para suas aplicações
# Adicionar o values.yaml no seu repositorio de aplicação, utilizando o seguinte padrão:
#   charts/<env>/values.yaml
#
projectName: deploy
namespace: "ns"
dockerRegistry: default-route-openshift-image-registry.apps.teste.com.br
#imageStreamName: 
replicas:
  min: 1
  max: 2
containerPort: 8080
hostSuffix: apps.teste.com.br
commonLabels: {}
commonAnnotations: {}
nodeSelector: {}

livenessProbe:
  enabled: false
  type: httpGet
  #command: []
  #failureThreshold: 3
  #path: /actuator/liveness
  #port: 8080
  #scheme: HTTP
  #initialDelaySeconds: 50
  #periodSeconds: 30
  #successThreshold: 1
  #timeoutSeconds: 30

readinessProbe:
  enabled: true
  type: httpGet
  # Baseado em comando....##
  #type: exec
  #command: ["/bin/sh", "-i", "-c", "echo 'Teste'" ]
  ###########################
  #failureThreshold: 3
  #path: /actuator/readiness
  #port: 8080
  #scheme: HTTP
  #initialDelaySeconds: 50
  #periodSeconds: 30
  #successThreshold: 1
  #timeoutSeconds: 30

resources:
  limits:
    cpu: 150m
    memory: 256Mi
  requests:
    cpu: 20m
    memory: 64Mi

secrets:
#  - name: SECURITY_OAUTH2_USERNAME
#  secretKeyRef:
#      key: SECURITY_OAUTH2_USERNAME
#      name: username
#  - name: SECURITY_OAUTH2_PASSWORD
#    secretKeyRef:
#      key: SECURITY_OAUTH2_PASSWORD
#      name: pwd-api

environment:
#  - name: API_HOST
#    value: 'http://teste.com

metrics:
  cpu:
    enabled: true
    averageUtilization: 80
  memory:
    enabled: false
    averageUtilization: 80

enableHPA: true
enableDeployment: true
enableRoute: true
enableService: true
enableImageStream: false
enablePVC: false
enableEmptyDir: false

apiVersions:
  hpa: autoscaling/v2
  deploymentConfig: apps.openshift.io/v1
  route: route.openshift.io/v1
  service: v1

VolumePersistence:
#  - name: pvc-name
#    mountPath: /mnt/arquivos
#    storageClassName: ocs-storagecluster-cephfs
#    #volName: volume-5pcuk

# Caso a aplicação use empty Dir
emptyDir:
#  - name: redis-1
#    mountPath: /data
#
strategy:
#  type: Rolling
#  rollingParams:
#    intervalSeconds: 1
#    maxSurge: 50%
#    maxUnavailable: 50%
#    timeoutSeconds: 6000
#    updatePeriodSeconds: 1

```

## Templates Disponíveis

### Helpers (templates/_helpers.tpl)

Este arquivo contém funções auxiliares que podem ser reutilizadas em outros templates. Por exemplo, a função `project.name` pode ser usada para obter o nome do projeto a partir dos valores fornecidos no `values.yaml`.

### DeploymentConfig (templates/dc.yaml)

O `dc.yaml` define o DeploymentConfig para a aplicação. Este template inclui a configuração dos contêineres, recursos, probes, entre outros.

#### Possibilidades de Configuração:

- **Replicas:** Número de réplicas para a aplicação.
- **Triggers:** Configuração dos triggers para atualizações de imagem e mudanças de configuração.
- **Containers:** Configuração dos contêineres, incluindo imagem, portas, recursos, variáveis de ambiente, e probes.
- **NodeSelector:** Seletores de nó para agendamento dos pods.

### Service (templates/svc.yaml)

O `svc.yaml` define o serviço para a aplicação. Este template expõe a aplicação internamente no cluster.

#### Possibilidades de Configuração:

- **Ports:** Configuração das portas do serviço.
- **Selectors:** Seletores para associar o serviço aos pods correspondentes.
- **Type:** Tipo de serviço (ClusterIP, NodePort, LoadBalancer).

### Route (templates/route.yaml)

O `route.yaml` define a rota para a aplicação. Este template expõe a aplicação externamente.

#### Possibilidades de Configuração:

- **Host:** Hostname da rota.
- **TLS:** Configuração de TLS para a rota.
- **Path:** Caminho para a rota.

### HorizontalPodAutoscaler (templates/hpa.yaml)

O `hpa.yaml` define o HorizontalPodAutoscaler para a aplicação. Este template escala automaticamente a aplicação com base na utilização de CPU e memória.

#### Possibilidades de Configuração:

- **MinReplicas:** Número mínimo de réplicas.
- **MaxReplicas:** Número máximo de réplicas.
- **Metrics:** Métricas para escalonamento (CPU, memória).

### PersistentVolumeClaim (templates/pvc.yaml)

O `pvc.yaml` define o PersistentVolumeClaim para a aplicação. Este template solicita armazenamento persistente para os pods.

#### Possibilidades de Configuração:

- **AccessModes:** Modos de acesso (ReadWriteOnce, ReadOnlyMany, ReadWriteMany).
- **Resources:** Requisições e limites de armazenamento.

### ImageStream (templates/is.yaml)

O `is.yaml` define o ImageStream para a aplicação. Este template gerencia as imagens de contêiner no OpenShift.

#### Possibilidades de Configuração:

- **Annotations:** Anotações para o ImageStream.
- **Tags:** Tags para a imagem.

## Exemplo de Uso do Chart

Aqui está um exemplo de como você pode usar este chart em um pipeline de Azure DevOps:

```yaml
trigger:
- main

pool:
  vmImage: 'ubuntu-latest'

steps:
- script: git clone https://your-repo-url.git
  displayName: 'Clonar repositório do Helm Chart'

- task: HelmInstaller@1
  inputs:
    helmVersionToInstall: 'latest'

- script: helm upgrade --install my-release ./my-chart -f ./my-chart/charts/hml/values.yaml
  displayName: 'Deploy para ambiente HML'
  condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')
```

Este arquivo de pipeline realiza o clone do repositório, instala o Helm e executa o deploy da aplicação usando o Helm Chart e o arquivo `values.yaml` específico para o ambiente de homologação.

## Possíveis Problemas

- Ajuste da versão do nodeVersion na pipeline baseado na versão correspondente do azure-pipelines.yaml da branch de origem.
- Ajuste da service account do Nexus no taskgroup do Helm.
- Ajustar o arquivo azure-pipelines.yml para azure-pipelines.yaml.

## Benefícios do ImageStream

- **Facilidade de Integração:** Integra facilmente com pipelines de CI/CD.
- **Automatização:** Triggers automáticos para builds e deployments.
- **Gerenciamento Centralizado:** Facilita o gerenciamento de imagens de contêiner em diferentes ambientes (desenvolvimento, homologação, produção).

## Maintainers

- **Bruno (YAMAN)**

