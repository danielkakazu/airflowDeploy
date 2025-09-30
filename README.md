# Airflow on Azure — Terraform (HCP Terraform / Terraform Cloud) Project

Este projeto contém os arquivos Terraform para provisionar:
- Resource Group, VNet e Subnets
- Private DNS zone
- PostgreSQL Flexible Server (Private)
- AKS cluster com node pools
- Public IP para o webserver
- Kubernetes namespace, secrets e Helm release do Apache Airflow

**Estrutura**
- providers.tf: providers e backend (HCP/Terraform Cloud)
- main.tf: recursos Azure, AKS, public IP e Helm release
- variables.tf: variáveis de entrada
- outputs.tf: outputs úteis (AKS kubeconfig, public IP)
- terraform.tfvars.example: exemplo de valores sensíveis (não coloque segredos neste arquivo em produção)
- scripts/deploy_local.sh: script helper para executar `terraform init` e `apply` localmente
- .github/workflows/ci.yml: workflow que executa Terraform via Terraform Cloud (HCP)

**Importante**
- Configure um workspace no HCP Terraform e conecte este repositório ou use o workflow.
- Defina variáveis sensíveis no workspace (AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID, db_admin_password, ssh_private_key).
- Substitua valores de exemplo antes de aplicar em produção.

