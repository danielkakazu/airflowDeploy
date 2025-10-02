# =========================
# Resource Group and Network
# =========================
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

# =========================
# PostgreSQL Flexible Server (private)
# =========================
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.airflow.name
}

resource "azurerm_postgresql_flexible_server" "airflow_db" {
  name                = "airflow-metadb-postgresql"
  resource_group_name = azurerm_resource_group.airflow.name
  location            = azurerm_resource_group.airflow.location

  administrator_login    = var.db_admin_user
  administrator_password = var.db_admin_password
  version                = "16"

  sku_name   = "GP_Standard_D2ds_v5"
  storage_mb = 32768

  delegated_subnet_id         = azurerm_subnet.db.id
  private_dns_zone_id         = azurerm_private_dns_zone.postgres.id
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

# =========================
# AKS cluster
# =========================
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-airflow-prod"
  location            = azurerm_resource_group.airflow.location
  resource_group_name = azurerm_resource_group.airflow.name
  dns_prefix          = "airflow"

  default_node_pool {
    name           = "systempool"
    node_count     = 1
    vm_size        = "Standard_B2s"
    vnet_subnet_id = azurerm_subnet.aks.id
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
  vnet_subnet_id        = azurerm_subnet.aks.id
  node_taints           = ["workload=worker:NoSchedule"]
}

# =========================
# Public IP for webserver
# =========================
resource "azurerm_public_ip" "airflow_web" {
  name                = "pip-airflow-web"
  location            = azurerm_resource_group.airflow.location
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
}

# =========================
# Configure Kubernetes provider dynamically
# =========================
provider "kubernetes" {
  alias = "aks"
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  alias      = "aks"
  kubernetes = {
    host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }
}

# =========================
# Kubernetes namespace and secrets
# =========================
resource "kubernetes_namespace" "airflow_ns" {
  provider = kubernetes.aks
  metadata { name = "airflow" }
  depends_on = [azurerm_kubernetes_cluster.aks]
}

resource "kubernetes_secret" "airflow_db_secret" {
  provider = kubernetes.aks
  metadata {
    name      = "airflow-db-secret"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }
  data = { connection = base64encode("postgresql://${var.db_admin_user}:${var.db_admin_password}@${azurerm_postgresql_flexible_server.airflow_db.fqdn}:5432/airflow") }
  depends_on = [kubernetes_namespace.airflow_ns]
}

resource "kubernetes_secret" "airflow_ssh_secret" {
  provider = kubernetes.aks
  metadata {
    name      = "airflow-ssh-secret"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }
  data = { gitSshKey = base64encode(var.ssh_private_key) }
  depends_on = [kubernetes_namespace.airflow_ns]
}

resource "kubernetes_secret" "airflow_ssh_knownhosts" {
  provider = kubernetes.aks
  metadata {
    name      = "airflow-ssh-knownhosts"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }
  data = { knownHosts = base64encode(var.ssh_known_hosts) }
  depends_on = [kubernetes_namespace.airflow_ns]
}

# =========================
# Helm Airflow release
# =========================
resource "helm_release" "airflow" {
  provider  = helm.aks
  name       = "airflow"
  repository = "https://airflow.apache.org"
  chart      = "airflow"
  namespace  = kubernetes_namespace.airflow_ns.metadata[0].name
  version    = "1.16.0"

  set = [
    { name = "executor", value = "KubernetesExecutor" },
    { name = "postgresql.enabled", value = "false" },
    { name = "redis.enabled", value = "false" },
    { name = "data.metadataSecretName", value = kubernetes_secret.airflow_db_secret.metadata[0].name },
    { name = "airflow.persistence.enabled", value = "true" },
    { name = "airflow.persistence.size", value = "20Gi" },
    { name = "images.airflow.repository", value = "apache/airflow" },
    { name = "images.airflow.tag", value = var.airflow_image_tag },
    { name = "airflow.airflowVersion", value = var.airflow_image_tag },
    { name = "webserver.service.type", value = "LoadBalancer" },
    { name = "webserver.service.loadBalancerIP", value = azurerm_public_ip.airflow_web.ip_address },
    { name = "dags.gitSync.enabled", value = "true" },
    { name = "dags.gitSync.repo", value = var.dags_git_repo },
    { name = "dags.gitSync.branch", value = var.dags_git_branch },
    { name = "dags.gitSync.subPath", value = "dags" },
    { name = "dags.gitSync.sshKeySecret", value = kubernetes_secret.airflow_ssh_secret.metadata[0].name },
    { name = "executorConfig.nodeSelector.agentpool", value = "workerpool" }
  ]

  lifecycle { ignore_changes = [set] }

  depends_on = [
    kubernetes_namespace.airflow_ns,
    azurerm_kubernetes_cluster.aks,
    kubernetes_secret.airflow_db_secret,
    kubernetes_secret.airflow_ssh_secret,
    azurerm_public_ip.airflow_web
  ]
}
