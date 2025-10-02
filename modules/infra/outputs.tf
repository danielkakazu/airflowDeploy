output "kube_host" { 
  value = azurerm_kubernetes_cluster.aks.kube_config[0].host 
  }
output "kube_client_certificate" { 
  value = azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate 
  }
output "kube_client_key" { 
  value = azurerm_kubernetes_cluster.aks.kube_config[0].client_key 
  }
output "kube_cluster_ca_certificate" { 
  value = azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate 
  }
output "db_fqdn" { 
  value = azurerm_postgresql_flexible_server.airflow_db.fqdn 
  }
output "airflow_web_ip" { 
  value = azurerm_public_ip.airflow_web.ip_address 
  }
