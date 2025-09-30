output "resource_group" {
  value = azurerm_resource_group.airflow.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "public_ip" {
  value = azurerm_public_ip.airflow_web.ip_address
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.airflow_db.fqdn
}
