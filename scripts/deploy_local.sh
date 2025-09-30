#!/usr/bin/env bash
set -euo pipefail

echo "This script runs terraform locally. For HCP/Terraform Cloud prefer connecting this repo to a workspace."
if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform CLI not found. Install Terraform >=1.6 and retry."
  exit 1
fi

terraform init
terraform apply -auto-approve
