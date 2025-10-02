module "infra" {
  source = "./modules/infra"

  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_name           = var.vnet_name
  db_admin_user       = var.db_admin_user
  db_admin_password   = var.db_admin_password
  ssh_private_key     = var.ssh_private_key
  ssh_known_hosts     = var.ssh_known_hosts
  airflow_image_tag   = var.airflow_image_tag
  dags_git_repo       = var.dags_git_repo
  dags_git_branch     = var.dags_git_branch
}

module "k8s" {
  source = "./modules/k8s"

  kube_host                   = module.infra.kube_host
  kube_client_certificate     = module.infra.kube_client_certificate
  kube_client_key             = module.infra.kube_client_key
  kube_cluster_ca_certificate = module.infra.kube_cluster_ca_certificate

  db_connection_string = "postgresql://${var.db_admin_user}:${var.db_admin_password}@${module.infra.db_fqdn}:5432/airflow"
  ssh_private_key      = var.ssh_private_key
  ssh_known_hosts      = var.ssh_known_hosts
  airflow_image_tag    = var.airflow_image_tag
  dags_git_repo        = var.dags_git_repo
  dags_git_branch      = var.dags_git_branch
  public_ip            = module.infra.airflow_web_ip
}
