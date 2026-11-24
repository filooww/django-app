output "vpc_id" {
  value = module.vpc.vpc_id
}

output "availability_zone" {
  value = local.az
}

output "django_public_ip" {
  value = aws_eip.django.public_ip
}

output "django_instance_id" {
  value = module.django.id
}

output "postgres_instance_id" {
  value = module.postgres.id
}

output "django_private_ip" {
  value = module.django.private_ip
}

output "postgres_public_ip" {
  value = module.postgres.public_ip
}

output "postgres_private_ip" {
  value = module.postgres.private_ip
}

output "postgres_data_volume_id" {
  value = module.postgres_data.volume_id
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.bucket
}

output "aws_region" {
  value = var.aws_region
}

output "django_url" {
  value = "http://${aws_eip.django.public_ip}:8000/"
}

output "health_url" {
  value = "http://${aws_eip.django.public_ip}:8000/health/"
}

output "ssm_django" {
  value = "aws ssm start-session --target ${module.django.id} --profile ${var.aws_profile}"
}

output "ssm_postgres" {
  value = "aws ssm start-session --target ${module.postgres.id} --profile ${var.aws_profile}"
}

output "monitoring_instance_id" {
  value = module.monitoring.id
}

output "monitoring_private_ip" {
  value = module.monitoring.private_ip
}

output "ssm_monitoring" {
  value = "aws ssm start-session --target ${module.monitoring.id} --profile ${var.aws_profile}"
}

# Opens Grafana on http://localhost:3000 through SSM (Prometheus: 9090, Alertmanager: 9093)
output "grafana_tunnel" {
  value = "aws ssm start-session --target ${module.monitoring.id} --document-name AWS-StartPortForwardingSession --parameters portNumber=3000,localPortNumber=3000 --profile ${var.aws_profile}"
}

output "monitoring_public_ip" {
  value = module.monitoring.public_ip
}
