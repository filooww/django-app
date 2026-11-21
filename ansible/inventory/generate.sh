#!/usr/bin/env bash
# Builds hosts.ini from Terraform outputs.
# Ansible reaches the instances by ID through SSM Session Manager (no open SSH port).
# CONNECTION=ssh connects to the public IPs instead (requires enable_ssh = true in Terraform).
set -euo pipefail

cd "$(dirname "$0")"
TF_DIR="../../terraform/environments/dev"
KEY_FILE="${SSH_KEY_FILE:-~/.ssh/aws-key.pem}"
CONNECTION="${CONNECTION:-ssm}"
AWS_PROFILE_NAME="${AWS_PROFILE:-devops}"

out="$(mktemp)"
trap 'rm -f "$out"' EXIT
terraform -chdir="$TF_DIR" output -json > "$out"

jq -r --arg key "$KEY_FILE" --arg conn "$CONNECTION" --arg profile "$AWS_PROFILE_NAME" --arg q "'" '
def host(id; ip): if $conn == "ssm" then id else ip end;
"[django]
django-server ansible_host=\(host(.django_instance_id.value; .django_public_ip.value)) public_ip=\(.django_public_ip.value) private_ip=\(.django_private_ip.value)

[database]
postgres-server ansible_host=\(host(.postgres_instance_id.value; .postgres_public_ip.value)) public_ip=\(.postgres_public_ip.value) private_ip=\(.postgres_private_ip.value) ebs_volume_id=\(.postgres_data_volume_id.value) backup_bucket=\(.backup_bucket.value) aws_region=\(.aws_region.value)

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=\($key)" +
(if $conn == "ssm" then
"\nansible_ssh_common_args=\($q)-o ProxyCommand=\"aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p --profile \($profile) --region \(.aws_region.value)\"\($q)"
else "" end)
' "$out" > hosts.ini

echo "inventory/hosts.ini ($CONNECTION):"
cat hosts.ini
