terraform {
  required_version = ">= 1.6.0"

  backend "remote" {
    host = "app.terraform.io" # HCP / Terraform Cloud host
    organization = "your-org" # <-- substitua pelo nome da sua organização no HCP

    workspaces {
      name = "airflow-azure-workspace" # <-- nome do workspace
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Kubernetes and Helm providers are configured later using the AKS kubeconfig outputs
