output "kube_config" { value = azurerm_kubernetes_cluster.aks.kube_config_raw }
output "postgres_fqdn" { value = azurerm_postgresql_flexible_server.airflow_db.fqdn }
output "public_ip" { value = azurerm_public_ip.airflow_web.ip_address }
output "aks_cluster_name" { value = azurerm_kubernetes_cluster.aks.name }