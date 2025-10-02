variable "kube_host" { type = string }
variable "kube_client_certificate" { type = string }
variable "kube_client_key" { type = string }
variable "kube_cluster_ca_certificate" { type = string }

variable "db_connection_string" { type = string }
variable "ssh_private_key" { 
  type = string
  sensitive = true 
}
variable "ssh_known_hosts" { type = string }
variable "airflow_image_tag" { type = string }
variable "dags_git_repo" { type = string }
variable "dags_git_branch" { type = string }
variable "public_ip" { type = string }
