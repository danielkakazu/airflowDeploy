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

  addon_profile {
    oms_agent {
      enabled = true
    }
  }
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
