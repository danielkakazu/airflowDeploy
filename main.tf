# =========================
# Kubernetes namespace
# =========================
resource "kubernetes_namespace" "airflow_ns" {
  provider = kubernetes.aks

  metadata {
    name = "airflow"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# =========================
# Kubernetes secrets
# =========================
resource "kubernetes_secret" "airflow_db_secret" {
  provider = kubernetes.aks

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
  provider = kubernetes.aks

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
  provider = kubernetes.aks

  metadata {
    name      = "airflow-ssh-knownhosts"
    namespace = kubernetes_namespace.airflow_ns.metadata[0].name
  }

  data = {
    knownHosts = base64encode(var.ssh_known_hosts)
  }

  depends_on = [kubernetes_namespace.airflow_ns]
}

# =========================
# Helm Airflow release
# =========================
resource "helm_release" "airflow" {
  provider = helm.aks

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

  lifecycle {
    ignore_changes = [set]
  }

  depends_on = [
    kubernetes_namespace.airflow_ns,
    azurerm_kubernetes_cluster.aks,
    kubernetes_secret.airflow_db_secret,
    kubernetes_secret.airflow_ssh_secret,
    azurerm_public_ip.airflow_web
  ]
}
