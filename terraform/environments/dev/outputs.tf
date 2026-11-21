output "vpc_id" {
  value = module.vpc.vpc_id
}

output "availability_zone" {
  value = local.az
}

output "django_public_ip" {
  value = module.django.public_ip
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

output "django_url" {
  value = "http://${module.django.public_ip}:8000/"
}

output "health_url" {
  value = "http://${module.django.public_ip}:8000/health/"
}

output "ssh_django" {
  value = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.django.public_ip}"
}

output "ssh_postgres" {
  value = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.postgres.public_ip}"
}
