variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "availability_zone" {
  type        = string
  default     = ""
  description = "Empty means the first available AZ in the region"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "admin_cidr" {
  type        = string
  description = "Admin IP for SSH and app testing, pass via TF_VAR_admin_cidr"
}

variable "app_allowed_cidrs" {
  type    = list(string)
  default = []
}

variable "key_name" {
  type        = string
  description = "Name of an existing EC2 key pair"
}

variable "django_instance_type" {
  type    = string
  default = "t3.small"
}

variable "postgres_instance_type" {
  type    = string
  default = "t3.small"
}

variable "postgres_data_volume_size" {
  type    = number
  default = 20
}

variable "enable_ssh" {
  type        = bool
  default     = false
  description = "Open port 22 to admin_cidr. Off by default: admin access goes through SSM Session Manager"
}

variable "enable_ssm" {
  type    = bool
  default = true
}

variable "alarm_email" {
  type        = string
  default     = ""
  description = "Email for CloudWatch alarm notifications, empty disables SNS"
}

variable "snapshot_retain_count" {
  type    = number
  default = 7
}

variable "backup_retention_days" {
  type    = number
  default = 14
}

variable "cpu_alarm_threshold" {
  type    = number
  default = 80
}

variable "disk_alarm_threshold" {
  type    = number
  default = 85
}
