terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }
  }
}

data "terraform_remote_state" "infra" {
  backend = "remote"
  config = {
    organization = "minha-org-hcp"
    workspaces = {
      name = "infra"
    }
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.kube_config.host
  client_certificate     = base64decode(data.terraform_remote_state.infra.outputs.kube_config.client_certificate)
  client_key             = base64decode(data.terraform_remote_state.infra.outputs.kube_config.client_key)
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.kube_config.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.infra.outputs.kube_config.host
    client_certificate     = base64decode(data.terraform_remote_state.infra.outputs.kube_config.client_certificate)
    client_key             = base64decode(data.terraform_remote_state.infra.outputs.kube_config.client_key)
    cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.kube_config.cluster_ca_certificate)
  }
}
