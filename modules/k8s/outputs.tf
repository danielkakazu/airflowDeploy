output "airflow_namespace" {
  value = kubernetes_namespace.airflow_ns.metadata[0].name
}

output "airflow_db_secret" {
  value     = kubernetes_secret.airflow_db_secret.metadata[0].name
  sensitive = true
}
