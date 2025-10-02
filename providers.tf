terraform {
  required_version = ">= 1.6.0"

  backend "remote" {
    host         = "app.terraform.io"
    organization = "StudyTestKakazu"

    workspaces { name = "airflowDeploy" }
  }

  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 3.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.0" }
    helm       = { source = "hashicorp/helm", version = ">= 2.0" }
  }
}

provider "azurerm" {
  features {}
}
