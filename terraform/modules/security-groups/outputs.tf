output "django_sg_id" {
  value = aws_security_group.django.id
}

output "postgres_sg_id" {
  value = aws_security_group.postgres.id
}
