locals {
  name = "${var.project}-${var.environment}"
  az   = var.availability_zone != "" ? var.availability_zone : data.aws_availability_zones.available.names[0]
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Network

module "vpc" {
  source = "../../modules/vpc"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = local.az
}

module "security_groups" {
  source = "../../modules/security-groups"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  admin_cidr        = var.admin_cidr
  app_allowed_cidrs = var.app_allowed_cidrs
  enable_ssh        = var.enable_ssh
}

# IAM

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

locals {
  ec2_roles = toset(["django", "postgres"])
}

resource "aws_iam_role" "ec2" {
  for_each = local.ec2_roles

  name               = "${local.name}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  for_each = local.ec2_roles

  role       = aws_iam_role.ec2[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  for_each = var.enable_ssm ? local.ec2_roles : toset([])

  role       = aws_iam_role.ec2[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "parameter_store" {
  for_each = local.ec2_roles

  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/${var.environment}/${each.key}/*"]
  }

  # AmazonSSMManagedInstanceCore allows ssm:GetParameter on "*"; an explicit deny keeps each server out of the other's prefix
  statement {
    effect  = "Deny"
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = [
      for role in local.ec2_roles :
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/${var.environment}/${role}/*"
      if role != each.key
    ]
  }
}

resource "aws_iam_role_policy" "parameter_store" {
  for_each = local.ec2_roles

  name   = "parameter-store-read"
  role   = aws_iam_role.ec2[each.key].id
  policy = data.aws_iam_policy_document.parameter_store[each.key].json
}

resource "aws_iam_instance_profile" "ec2" {
  for_each = local.ec2_roles

  name = "${local.name}-${each.key}"
  role = aws_iam_role.ec2[each.key].name
}

# Compute

module "django" {
  source = "../../modules/ec2"

  name                  = "${local.name}-django"
  ami_id                = data.aws_ami.ubuntu.id
  instance_type         = var.django_instance_type
  subnet_id             = module.vpc.public_subnet_id
  security_group_ids    = [module.security_groups.django_sg_id]
  instance_profile_name = aws_iam_instance_profile.ec2["django"].name
  key_name              = var.key_name
  tags                  = { Role = "django" }
}

resource "aws_eip" "django" {
  domain   = "vpc"
  instance = module.django.id

  tags = { Name = "${local.name}-django" }
}

module "postgres" {
  source = "../../modules/ec2"

  name                  = "${local.name}-postgres"
  ami_id                = data.aws_ami.ubuntu.id
  instance_type         = var.postgres_instance_type
  subnet_id             = module.vpc.public_subnet_id
  security_group_ids    = [module.security_groups.postgres_sg_id]
  instance_profile_name = aws_iam_instance_profile.ec2["postgres"].name
  key_name              = var.key_name
  tags                  = { Role = "postgres" }
}

module "postgres_data" {
  source = "../../modules/ebs"

  name              = "${local.name}-postgres-data"
  availability_zone = module.postgres.availability_zone
  instance_id       = module.postgres.id
  size              = var.postgres_data_volume_size
  tags              = { Snapshot = "${local.name}-postgres-data" }
}
