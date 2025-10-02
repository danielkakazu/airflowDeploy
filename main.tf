# Resource Group and Network
resource "azurerm_resource_group" "airflow" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "airflow" {
  name                = var.vnet_name
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.airflow.location
  resource_group_name = azurerm_resource_group.airflow.name
}

resource "azurerm_subnet" "aks" {
  name                 = "subnet-aks"
  resource_group_name  = azurerm_resource_group.airflow.name
  virtual_network_name = azurerm_virtual_network.airflow.name
  address_prefixes     = ["10.10.0.0/22"]
}

resource "azurerm_subnet" "db" {
  name                 = "subnet-db-private"
  resource_group_name  = azurerm_resource_group.airflow.name
  virtual_network_name = azurerm_virtual_network.airflow.name
  address_prefixes     = ["10.10.4.0/24"]
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.airflow.name
}

# PostgreSQL Flexible Server (private)
resource "azurerm_postgresql_flexible_server" "airflow_db" {
  name                = "airflow-metadb-postgresql"
  resource_group_name = azurerm_resource_group.airflow.name
  location            = azurerm_resource_group.airflow.location

  administrator_login    = var.db_admin_user
  administrator_password = var.db_admin_password
  version                = "16"

  sku_name   = "GP_Standard_D2ds_v5"
  storage_mb = 32768

  delegated_subnet_id = azurerm_subnet.db.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false

  authentication {
    password_auth_enabled = true
  }

  depends_on = [azurerm_subnet.db]
}

