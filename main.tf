resource "kubernetes_namespace" "airflow" {
  metadata {
    name = "airflow"
  }
}

resource "helm_release" "airflow" {
  name             = "airflow"
  repository       = "https://airflow.apache.org"
  chart            = "airflow"
  namespace        = kubernetes_namespace.airflow.metadata[0].name
  create_namespace = false
  timeout          = 1200
  wait             = true
}
