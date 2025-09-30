# Variáveis e passos para HCP / Terraform Cloud

**Variáveis sensíveis a criar no Workspace (set as sensitive):**
- AZURE_SUBSCRIPTION_ID
- AZURE_CLIENT_ID
- AZURE_CLIENT_SECRET
- AZURE_TENANT_ID
- db_admin_password
- ssh_private_key

**Sugestão de fluxo**
1. Crie um workspace no Terraform Cloud/HCP e conecte ao repositório contendo estes arquivos.
2. No workspace, configure as variáveis de ambiente (AZURE_*) como environment variables.
3. Configure as variáveis Terraform (db_admin_password, ssh_private_key) como "Terraform variables" e marque como Sensitive.
4. Execute uma Run (via GUI, ou via push -> GitHub Action usando TF_API_TOKEN).
