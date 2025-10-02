variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "vnet_name" { type = string }
variable "db_admin_user" { type = string }
variable "db_admin_password" { 
  type = string
  sensitive = true 
}
variable "ssh_private_key" { 
  type = string
  sensitive = true
}
variable "ssh_known_hosts" { type = string }
variable "airflow_image_tag" { type = string }
variable "dags_git_repo" { type = string }
variable "dags_git_branch" { type = string }
