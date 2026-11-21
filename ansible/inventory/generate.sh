#!/usr/bin/env bash
# Builds hosts.ini from Terraform outputs.
set -euo pipefail

cd "$(dirname "$0")"
TF_DIR="../../terraform/environments/dev"
KEY_FILE="${SSH_KEY_FILE:-~/.ssh/aws-key.pem}"

terraform -chdir="$TF_DIR" output -json > /tmp/tf-outputs.$$.json
trap 'rm -f /tmp/tf-outputs.$$.json' EXIT

jq -r --arg key "$KEY_FILE" '
"[django]
django-server ansible_host=\(.django_public_ip.value) private_ip=\(.django_private_ip.value)

[database]
postgres-server ansible_host=\(.postgres_public_ip.value) private_ip=\(.postgres_private_ip.value) ebs_volume_id=\(.postgres_data_volume_id.value) backup_bucket=\(.backup_bucket.value) aws_region=\(.aws_region.value)

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=\($key)"
' /tmp/tf-outputs.$$.json > hosts.ini

echo "inventory/hosts.ini:"
cat hosts.ini
