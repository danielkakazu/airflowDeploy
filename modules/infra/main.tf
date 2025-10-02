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

resource "azurerm_postgresql_flexible_server" "airflow_db" {
  name                = "airflow-metadb-postgresql"
  resource_group_name = azurerm_resource_group.airflow.name
  location            = azurerm_resource_group.airflow.location
  administrator_login    = var.db_admin_user
  administrator_password = var.db_admin_password
  version                = "16"
  sku_name               = "GP_Standard_D2ds_v5"
  storage_mb             = 32768
  delegated_subnet_id    = azurerm_subnet.db.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false

  authentication { password_auth_enabled = true }
  depends_on = [azurerm_subnet.db]
}

resource "azurerm_postgresql_flexible_server_database" "airflow_db_database" {
  name      = "airflow"
  server_id = azurerm_postgresql_flexible_server.airflow_db.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

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

  identity { type = "SystemAssigned" }
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

resource "azurerm_public_ip" "airflow_web" {
  name                = "pip-airflow-web"
  location            = azurerm_resource_group.airflow.location
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
}