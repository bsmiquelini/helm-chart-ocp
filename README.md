
# Helm Chart para Deploy de Aplicações em OpenShift criado pela YAMAN

## Introdução

Este repositório contém um Helm Chart configurável para o deploy de aplicações em clusters OpenShift. O objetivo deste chart é facilitar o processo de deploy de aplicações, fornecendo uma estrutura flexível e reutilizável que pode ser clonada e utilizada em pipelines de CI/CD, especificamente no Azure DevOps. O chart suporta a configuração de vários recursos, como DeploymentConfig, HorizontalPodAutoscaler, Service e Route, permitindo uma personalização completa através de um arquivo `values.yaml`.

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
  │   ├── deployment.yaml
  │   ├── hpa.yaml
  │   ├── route.yaml
  │   └── service.yaml
  ├── Chart.yaml
  ├── values.yaml
  └── ReadMe.md
```

## Utilização

### Pré-requisitos

- Helm instalado.
- Acesso a um cluster OpenShift.
- Azure DevOps configurado para clonar o repositório durante o pipeline.
- Para adicionar na pipeline habilitar no `Agent Job` a opção para acessar o `AccessToken`
- Desabilitar no projeto a restrição de limitar acesso a repositorios das pipelines de Releases

### Scripts de Apoio

TaskGroup que suporta o Helm
- scripts/Deploy-Openshift-HELM.json

Script para criação automatica do Taskgroup
- scripts/createTaskGroup.sh

Script para gerar o manifesto values.yaml do Helm
- scripts/createHelm.sh


### Passos para Deploy

*** Ajustar os manifestos atuais para suportar o Helm
```
metadata:
  labels:
    app.kubernetes.io/managed-by: Helm
  annotations:
    meta.helm.sh/release-name: corretora-institucional
    meta.helm.sh/release-namespace: corretora-seguros
```


1. **Clone o repositório no pipeline de release:**

   Configure seu pipeline no Azure DevOps para clonar este repositório. No seu arquivo de pipeline, adicione um passo para clonar o repositório.

   ```yaml
   - script: git clone https://bancotoyota@dev.azure.com/bancotoyota/Devops-Corporativo/_git/helm-charts

     displayName: 'Clonar repositório do Helm Chart'
   ```

2. **Configurar o `values.yaml` do ambiente:**

   Dependendo do ambiente (hml ou prd), utilize o `values.yaml` correspondente que pode ser baseado  no values.yaml do repositorio de charts mencionado acima.

   ```yaml
   - script: helm upgrade --install $(Build.Repository.Name) ./helm-charts -f ./charts/$(Release.EnvironmentName)/values.yaml
     displayName: 'Deploy HML'
   ```

   ```yaml
   - script: helm upgrade --install $(Build.Repository.Name) ./my-chart -f ./charts/$(Release.EnvironmentName)/values.yaml
     displayName: 'Deploy PRD'
   ```

### Configuração do `values.yaml`

O arquivo `values.yaml` permite uma configuração detalhada e flexível. Aqui estão alguns dos valores configuráveis:

```yaml
projectName: app-deploy
namespace: ns
dockerRegistry: registry # URL do registry do openshift
replicas:
  min: 1
  max: 5
containerPort: 8080
targetPort: 8080
hostSuffix: example.com # Sulfixo do dominio que será utilizado

# Definição de limites e recursos solicitados pelo POD
resources:
  limits:
    cpu: 150m
    memory: 256Mi
  requests:
    cpu: 20m
    memory: 64Mi

# Possibilita o uso de variavel de ambientes
environment:
  - name: API_HOST
    value: 'http://corretora-business-corretora-seguros.apps.hom.corp.btb/corretora-seguros'

# Possibilita o uso de secrets pré existentes como variavel de ambiente
secrets:
  - name: SECURITY_OAUTH2_USERNAME
    secretKeyRef:
      key: SECURITY_OAUTH2_USERNAME
      name: username

# Possibilita o uso de HPA
# Quantidade minima e maxima dependerá da especificada no deploy e baseado no resoureces
metrics:
  cpu:
    enabled: true
    averageUtilization: 80 # Trigger
  memory:
    enabled: false
    averageUtilization: 80 # Trigger

# Toggles para habilitar ou não recursos
enableHPA: true
enableDeployment: true
enableRoute: true
enableService: true

# Possibilita sobrescrever API padrão nos manifestos
apiVersions:
  hpa: autoscaling/v1
  deploymentConfig: apps.openshift.io/v1
  route: route.openshift.io/v1
  service: v1

# Possibilita adicionar labels e annotações
commonLabels: {}
commonAnnotations: {}

# Possibilita segregar o workload por selector
nodeSelector: {}
```

### Recursos Suportados

- **DeploymentConfig**: Garante que a aplicação seja implantada com a configuração desejada, permitindo escalabilidade e gerenciamento de imagens.
- **HorizontalPodAutoscaler**: Ajusta automaticamente o número de pods em uma implantação com base na utilização de CPU e memória.
- **Service**: Expõe a aplicação dentro do cluster e facilita a comunicação entre diferentes componentes.
- **Route**: Expõe a aplicação externamente, permitindo o acesso via URL.

### ImageStream no OpenShift

Um `ImageStream` no OpenShift é uma forma de rastrear mudanças em uma imagem de contêiner. O `ImageStream` não contém a imagem em si, mas uma referência às imagens localizadas em um registro (interno ou externo). Quando uma nova imagem é adicionada ao `ImageStream`, as mudanças podem acionar novos builds ou deployments automaticamente, sendo que a cada push que é realizado e apontado para a tag lates (ou conforme configurada) será realizado um rollout dos pods.

É necessario a cada helm upgrade ou deploy da aplicação, realizar um trigger no ImageStream:
```
oc tag image:latest openshift_registry/image:-$(Build.BuildId)


```
Para usar o imageStream é necessario habilitar o recurso `enableImageStream`

### Benefícios do ImageStream

- **Facilidade de Integração**: Integra facilmente com pipelines de CI/CD.
- **Automatização**: Triggers automáticos para builds e deployments.
- **Gerenciamento Centralizado**: Facilita o gerenciamento de imagens de contêiner em diferentes ambientes (desenvolvimento, homologação, produção).

### Exemplo de Uso do Chart

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

Para facilitar os deploys, centralizar manifestos, flexibilizar funcionalidades e integrar com CI/CD, mantendo historico de releases no cluster, a utilização do Helm é muito importante.

## Maintainers
- **Bruno (YAMAN)**
