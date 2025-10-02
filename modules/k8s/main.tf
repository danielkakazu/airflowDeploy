provider "kubernetes" {
  alias                   = "aks"
  host                    = var.kube_config.host
  client_certificate      = base64decode(var.kube_config.client_certificate)
  client_key              = base64decode(var.kube_config.client_key)
  cluster_ca_certificate  = base64decode(var.kube_config.cluster_ca_certificate)
}

provider "helm" {
  alias = "aks"
  kubernetes = {
    host                   = var.kube_config.host
    client_certificate     = base64decode(var.kube_config.client_certificate)
    client_key             = base64decode(var.kube_config.client_key)
    cluster_ca_certificate = base64decode(var.kube_config.cluster_ca_certificate)
  }
}

resource "kubernetes_namespace" "airflow_ns" {
  provider = kubernetes.aks
  metadata { name = "airflow" }
}

resource "kubernetes_secret" "airflow_db_secret" {
  provider = kubernetes.aks
  metadata {
    name      = "airflow-db-secret"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }
  data = { connection = base64encode(var.db_connection_string) }
}

resource "kubernetes_secret" "airflow_ssh_secret" {
  provider = kubernetes.aks
  metadata {
    name      = "airflow-ssh-secret"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }
  data = { gitSshKey = base64encode(var.ssh_private_key) }
}

resource "kubernetes_secret" "airflow_ssh_knownhosts" {
  provider = kubernetes.aks
  metadata {
    name      = "airflow-ssh-knownhosts"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }
  data = { knownHosts = base64encode(var.ssh_known_hosts) }
}
