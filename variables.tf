variable "resource_group_name" {
  type        = string
  description = "Nome do Resource Group"
}

variable "location" {
  type        = string
  description = "Região do Azure"
}

variable "vnet_name" {
  type        = string
  description = "Nome da VNet"
}

variable "db_admin_user" {
  type        = string
  description = "Usuário administrador do PostgreSQL"
}

variable "db_admin_password" {
  type        = string
  description = "Senha do administrador do PostgreSQL"
  sensitive   = true
}

variable "airflow_image_tag" {
  type        = string
  description = "Tag da imagem do Airflow"
}

variable "dags_git_repo" {
  type        = string
  description = "Repositório Git dos DAGs"
}

variable "dags_git_branch" {
  type        = string
  description = "Branch do repositório Git dos DAGs"
}

variable "ssh_private_key" {
  type        = string
  description = "Chave SSH privada para GitSync"
  sensitive   = true
}

variable "ssh_known_hosts" {
  type        = string
  description = "Conteúdo do known_hosts para GitSync (ex: github.com ssh-rsa ...)"
}
