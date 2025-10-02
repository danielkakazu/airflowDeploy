variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "db_admin_user" {
  type = string
}

variable "db_admin_password" {
  type      = string
  sensitive = true
}