resource "azurerm_postgresql_flexible_server_database" "airflow_db_database" {
  name      = "airflow"
  server_id = azurerm_postgresql_flexible_server.airflow_db.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# AKS cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-airflow-prod"
  location            = azurerm_resource_group.airflow.location
  resource_group_name = azurerm_resource_group.airflow.name
  dns_prefix          = "airflow"

  default_node_pool {
    name                = "systempool"
    node_count          = 1
    vm_size             = "Standard_B2s"
    vnet_subnet_id      = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  kubernetes_version = "1.30.3"
}

resource "azurerm_kubernetes_cluster_node_pool" "workerpool" {
  name                  = "workerpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_D4s_v3"
  node_count            = 0
  auto_scaling_enabled  = true
  min_count             = 0
  max_count             = 5
  mode                  = "User"

  node_taints = ["workload=worker:NoSchedule"]
}

# Public IP (in AKS node resource group)
resource "azurerm_public_ip" "airflow_web" {
  name                = "pip-airflow-web"
  location            = azurerm_resource_group.airflow.location
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Kubernetes namespace and secrets (using kubernetes provider configured from AKS kubeconfig)
resource "kubernetes_namespace" "airflow_ns" {
  metadata {
    name = "airflow"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

resource "kubernetes_secret" "airflow_db_secret" {
  provider = kubernetes.aks

  metadata {
    name      = "airflow-db-secret"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }

  data = {
    connection = base64encode("postgresql://${var.db_admin_user}:${var.db_admin_password}@${azurerm_postgresql_flexible_server.airflow_db.fqdn}:5432/airflow")
  }

  depends_on = [kubernetes_namespace.airflow_ns]
}

resource "kubernetes_secret" "airflow_ssh_secret" {
  provider = kubernetes.aks

  metadata {
    name      = "airflow-ssh-secret"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }

  data = {
    gitSshKey = base64encode(var.ssh_private_key)
  }

  depends_on = [kubernetes_namespace.airflow_ns]
}

resource "kubernetes_secret" "airflow_ssh_knownhosts" {
  provider = kubernetes.aks

  metadata {
    name      = "airflow-ssh-knownhosts"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }

  data = {
    knownHosts = base64encode("github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=")
  }

  depends_on = [kubernetes_namespace.airflow_ns]
}

# Helm release for Airflow
resource "helm_release" "airflow" {
You said:
crie e estruture todos esses comando no Terraform para executar no HCP
az group create \
  --name rg-airflow-prod \
  --location centralus

az network vnet create \
  --resource-group rg-airflow-prod \
  --name vnet-airflow \
  --address-prefixes 10.10.0.0/16

az network vnet subnet create \
  --resource-group rg-airflow-prod \
  --vnet-name vnet-airflow \
  --name subnet-aks \
  --address-prefixes 10.10.0.0/22

az network vnet subnet create \
  --resource-group rg-airflow-prod \
  --vnet-name vnet-airflow \
  --name subnet-db-private \
  --address-prefixes 10.10.4.0/24

az network private-dns zone create \
  --resource-group rg-airflow-prod \
  --name "privatelink.postgres.database.azure.com"

az postgres flexible-server create \
  --resource-group rg-airflow-prod \
  --name airflow-metadb-postgresql \
  --location centralus \
  --admin-user airflow_user \
  --admin-password "airflow_pass" \
  --sku-name Standard_D2ds_v5 \
  --tier GeneralPurpose \
  --version 16 \
  --storage-size 32 \
  --high-availability Disabled \
  --vnet vnet-airflow \
  --subnet subnet-db-private \
  --private-dns-zone "privatelink.postgres.database.azure.com" \
  --database-name airflow


az aks create \
  --resource-group rg-airflow-prod \
  --name aks-airflow-prod \
  --node-count 1 \
  --node-vm-size Standard_B2s \
  --enable-addons monitoring \
  --network-plugin azure \
  --vnet-subnet-id $(az network vnet subnet show --resource-group rg-airflow-prod --vnet-name vnet-airflow --name subnet-aks --query id -o tsv) \
  --enable-managed-identity \
  --kubernetes-version 1.30.3 \
  --generate-ssh-keys \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 1 \
  --nodepool-name systempool
  
  
az aks nodepool add \
  --resource-group rg-airflow-prod \
  --cluster-name aks-airflow-prod \
  --name workerpool \
  --node-vm-size Standard_D4s_v3 \
  --node-count 0 \
  --enable-cluster-autoscaler \
  --min-count 0 \
  --max-count 5 \
  --mode User \
  --node-taints workload=worker:NoSchedule
  
  
  az aks get-credentials \
  --resource-group rg-airflow-prod \
  --name aks-airflow-prod



kubectl create secret generic airflow-db-secret \
  --namespace airflow \
  --from-literal=connection="postgresql://airflow_user:airflow_pass@airflow-metadb-postgresql.postgres.database.azure.com:5432/airflow"


helm repo add apache-airflow https://airflow.apache.org
helm repo update


az network public-ip create \
  --resource-group MC_rg-airflow-prod_aks-airflow-prod_centralus \
  --name pip-airflow-web \
  --sku Standard \
  --allocation-method Static

az network public-ip show -g MC_rg-airflow-prod_aks-airflow-prod_centralus -n pip-airflow-web --query ipAddress -o tsv


kubectl create namespace airflow

kubectl get secret airflow-db-secret -n airflow \
  -o jsonpath="{.data.connection}" | base64 --decode

kubectl patch svc airflow-webserver -n airflow -p '{"spec":{"type":"LoadBalancer","loadBalancerIP":"135.119.50.30"}}'

kubectl create secret generic airflow-ssh-knownhosts \
  --from-literal=knownHosts="$(ssh-keyscan github.com)" \
  --namespace airflow

helm upgrade --install airflow apache-airflow/airflow \
  --namespace airflow \
  --create-namespace \
  --version 1.16.0 \
  --set executor=KubernetesExecutor \
  --set postgresql.enabled=false \
  --set redis.enabled=false \
  --set data.metadataSecretName=airflow-db-secret \
  --set airflow.persistence.enabled=true \
  --set airflow.persistence.size=20Gi \
  --set images.airflow.repository=apache/airflow \
  --set images.airflow.tag=2.10.5 \
  --set airflow.airflowVersion=2.10.5 \
  --set webserver.enabled=true \
  --set webserver.service.type=LoadBalancer \
  --set webserver.service.loadBalancerIP=135.119.50.30 \
  --set webserver.livenessProbe.initialDelaySeconds=60 \
  --set webserver.readinessProbe.initialDelaySeconds=60 \
  --set webserver.livenessProbe.failureThreshold=20 \
  --set webserver.readinessProbe.failureThreshold=20 \
  --set dags.gitSync.enabled=true \
  --set-string dags.gitSync.repo=git@github.com:danielkakazu/dags.git \
  --set dags.gitSync.branch=main \
  --set dags.gitSync.subPath="dags" \
  --set dags.gitSync.sshKeySecret=airflow-ssh-secret \
  --set-string dags.gitSync.knownHosts="$KNOWN_HOSTS" \
  --set executorConfig.nodeSelector.agentpool=workerpool \
  --set executorConfig.tolerations[0].key="workerpool" \
  --set executorConfig.tolerations[0].operator="Exists" \
  --set executorConfig.tolerations[0].effect="NoSchedule"
  
  

kubectl create secret generic airflow-ssh-secret \
  --from-literal=gitSshKey='-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACC46Ey1Qyjkl26NWAlG7v5VsayovUANpE6AyV88ookk8AAAAJhklC0MZJQt
DAAAAAtzc2gtZWQyNTUxOQAAACC46Ey1Qyjkl26NWAlG7v5VsayovUANpE6AyV88ookk8A
AAAEBjrAS5yAt4OmmiYE8sbg6V8FcIFnlWL6nEmir80YhcFLjoTLVDKOSXbo1YCUbu/lWx
rKi9QA2kToDJXzyiiSTwAAAAEGFpcmZsb3ctZ2l0LXN5bmMBAgMEBQ==
-----END OPENSSH PRIVATE KEY-----' \
  -n airflow
  
  
kubectl create secret generic airflow-ssh-knownhosts \
  --from-literal=knownHosts='github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=' \
  -n airflow 
ChatGPT said:

Ótimo pedido 🚀

Vou converter toda a sequência de comandos az cli + kubectl + helm em código Terraform estruturado para rodar no HCP Terraform (antigo Terraform Cloud).

A solução será dividida em módulos lógicos:

    Resource Group + Network

    Postgres Flexible Server

    AKS Cluster + Node Pools

    DNS + Public IP

    Kubernetes Secrets

    Helm Release do Airflow

Aqui está a primeira versão estruturada:
Terraform – Infraestrutura Airflow no Azure

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "azurerm" {
  features {}
}

# ------------------------------
# 1. Resource Group + Network
# ------------------------------
resource "azurerm_resource_group" "airflow" {
  name     = "rg-airflow-prod"
  location = "Central US"
}

resource "azurerm_virtual_network" "airflow" {
  name                = "vnet-airflow"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.airflow.location
  resource_group_name = azurerm_resource_group.airflow.name
}

resource "azurerm_subnet" "aks" {
  name                 = "subnet-aks"
  resource_group_name  = azurerm_resource_group.airflow.name
  virtual_network_name = azurerm_virtual_network.airflow.name
  address_prefixes     = ["10.10.0.0/22"]
}

resource "azurerm_subnet" "db" {
  name                 = "subnet-db-private"
  resource_group_name  = azurerm_resource_group.airflow.name
  virtual_network_name = azurerm_virtual_network.airflow.name
  address_prefixes     = ["10.10.4.0/24"]
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.airflow.name
}

# ------------------------------
# 2. PostgreSQL Flexible Server
# ------------------------------
resource "azurerm_postgresql_flexible_server" "airflow" {
  name                   = "airflow-metadb-postgresql"
  resource_group_name    = azurerm_resource_group.airflow.name
  location               = azurerm_resource_group.airflow.location
  administrator_login    = "airflow_user"
  administrator_password = "airflow_pass"
  version                = "16"

  sku_name   = "Standard_D2ds_v5"
  storage_mb = 32768
  zone       = "1"

  delegated_subnet_id = azurerm_subnet.db.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  high_availability {
    mode = "Disabled"
  }

  authentication {
    password_auth_enabled = true
  }

  depends_on = [azurerm_subnet.db]
}

resource "azurerm_postgresql_flexible_server_database" "airflow" {
  name      = "airflow"
  server_id = azurerm_postgresql_flexible_server.airflow.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# ------------------------------
# 3. AKS Cluster + Node Pools
# ------------------------------
resource "azurerm_kubernetes_cluster" "airflow" {
  name                = "aks-airflow-prod"
  location            = azurerm_resource_group.airflow.location
  resource_group_name = azurerm_resource_group.airflow.name
  dns_prefix          = "airflow"

  default_node_pool {
    name                = "systempool"
    node_count          = 1
    vm_size             = "Standard_B2s"
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 1
  }

  identity {
    type = "SystemAssigned"
  }

  kubernetes_version = "1.30.3"

  addon_profile {
    oms_agent {
      enabled = true
    }
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "workerpool" {
  name                  = "workerpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.airflow.id
  vm_size               = "Standard_D4s_v3"
  node_count            = 0
  enable_auto_scaling   = true
  min_count             = 0
  max_count             = 5
  mode                  = "User"

  node_taints = ["workload=worker:NoSchedule"]
}

# ------------------------------
# 4. Public IP para Airflow Web
# ------------------------------
resource "azurerm_public_ip" "airflow_web" {
  name                = "pip-airflow-web"
  location            = azurerm_resource_group.airflow.location
  resource_group_name = azurerm_kubernetes_cluster.airflow.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ------------------------------
# 5. Providers Kubernetes/Helm
# ------------------------------
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.airflow.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.airflow.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.airflow.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.airflow.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.airflow.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.airflow.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.airflow.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.airflow.kube_config[0].cluster_ca_certificate)
  }
}

# ------------------------------
# 6. Secrets no Kubernetes
# ------------------------------
resource "kubernetes_namespace" "airflow" {
  metadata {
    name = "airflow"
  }
}

resource "kubernetes_secret" "db" {
  metadata {
    name      = "airflow-db-secret"
    namespace = kubernetes_namespace.airflow.metadata[0].name
  }

  data = {
    connection = base64encode("postgresql://airflow_user:airflow_pass@${azurerm_postgresql_flexible_server.airflow.fqdn}:5432/airflow")
  }
}

resource "kubernetes_secret" "ssh_key" {
  metadata {
    name      = "airflow-ssh-secret"
    namespace = kubernetes_namespace.airflow.metadata[0].name
  }

  data = {
    gitSshKey = filebase64("${path.module}/id_rsa") # chave privada local
  }
}

resource "kubernetes_secret" "ssh_knownhosts" {
  metadata {
    name      = "airflow-ssh-knownhosts"
    namespace = kubernetes_namespace.airflow.metadata[0].name
  }

  data = {
    knownHosts = base64encode("github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=")
  }
}

# ------------------------------
# 7. Helm Chart Airflow
# ------------------------------
resource "helm_release" "airflow" {
  name       = "airflow"
  repository = "https://airflow.apache.org"
  chart      = "airflow"
  namespace  = kubernetes_namespace.airflow.metadata[0].name
  version    = "1.16.0"

  set {
    name  = "executor"
    value = "KubernetesExecutor"
  }

  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  set {
    name  = "redis.enabled"
    value = "false"
  }

  set {
    name  = "data.metadataSecretName"
    value = kubernetes_secret.db.metadata[0].name
  }

  set {
    name  = "airflow.persistence.enabled"
    value = "true"
  }

  set {
    name  = "airflow.persistence.size"
    value = "20Gi"
  }

  set {
    name  = "images.airflow.repository"
    value = "apache/airflow"
  }

  set {
    name  = "images.airflow.tag"
    value = "2.10.5"
  }

  set {
    name  = "airflow.airflowVersion"
    value = "2.10.5"
  }

  set {
    name  = "webserver.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "webserver.service.loadBalancerIP"
    value = azurerm_public_ip.airflow_web.ip_address
  }

  set {
    name  = "dags.gitSync.enabled"
    value = "true"
  }

  set {
    name  = "dags.gitSync.repo"
    value = "git@github.com:danielkakazu/dags.git"
  }

  set {
    name  = "dags.gitSync.branch"
    value = "main"
  }

  set {
    name  = "dags.gitSync.subPath"
    value = "dags"
  }

  set {
    name  = "dags.gitSync.sshKeySecret"
    value = kubernetes_secret.ssh_key.metadata[0].name
  }

  set {
    name  = "dags.gitSync.knownHosts"
    value = "github.com"
  }

  set {
    name  = "executorConfig.nodeSelector.agentpool"
    value = "workerpool"
  }
}

👉 Observações importantes:

    A chave SSH usada no secret airflow-ssh-secret deve estar salva em um arquivo (id_rsa) no diretório do módulo Terraform.

    O azurerm_kubernetes_cluster.airflow.node_resource_group é um RG gerado automaticamente pelo AKS (necessário para o Public IP).

    Os comandos kubectl patch foram substituídos por configuração direta no helm_release.

    Os secrets de banco e SSH estão sendo injetados pelo Terraform.

Você quer que eu também monte o pipeline HCP Terraform (workspace + variáveis sensíveis como senha do banco/SSH key) para você rodar isso direto no HCP?
You said:
sim por favor, e faça tudo isso gerando uma estrutura com arquivos zipados.
ChatGPT said:

Pronto — gerei a estrutura completa de arquivos Terraform + workflow e empacotei tudo num ZIP para você.

📦 Baixe o projeto (ZIP)

O ZIP contém:

    providers.tf, main.tf, variables.tf, outputs.tf

    terraform.tfvars.example (exemplo de variáveis)

    Kubernetes secrets criados via provider Kubernetes (injetados do var.ssh_private_key e var.db_admin_password)

    scripts/deploy_local.sh (helper para execução local)

    .github/workflows/ci.yml (GitHub Actions que usa Terraform Cloud / HCP)

    README.md e README-HCP-VARS.md com instruções para configurar o workspace no HCP e variáveis sensíveis

⚠️ Observações importantes (leia antes de aplicar):

    Substitua organization = "your-org" e workspaces.name em providers.tf pelo seu org/workspace no HCP.

    Não coloque segredos em repositórios públicos. Configure db_admin_password e ssh_private_key como sensitive variables no workspace do Terraform Cloud/HCP.

    O provider Kubernetes e Helm são configurados via kube_config do recurso azurerm_kubernetes_cluster. Se o fluxo for executar no HCP, a run do workspace precisa ter permissão/credenciais Azure (env vars AZURE_CLIENT_ID etc.) configuradas no workspace.

    Teste em um ambiente de dev antes de aplicar em produção (endereços IP, tamanhos de VM, tags e quotas podem precisar de ajuste).

Se quiser, eu:

    atualizo os arquivos para incluir módulos separados (network / db / aks) e outputs mais detalhados;

    adiciono um exemplo de .tfvars populado (com placeholders) ou importo a chave SSH que você usou anteriormente para dentro do projeto (colocando como arquivo);

    ou já crio o workspace no HCP pra você (preciso apenas do nome da organização e token TF API — não envie aqui se for sensível; em vez disso, posso fornecer o curl/gh/az cli exato para você executar).

O que prefere que eu faça agora?
You said:
Initializing HCP Terraform...
╷
│ Error: Terraform encountered problems during initialisation, including problems
│ with the configuration, described below.
│ 
│ The Terraform configuration must be valid before initialization so that
│ Terraform can determine which modules and providers need to be installed.
│ 
│ 
╵
╷
│ Error: Invalid expression
│ 
│   on main.tf line 264, in resource "helm_release" "airflow":
│  264:       set[?name=="webserver.service.loadBalancerIP"]
│ 
│ Expected the start of an expression, but found an invalid expression token.
╵
ChatGPT said:

Boa captura 👌

Esse erro vem da parte de lifecycle.ignore_changes no helm_release.
O que eu escrevi (set[?name=="webserver.service.loadBalancerIP"]) é sintaxe de filtro HCL2 inválida — Terraform não entende isso.

A forma correta de ignorar uma set { ... } do helm_release é ignorar pelo campo todo, não por sub-atributo.
Correção:

Troque este trecho no main.tf:

lifecycle {
  ignore_changes = [
    # prevent helm from forcing changes on dynamic fields like loadBalancer IP while AKS allocates it
    set[?name=="webserver.service.loadBalancerIP"]
  ]
}

por:

lifecycle {
  ignore_changes = [
    set
  ]
}

👉 Isso faz com que o Terraform não tente reconciliar qualquer mudança de set no chart (ou seja, se o Helm mudar algo em runtime, não dá conflito).
Se quiser ser mais granular (só para loadBalancerIP), a alternativa é não usar ignore_changes e deixar que o IP seja gerenciado pela Public IP do Azure, como já está configurado em azurerm_public_ip.airflow_web.

⚡ Resumindo:

    Abra main.tf.

    Encontre o recurso helm_release "airflow".

    Substitua o bloco lifecycle pelo corrigido acima.

Depois rode novamente:

terraform init -upgrade
terraform plan

Quer que eu já te gere uma versão corrigida do ZIP com esse ajuste pronto, para você baixar e testar direto?
You said:
Error: No value for required variable
on variables.tf line 21:
variable "db_admin_password" {
The root module input variable "db_admin_password" is not set, and has no default value. Use a -var or -var-file command line argument to provide a value for this variable.
Error: No value for required variable
on variables.tf line 27:
variable "ssh_private_key" {
The root module input variable "ssh_private_key" is not set, and has no default value. Use a -var or -var-file command line argument to provide a value for this variable.
ChatGPT said:

Perfeito 🚀 isso significa que o Terraform está reclamando de duas variáveis obrigatórias que você mesmo precisa fornecer:

    db_admin_password → senha do banco PostgreSQL (não tem default, precisa ser definida).

    ssh_private_key → chave privada usada para o GitSync do Airflow.

3 maneiras de resolver
1. Usando terraform.tfvars

Crie um arquivo terraform.tfvars na raiz do projeto com:

db_admin_password = "SenhaForteAqui123!"
ssh_private_key   = <<EOF
-----BEGIN OPENSSH PRIVATE KEY-----
cole sua chave privada aqui
-----END OPENSSH PRIVATE KEY-----
EOF

E depois rode normalmente:

terraform plan
terraform apply

2. Passando com -var

terraform apply \
  -var="db_admin_password=SenhaForteAqui123!" \
  -var="ssh_private_key=$(cat ~/.ssh/id_rsa)"

3. No HCP Terraform (Terraform Cloud)

No workspace que você criou no HCP:

    Vá em Variables → Terraform Variables

        Adicione db_admin_password (Sensitive = ✅)

        Adicione ssh_private_key (Sensitive = ✅)

⚠️ Nunca coloque esses valores direto nos arquivos versionados (commit) — só local ou no HCP com variáveis sensíveis.

👉 Depois que você adicionar essas variáveis, o erro desaparece e o Terraform conseguirá criar o PostgreSQL e os Secrets no Kubernetes.

Quer que eu prepare para você um terraform.tfvars já pronto (com placeholders) e gere um novo ZIP corrigido incluindo isso?
You said:
Error: "sku_name" is not a valid sku name, got Standard_D2ds_v5
with azurerm_postgresql_flexible_server.airflow_db
on main.tf line 43, in resource "azurerm_postgresql_flexible_server" "airflow_db":
  sku_name   = "Standard_D2ds_v5"
Error: expected high_availability.0.mode to be one of ["ZoneRedundant" "SameZone"], got Disabled
with azurerm_postgresql_flexible_server.airflow_db
on main.tf line 50, in resource "azurerm_postgresql_flexible_server" "airflow_db":
    mode = "Disabled"
Error: Unsupported block type
on main.tf line 90, in resource "azurerm_kubernetes_cluster" "aks":
  addon_profile {
Blocks of type "addon_profile" are not expected here.
Error: Unsupported argument
on main.tf line 79, in resource "azurerm_kubernetes_cluster" "aks":
    enable_auto_scaling = true
An argument named "enable_auto_scaling" is not expected here.
ChatGPT said:

Boa 👀 — você esbarrou em diferenças entre o CLI (az) e o provider Terraform azurerm.
Os argumentos que o CLI aceita não são exatamente os mesmos que o Terraform entende. Vou corrigir ponto por ponto:
1. PostgreSQL Flexible Server

No Terraform, o campo sku_name não usa a nomenclatura Standard_D2ds_v5.
Ele é composto assim:

{tier}_{family}_{cores}

Exemplo válido (equivalente a um D2ds v5 do CLI seria 2 vCores, General Purpose):

sku_name = "GP_Standard_D2ds_v5_2"

Mas a forma mais estável é usar um SKU suportado oficialmente no provider, tipo:

sku_name = "GP_Standard_D2s_v3_2"

⚠️ Sugiro você ajustar para algo mais seguro/testado, como GP_Standard_D2s_v3_2.
2. High Availability

No Terraform, não existe Disabled. Se não quiser HA, simplesmente não declara o bloco high_availability.

Ou seja, remova:

high_availability {
  mode = "Disabled"
}

3. AKS Addons

No azurerm_kubernetes_cluster, não existe mais addon_profile (foi deprectado).
O equivalente para habilitar Monitoramento é via oms_agent dentro de monitor_metrics ou habilitando oms_agent direto.

Exemplo atualizado:

oms_agent {
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
}

Se você não configurou Log Analytics, pode deixar esse bloco fora até criar o recurso.
4. Cluster Autoscaler

No Terraform, o autoscaler é configurado dentro do default_node_pool, não no cluster root.

Errado (o que você tinha):

resource "azurerm_kubernetes_cluster" "aks" {
  ...
  enable_auto_scaling = true
}

Certo:

default_node_pool {
  name                = "systempool"
  node_count          = 1
  vm_size             = "Standard_B2s"
  enable_auto_scaling = true
  min_count           = 1
  max_count           = 1
}

✅ Resumindo as correções que você precisa aplicar:

    Trocar sku_name = "Standard_D2ds_v5" → sku_name = "GP_Standard_D2s_v3_2".

    Remover o bloco high_availability se quiser sem HA.

    Apagar addon_profile { ... }.

    Mover enable_auto_scaling, min_count, max_count para dentro de default_node_pool.

Quer que eu já te entregue um novo ZIP corrigido com essas mudanças aplicadas no main.tf?
You said:
este ultimo erro do auto_scaling esta no default_node_pool, 
# Resource Group and Network
resource "azurerm_resource_group" "airflow" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "airflow" {
  name                = var.vnet_name
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.airflow.location
  resource_group_name = azurerm_resource_group.airflow.name
}

resource "azurerm_subnet" "aks" {
  name                 = "subnet-aks"
  resource_group_name  = azurerm_resource_group.airflow.name
  virtual_network_name = azurerm_virtual_network.airflow.name
  address_prefixes     = ["10.10.0.0/22"]
}

resource "azurerm_subnet" "db" {
  name                 = "subnet-db-private"
  resource_group_name  = azurerm_resource_group.airflow.name
  virtual_network_name = azurerm_virtual_network.airflow.name
  address_prefixes     = ["10.10.4.0/24"]
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.airflow.name
}

# PostgreSQL Flexible Server (private)
resource "azurerm_postgresql_flexible_server" "airflow_db" {
  name                = "airflow-metadb-postgresql"
  resource_group_name = azurerm_resource_group.airflow.name
  location            = azurerm_resource_group.airflow.location

  administrator_login    = var.db_admin_user
  administrator_password = var.db_admin_password
  version                = "16"

  sku_name   = "GP_Standard_D2ds_v5"
  storage_mb = 32768

  delegated_subnet_id = azurerm_subnet.db.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  authentication {
    password_auth_enabled = true
  }

  depends_on = [azurerm_subnet.db]
}

resource "azurerm_postgresql_flexible_server_database" "airflow_db_database" {
  name      = "airflow"
  server_id = azurerm_postgresql_flexible_server.airflow_db.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# AKS cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-airflow-prod"
  location            = azurerm_resource_group.airflow.location
  resource_group_name = azurerm_resource_group.airflow.name
  dns_prefix          = "airflow"

  default_node_pool {
    name                = "systempool"
    node_count          = 1
    vm_size             = "Standard_B2s"
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 1
  }

  identity {
    type = "SystemAssigned"
  }

  kubernetes_version = "1.30.3"
}

resource "azurerm_kubernetes_cluster_node_pool" "workerpool" {
  name                  = "workerpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_D4s_v3"
  node_count            = 0
  enable_auto_scaling   = true
  min_count             = 0
  max_count             = 5
  mode                  = "User"

  node_taints = ["workload=worker:NoSchedule"]
}

# Public IP (in AKS node resource group)
resource "azurerm_public_ip" "airflow_web" {
  name                = "pip-airflow-web"
  location            = azurerm_resource_group.airflow.location
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Kubernetes namespace and secrets (using kubernetes provider configured from AKS kubeconfig)
resource "kubernetes_namespace" "airflow_ns" {
  metadata {
    name = "airflow"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

resource "kubernetes_secret" "airflow_db_secret" {
  metadata {
    name      = "airflow-db-secret"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }

  data = {
    connection = base64encode("postgresql://${var.db_admin_user}:${var.db_admin_password}@${azurerm_postgresql_flexible_server.airflow_db.fqdn}:5432/airflow")
  }

  depends_on = [kubernetes_namespace.airflow_ns]
}

resource "kubernetes_secret" "airflow_ssh_secret" {
  metadata {
    name      = "airflow-ssh-secret"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }

  data = {
    gitSshKey = base64encode(var.ssh_private_key)
  }

  depends_on = [kubernetes_namespace.airflow_ns]
}

resource "kubernetes_secret" "airflow_ssh_knownhosts" {
  metadata {
    name      = "airflow-ssh-knownhosts"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }

  data = {
    knownHosts = base64encode("github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=")
  }

  depends_on = [kubernetes_namespace.airflow_ns]
}

# Helm release for Airflow
resource "helm_release" "airflow" {
  name       = "airflow"
  repository = "https://airflow.apache.org"
  chart      = "airflow"
  namespace  = kubernetes_namespace.airflow_ns.metadata[0].name
  version    = "1.16.0"

  set {
    name  = "executor"
    value = "KubernetesExecutor"
  }

  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  set {
    name  = "redis.enabled"
    value = "false"
  }

  set {
    name  = "data.metadataSecretName"
    value = kubernetes_secret.airflow_db_secret.metadata[0].name
  }

  set {
    name  = "airflow.persistence.enabled"
    value = "true"
  }

  set {
    name  = "airflow.persistence.size"
    value = "20Gi"
  }

  set {
    name  = "images.airflow.repository"
    value = "apache/airflow"
  }

  set {
    name  = "images.airflow.tag"
    value = var.airflow_image_tag
  }

  set {
    name  = "airflow.airflowVersion"
    value = var.airflow_image_tag
  }

  set {
    name  = "webserver.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "webserver.service.loadBalancerIP"
    value = azurerm_public_ip.airflow_web.ip_address
  }

  set {
    name  = "dags.gitSync.enabled"
    value = "true"
  }

  set {
    name  = "dags.gitSync.repo"
    value = var.dags_git_repo
  }

  set {
    name  = "dags.gitSync.branch"
    value = var.dags_git_branch
  }

  set {
    name  = "dags.gitSync.subPath"
    value = "dags"
  }

  set {
    name  = "dags.gitSync.sshKeySecret"
    value = kubernetes_secret.airflow_ssh_secret.metadata[0].name
  }

  # node selector and tolerations should match the workerpool
  set {
    name  = "executorConfig.nodeSelector.agentpool"
    value = "workerpool"
  }

  lifecycle {
    ignore_changes = [
      set
    ]
  }

  depends_on = [
    kubernetes_secret.airflow_db_secret,
    kubernetes_secret.airflow_ssh_secret,
    azurerm_public_ip.airflow_web
  ]
}
ChatGPT said:

Show, agora consigo ver tudo que você tem no main.tf 👌.
O problema que você encontrou com enable_auto_scaling não é que está “fora do lugar”, mas sim que a forma de declarar mudou entre versões do provider azurerm.
📌 Problema

    No recurso azurerm_kubernetes_cluster.default_node_pool você escreveu:

default_node_pool {
  name                = "systempool"
  node_count          = 1
  vm_size             = "Standard_B2s"
  vnet_subnet_id      = azurerm_subnet.aks.id
  enable_auto_scaling = true
  min_count           = 1
  max_count           = 1
}

O erro do Terraform (enable_auto_scaling não esperado) indica que a versão do provider azurerm que você está usando não aceita mais esse campo dentro do default_node_pool.
✅ Correção (2 opções)
Opção 1 – Fixar versão do provider

Se você quer manter enable_auto_scaling, precisa usar azurerm >= 3.38.
No seu providers.tf:

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.38.0"
    }
  }
}

provider "azurerm" {
  features {}
}

Com essa versão, o bloco acima funciona normalmente.
Opção 2 – Usar azurerm_kubernetes_cluster_node_pool para autoscaling

Se você não quiser atualizar, deixe o default_node_pool fixo e configure o autoscaling apenas no node pool adicional:

default_node_pool {
  name           = "systempool"
  node_count     = 1
  vm_size        = "Standard_B2s"
  vnet_subnet_id = azurerm_subnet.aks.id
}

resource "azurerm_kubernetes_cluster_node_pool" "system_autoscaler" {
  name                  = "systemautoscaler"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_B2s"
  enable_auto_scaling   = true
  min_count             = 1
  max_count             = 3
  mode                  = "System"
}

🔧 Além disso:

    Troque sku_name = "GP_Standard_D2ds_v5" para algo válido, ex:

    sku_name = "GP_Standard_D2s_v3_2"

    Remova o bloco high_availability do PostgreSQL, já que "Disabled" não existe em Terraform.

    O addon_profile precisa ser removido mesmo, como já comentamos.

👉 Pergunto: você prefere que eu atualize seu código para usar o provider azurerm >= 3.38 (mais simples, manter enable_auto_scaling onde está),
ou prefere que eu reorganize os nodepools (sem atualizar provider, mas mais verboso)?
You said:
Error: Unsupported block type
on main.tf line 162, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 167, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 172, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 177, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 182, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 187, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 192, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 197, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 202, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 207, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 212, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 217, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 222, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 227, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 232, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 237, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
Error: Unsupported block type
on main.tf line 243, in resource "helm_release" "airflow":
  set {
Blocks of type "set" are not expected here. Did you mean to define argument "set"? If so, use the equals sign to assign it a value.
ChatGPT said:

Ah, agora o erro é totalmente compreensível: o provider helm que você está usando mudou a forma de passar valores set.

Na versão >= 2.x do provider helm, o bloco set { ... } não é mais suportado como bloco, você precisa usar argumento set com lista de mapas.
Correção do helm_release

Troque isso (sintaxe antiga):

resource "helm_release" "airflow" {
  name       = "airflow"
  repository = "https://airflow.apache.org"
  chart      = "airflow"
  namespace  = kubernetes_namespace.airflow_ns.metadata[0].name
  version    = "1.16.0"

  set {
    name  = "executor"
    value = "KubernetesExecutor"
  }

  set {
    name  = "postgresql.enabled"
    value = "false"
  }

  ...
}

Por isso (sintaxe nova compatível com helm >= 2):

resource "helm_release" "airflow" {
  name       = "airflow"
  repository = "https://airflow.apache.org"
  chart      = "airflow"
  namespace  = kubernetes_namespace.airflow_ns.metadata[0].name
  version    = "1.16.0"

  set = [
    {
      name  = "executor"
      value = "KubernetesExecutor"
    },
    {
      name  = "postgresql.enabled"
      value = "false"
    },
    {
      name  = "redis.enabled"
      value = "false"
    },
    {
      name  = "data.metadataSecretName"
      value = kubernetes_secret.airflow_db_secret.metadata[0].name
    },
    {
      name  = "airflow.persistence.enabled"
      value = "true"
    },
    {
      name  = "airflow.persistence.size"
      value = "20Gi"
    },
    {
      name  = "images.airflow.repository"
      value = "apache/airflow"
    },
    {
      name  = "images.airflow.tag"
      value = var.airflow_image_tag
    },
    {
      name  = "airflow.airflowVersion"
      value = var.airflow_image_tag
    },
    {
      name  = "webserver.service.type"
      value = "LoadBalancer"
    },
    {
      name  = "webserver.service.loadBalancerIP"
      value = azurerm_public_ip.airflow_web.ip_address
    },
    {
      name  = "dags.gitSync.enabled"
      value = "true"
    },
    {
      name  = "dags.gitSync.repo"
      value = var.dags_git_repo
    },
    {
      name  = "dags.gitSync.branch"
      value = var.dags_git_branch
    },
    {
      name  = "dags.gitSync.subPath"
      value = "dags"
    },
    {
      name  = "dags.gitSync.sshKeySecret"
      value = kubernetes_secret.airflow_ssh_secret.metadata[0].name
    },
    {
      name  = "executorConfig.nodeSelector.agentpool"
      value = "workerpool"
    }
  ]

  lifecycle {
    ignore_changes = [
      set
    ]
  }

  depends_on = [
    kubernetes_secret.airflow_db_secret,
    kubernetes_secret.airflow_ssh_secret,
    azurerm_public_ip.airflow_web
  ]
}

✅ Explicação:

    set agora é um argumento único, recebe uma lista de mapas com name e value.

    Blocos individuais set { ... } não existem mais no Terraform 1.6 + Helm provider 2.x.

    lifecycle.ignore_changes = [set] continua válido para ignorar alterações dinâmicas.

Se quiser, posso gerar uma versão completa do main.tf corrigida pronta para rodar no HCP com:

    Helm provider 2.x

    PostgreSQL SKU e HA válidos

    AKS com nodepool autoscaling correto

    Removido blocos/deprecated fields

Isso resolve todos os erros que você encontrou até agora.

Quer que eu faça isso?
You said:
Error: Post "http://localhost/api/v1/namespaces": dial tcp [::1]:80: connect: connection refused
with kubernetes_namespace.airflow_ns
on main.tf line 107, in resource "kubernetes_namespace" "airflow_ns":
resource "kubernetes_namespace" "airflow_ns" {
Error: creating Flexible Server (Subscription: "8cd5fdce-6161-4fb3-80f1-de5dd3736921" Resource Group Name: "rg-airflow-prod" Flexible Server Name: "airflow-metadb-postgresql"): performing Create: unexpected status 400 (400 Bad Request) with error: ConflictingPublicNetworkAccessAndVirtualNetworkConfiguration: Conflicting configuration is detected between Public Network Access and Virtual Network arguments. Public Network Access is not supported along with Virtual Network feature.
with azurerm_postgresql_flexible_server.airflow_db
on main.tf line 34, in resource "azurerm_postgresql_flexible_server" "airflow_db":
resource "azurerm_postgresql_flexible_server" "airflow_db" {
ChatGPT said:

💡 Excelente, agora você pegou dois pontos diferentes:
1. Erro do Kubernetes provider (dial tcp [::1]:80)

Isso acontece porque o provider kubernetes está tentando conectar no cluster AKS antes do cluster estar pronto.
Por padrão ele vai usar http://localhost:80 porque não recebeu kubeconfig.

👉 Soluções possíveis:

    Configure o provider kubernetes para usar as credenciais do AKS:

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

    E coloque depends_on = [azurerm_kubernetes_cluster.aks] nos recursos Kubernetes (você já fez em alguns).

Assim o Terraform só tenta aplicar os manifests depois que o cluster existe e o kubeconfig foi gerado.
2. Erro do PostgreSQL Flexible Server (ConflictingPublicNetworkAccessAndVirtualNetworkConfiguration)

Esse erro vem da API do Azure: você definiu delegated_subnet_id e private_dns_zone_id (modo Private Access), mas não desativou o acesso público.

👉 Correção: adicione ao seu recurso:

resource "azurerm_postgresql_flexible_server" "airflow_db" {
  name                = "airflow-metadb-postgresql"
  resource_group_name = azurerm_resource_group.airflow.name
  location            = azurerm_resource_group.airflow.location

  administrator_login    = var.db_admin_user
  administrator_password = var.db_admin_password
  version                = "16"

  sku_name   = "GP_Standard_D2s_v3_2"
  storage_mb = 32768

  delegated_subnet_id    = azurerm_subnet.db.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false   # 🔥 ESSENCIAL

  authentication {
    password_auth_enabled = true
  }

  depends_on = [azurerm_subnet.db]
}

Isso deixa o servidor 100% privado, acessível só pelo subnet e DNS privado.

✅ Resumindo:

    Corrija o provider Kubernetes para usar o kube_config do AKS.

    Adicione public_network_access_enabled = false ao PostgreSQL Flexible Server.

Quer que eu já te gere um ZIP atualizado com:

    provider Kubernetes configurado,

    PostgreSQL privado corrigido,

    Helm syntax corrigida,

    autoscaling/sku válidos?

You said:
do kube_config eu não entendi, pode me dizer detalhadamente onde devo trocar e o que ?
ChatGPT said:

Boa! Esse ponto do kube_config realmente é confuso no AKS quando usado com Terraform. Vou detalhar passo a passo, pra você não se perder:
📍 Onde você está agora

    Você criou o recurso azurerm_kubernetes_cluster "aks".

    Em seguida está tentando criar kubernetes_namespace e kubernetes_secret usando o provider kubernetes.

    Mas o provider kubernetes não sabe como se conectar ao cluster, então ele tentou http://localhost:80 → erro connection refused.

📍 Como resolver

O provider kubernetes precisa receber as credenciais do AKS. Essas credenciais vêm direto do recurso azurerm_kubernetes_cluster.
1. Edite o providers.tf

Adicione (ou substitua) o bloco do provider kubernetes:

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

⚠️ Importante:

    Esse kube_config é gerado pelo Azure automaticamente quando você cria o cluster.

    O base64decode é necessário porque o Terraform armazena os certificados codificados em Base64.

2. Garanta a ordem de criação

O provider kubernetes só funciona depois que o cluster existe.
Então, nos recursos que usam Kubernetes (namespace, secrets, helm_release), coloque:

depends_on = [azurerm_kubernetes_cluster.aks]

Você já fez em alguns (namespace, secret), mas pode reforçar em todos que dependem do cluster.
3. Exemplo prático

Seu providers.tf ficaria assim:

provider "azurerm" {
  features {}
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

Assim:

    azurerm → cria os recursos no Azure.

    kubernetes → usa o kubeconfig embutido no recurso do AKS.

    helm → instala o chart no AKS usando o mesmo kubeconfig.

👉 Pergunto:
Quer que eu já prepare pra você um providers.tf completo + ajustes nos depends_on e te mando tudo em um ZIP revisado (com PostgreSQL privado também corrigido)?
You said:
mas o meu bloco do  provider esta assim
terraform {
  required_version = ">= 1.6.0"

  backend "remote" {
    host = "app.terraform.io" # HCP / Terraform Cloud host
    organization = "your-org" # <-- substitua pelo nome da sua organização no HCP

    workspaces {
      name = "airflow-azure-workspace" # <-- nome do workspace
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Kubernetes and Helm providers are configured later using the AKS kubeconfig outputs
ChatGPT said:

Perfeito 👌 obrigado por compartilhar — isso explica a confusão.

O bloco que você mostrou (terraform { ... } + provider "azurerm") está só definindo quais providers usar, mas o kubernetes e o helm ainda não estão configurados.

O comentário no final do arquivo já dá a dica:

# Kubernetes and Helm providers are configured later using the AKS kubeconfig outputs

Ou seja: você precisa criar providers adicionais que apontem para as credenciais (kube_config) do seu azurerm_kubernetes_cluster.aks.
✅ Como corrigir

Logo abaixo desse bloco que você já tem, adicione:

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }
}

⚠️ Ordem de criação (muito importante)

Esses providers usam o output de azurerm_kubernetes_cluster.aks.
Então, se o Terraform tentar criar kubernetes_namespace ou helm_release antes do cluster existir, vai falhar.

👉 Por isso, você precisa garantir depends_on nos recursos Kubernetes/Helm, assim:

resource "kubernetes_namespace" "airflow_ns" {
  metadata {
    name = "airflow"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

resource "helm_release" "airflow" {
  name       = "airflow"
  repository = "https://airflow.apache.org"
  chart      = "airflow"
  namespace  = kubernetes_namespace.airflow_ns.metadata[0].name

  depends_on = [
    kubernetes_namespace.airflow_ns,
    azurerm_kubernetes_cluster.aks
  ]
}

📌 Resumindo:

    Seu terraform { ... } fica como está (com os required_providers).

    Logo abaixo, você adiciona os blocos provider "kubernetes" e provider "helm" configurados com o kube_config.

    E reforça depends_on em tudo que depende do AKS.

Quer que eu já te monte um providers.tf pronto com esse ajuste, junto com as depends_on adicionadas nos pontos certos do seu main.tf?
You said:
Error: Unsupported block type
on providers.tf line 41, in provider "helm":
  kubernetes {
Blocks of type "kubernetes" are not expected here. Did you mean to define argument "kubernetes"? If so, use the equals sign to assign it a value.
ChatGPT said:

Boa, esse erro faz sentido 👌

No provider helm, você não usa bloco kubernetes {}, mas sim argumento kubernetes {} (inline map).
A sintaxe é ligeiramente diferente.
🚀 Correção

Troque o que você tem hoje:

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }
}

Por esta versão válida:

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }
}

👉 Mas o detalhe é: dependendo da versão do provider helm, o suporte ao bloco kubernetes {} pode não estar disponível.
Se você estiver usando hashicorp/helm >= 2.9.0, a forma recomendada é passar como argumento kubernetes {} exatamente como acima.
Se for uma versão mais antiga (< 2.9.0), o correto é usar um provider kubernetes separado e o helm pega esse provider automaticamente.
✅ Solução mais compatível (independente da versão)

O jeito mais seguro é deixar o helm sem configuração própria e ele vai usar o mesmo provider "kubernetes" que você já configurou:

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

👉 Só que como você está pegando os dados direto do azurerm_kubernetes_cluster, o ideal é:

    manter o provider "kubernetes" configurado com o kube_config do AKS

    e usar o helm sem argumentos extras, que ele herda do Kubernetes provider.

📌 Pergunto: você prefere que eu simplifique e deixe só provider "kubernetes" com o kube_config do AKS, e o helm pegando automaticamente esse provider, ou você quer manter o helm com a configuração explícita?
You said:
Error: Unsupported block type
on providers.tf line 41, in provider "helm":
  kubernetes {
Blocks of type "kubernetes" are not expected here. Did you mean to define argument "kubernetes"? If so, use the equals sign to assign it a value.
ChatGPT said:

Perfeito, agora ficou claro o que está acontecendo 🚦

O erro:

Error: Unsupported block type
on providers.tf line 41, in provider "helm":
  kubernetes {
Blocks of type "kubernetes" are not expected here.

significa que a versão do provider helm que você está usando não aceita o bloco kubernetes { ... } dentro dele.
Isso mudou entre versões antigas e novas do provider.
✅ Como resolver

Na sua configuração, já existe um provider "kubernetes" configurado.
Então, a forma correta é não configurar nada dentro do provider "helm" → ele herda o contexto do provider kubernetes.
providers.tf corrigido:

terraform {
  required_version = ">= 1.6.0"

  backend "remote" {
    host         = "app.terraform.io"
    organization = "your-org"

    workspaces {
      name = "airflow-azure-workspace"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

provider "helm" {}

🔑 Resumo

    provider "kubernetes" → conecta no AKS usando os outputs de azurerm_kubernetes_cluster.

    provider "helm" → não precisa de nada, ele automaticamente usa o kubernetes.

👉 Quer que eu já ajuste o seu main.tf para garantir que todos os recursos Helm (helm_release) e Kubernetes (namespace, secrets) tenham depends_on no AKS, e te mande um pacote .zip pronto corrigido?
You said:
Error: Get "http://localhost/api/v1/namespaces/airflow": dial tcp [::1]:80: connect: connection refused
with kubernetes_namespace.airflow_ns
on main.tf line 108, in resource "kubernetes_namespace" "airflow_ns":
resource "kubernetes_namespace" "airflow_ns" {
ChatGPT said:

Boa, esse erro já não é de sintaxe, mas sim de conexão:

Error: Get "http://localhost/api/v1/namespaces/airflow": dial tcp [::1]:80: connect: connection refused

O Terraform está tentando falar com o Kubernetes, mas em vez de usar o endpoint do AKS, ele está caindo no http://localhost:80 (ou seja, não conseguiu pegar o kubeconfig do cluster ainda).
🔍 Causas prováveis

    O provider "kubernetes" está sendo inicializado antes do cluster AKS ser criado.

    O bloco provider "kubernetes" não está usando os outputs corretos de azurerm_kubernetes_cluster.

    Faltou depends_on para forçar que o AKS exista antes de usar o provider.

✅ Como corrigir
1. Ajuste no provider kubernetes

Confirme que ele está assim no providers.tf:

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)

  # garante que só inicializa depois do AKS
  load_config_file       = false
}

👉 sem o load_config_file = false, ele tenta buscar ~/.kube/config e cai no localhost.
2. Adicione depends_on

Nos recursos que usam o Kubernetes provider (namespace, secrets, helm release), force dependência explícita:

resource "kubernetes_namespace" "airflow_ns" {
  metadata {
    name = "airflow"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

E o mesmo para os kubernetes_secret e helm_release.
3. Ordem de aplicação

No primeiro terraform apply, pode ser necessário rodar em duas fases:

    Criar AKS e rede:

terraform apply -target=azurerm_kubernetes_cluster.aks

Depois aplicar o resto normalmente:

    terraform apply

⚡ Isso resolve porque garante que o provider "kubernetes" tenha as credenciais do AKS já provisionado.

👉 Quer que eu te monte um providers.tf + main.tf corrigidos (com depends_on em todos os recursos Kubernetes/Helm) e te entregue num .zip já ajustado?
You said:
Error: Get "http://localhost/api/v1/namespaces/airflow": dial tcp [::1]:80: connect: connection refused
with kubernetes_namespace.airflow_ns
on main.tf line 108, in resource "kubernetes_namespace" "airflow_ns":
resource "kubernetes_namespace" "airflow_ns" {
ChatGPT said:

Perfeito, esse erro está te perseguindo porque o Terraform ainda tenta usar o localhost como endpoint do Kubernetes, em vez do endpoint do AKS. Isso acontece quando o provider "kubernetes" não está corretamente ligado ao output do azurerm_kubernetes_cluster.
✅ Como corrigir de forma robusta
1. Configure o kubernetes provider assim:

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)

  load_config_file       = false
}

👉 Esse load_config_file = false é obrigatório.
Sem ele, o Terraform tenta usar ~/.kube/config e acaba conectando em http://localhost:80.
2. Forçar ordem com depends_on

Todos os recursos que usam Kubernetes precisam esperar o cluster AKS estar pronto. Exemplo:

resource "kubernetes_namespace" "airflow_ns" {
  metadata {
    name = "airflow"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

E faça o mesmo para:

    kubernetes_secret.airflow_db_secret

    kubernetes_secret.airflow_ssh_secret

    kubernetes_secret.airflow_ssh_knownhosts

    helm_release.airflow

3. Aplicar em duas fases (primeira vez)

Mesmo com o depends_on, às vezes o AKS demora para liberar o kubeconfig.
Então, no primeiro apply, pode ser necessário rodar em duas etapas:

terraform apply -target=azurerm_kubernetes_cluster.aks

Quando o cluster já existir, rode o restante:

terraform apply

🔑 Resumo:

    O provider kubernetes precisa ser configurado com os blocos host, client_certificate, client_key, cluster_ca_certificate.

    load_config_file = false evita cair no localhost.

    depends_on garante que o AKS já exista antes de criar namespace, secret e helm_release.

    No primeiro deploy, talvez precise rodar em duas fases.

👉 Quer que eu te entregue um providers.tf + main.tf revisados já com load_config_file = false e todos os depends_on para você aplicar sem cair no localhost?
You said:
Error: Unsupported argument
on providers.tf line 39, in provider "kubernetes":
  load_config_file       = false
An argument named "load_config_file" is not expected here.
ChatGPT said:

Boa 🚦 — isso confirma que a versão do provider kubernetes que você está usando não aceita o argumento load_config_file.

Esse campo existia em versões mais antigas (1.x e 2.x iniciais), mas nas versões recentes (>=2.20) a HashiCorp mudou a forma de configurar o provider.
✅ Como corrigir

Em vez de load_config_file, você só precisa definir os campos diretamente.
Exemplo compatível com as versões atuais:

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

👉 Ou seja, remova completamente load_config_file.
⚡ Dica extra

Se ainda assim cair no localhost, pode ser que o Terraform esteja tentando inicializar o provider "kubernetes" antes de o AKS existir.
Nesse caso:

    Rode em duas etapas:

terraform apply -target=azurerm_kubernetes_cluster.aks

(isso cria o AKS primeiro)

Depois rode:

    terraform apply

    Adicione depends_on nos recursos Kubernetes e Helm para garantir ordem, por exemplo:

resource "kubernetes_namespace" "airflow_ns" {
  metadata {
    name = "airflow"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

🔑 Resumo:

    Remova load_config_file (não existe nessa versão).

    Continue usando os atributos host, client_certificate, client_key, cluster_ca_certificate.

    Garanta que o AKS esteja criado antes do kubernetes provider ser usado (com depends_on ou terraform apply -target).

👉 Quer que eu monte para você um providers.tf atualizado, sem load_config_file, já pronto para HCP Terraform?
You said:
Error: Get "http://localhost/api/v1/namespaces/airflow": dial tcp [::1]:80: connect: connection refused
with kubernetes_namespace.airflow_ns
on main.tf line 108, in resource "kubernetes_namespace" "airflow_ns":
resource "kubernetes_namespace" "airflow_ns" {
ChatGPT said:

Entendi 🔎 — esse erro continua porque o provider kubernetes ainda não está pegando as credenciais do AKS no momento em que o Terraform tenta criar o namespace.

O sintoma é claro:

Get "http://localhost/api/v1/namespaces/airflow": dial tcp [::1]:80: connect: connection refused

👉 Isso significa que o Terraform está caindo no localhost (default) em vez de usar os dados de azurerm_kubernetes_cluster.aks.kube_config.
✅ Como resolver de forma garantida
1. Configure os providers com alias e depends_on

📌 providers.tf atualizado:

provider "azurerm" {
  features {}
}

# Provider Kubernetes, usando kube_config do AKS
provider "kubernetes" {
  alias                  = "aks"
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

# Provider Helm, também apontando para o cluster AKS
provider "helm" {
  alias = "aks"
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }
}

2. Use os providers explicitamente nos recursos

Por exemplo, no main.tf:

resource "kubernetes_namespace" "airflow_ns" {
  provider = kubernetes.aks

  metadata {
    name = "airflow"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

resource "kubernetes_secret" "airflow_db_secret" {
  provider = kubernetes.aks

  metadata {
    name      = "airflow-db-secret"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }

  data = {
    connection = base64encode("postgresql://${var.db_admin_user}:${var.db_admin_password}@${azurerm_postgresql_flexible_server.airflow_db.fqdn}:5432/airflow")
  }

  depends_on = [kubernetes_namespace.airflow_ns]
}

resource "helm_release" "airflow" {
  provider = helm.aks

  name       = "airflow"
  repository = "https://airflow.apache.org"
  chart      = "airflow"
  namespace  = kubernetes_namespace.airflow_ns.metadata[0].name
  version    = "1.16.0"

  set = [
  {
    name  = "executor"
    value = "KubernetesExecutor"
  },
  {
    name  = "postgresql.enabled"
    value = "false"
  },
  {
    name  = "redis.enabled"
    value = "false"
  },
  {
    name  = "data.metadataSecretName"
    value = kubernetes_secret.airflow_db_secret.metadata[0].name
  },
  {
    name  = "airflow.persistence.enabled"
    value = "true"
  },
  {
    name  = "airflow.persistence.size"
    value = "20Gi"
  },
  {
    name  = "images.airflow.repository"
    value = "apache/airflow"
  },
  {
    name  = "images.airflow.tag"
    value = var.airflow_image_tag
  },
  {
    name  = "airflow.airflowVersion"
    value = var.airflow_image_tag
  },
  {
    name  = "webserver.service.type"
    value = "LoadBalancer"
  },
  {
    name  = "webserver.service.loadBalancerIP"
    value = azurerm_public_ip.airflow_web.ip_address
  },
  {
    name  = "dags.gitSync.enabled"
    value = "true"
  },
  {
    name  = "dags.gitSync.repo"
    value = var.dags_git_repo
  },
  {
    name  = "dags.gitSync.branch"
    value = var.dags_git_branch
  },
  {
    name  = "dags.gitSync.subPath"
    value = "dags"
  },
  {
    name  = "dags.gitSync.sshKeySecret"
    value = kubernetes_secret.airflow_ssh_secret.metadata[0].name
  },
  # node selector and tolerations should match the workerpool
  {
    name  = "executorConfig.nodeSelector.agentpool"
    value = "workerpool"
  }
]

  lifecycle {
    ignore_changes = [
      set
    ]
  }

  depends_on = [
    kubernetes_namespace.airflow_ns,
    azurerm_kubernetes_cluster.aks,
    kubernetes_secret.airflow_db_secret,
    kubernetes_secret.airflow_ssh_secret,
    azurerm_public_ip.airflow_web
  ]
}
