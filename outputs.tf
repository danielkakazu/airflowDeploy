output "aks_cluster_name" {
  value     = module.infra.aks_name
  sensitive = true
}

output "postgres_fqdn" {
  value = module.infra.db_fqdn
}

output "public_ip" {
  value = module.infra.airflow_web_ip
}
