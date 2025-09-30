variable "location" {
  type    = string
  default = "Central US"
}

variable "resource_group_name" {
  type    = string
  default = "rg-airflow-prod"
}

variable "vnet_name" {
  type    = string
  default = "vnet-airflow"
}

variable "db_admin_user" {
  type    = string
  default = "airflow_user"
}

variable "db_admin_password" {
  type      = string
  description = "Password for the PostgreSQL flexible server admin user. Mark this variable as sensitive in HCP."
  sensitive = true
}

variable "ssh_private_key" {
  type      = string
  description = "Private SSH key for git sync. Mark this variable as sensitive in HCP."
  sensitive = true
}

variable "dags_git_repo" {
  type    = string
  default = "git@github.com:danielkakazu/dags.git"
}

variable "dags_git_branch" {
  type    = string
  default = "main"
}

variable "airflow_image_tag" {
  type    = string
  default = "2.10.5"
}
