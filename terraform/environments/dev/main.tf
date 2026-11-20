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

resource "aws_iam_role" "ec2" {
  name               = "${local.name}-ec2"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count = var.enable_ssm ? 1 : 0

  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "parameter_store" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/${var.environment}/*"]
  }
}

resource "aws_iam_role_policy" "parameter_store" {
  name   = "parameter-store-read"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.parameter_store.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name}-ec2"
  role = aws_iam_role.ec2.name
}

# Compute

module "django" {
  source = "../../modules/ec2"

  name                  = "${local.name}-django"
  ami_id                = data.aws_ami.ubuntu.id
  instance_type         = var.django_instance_type
  subnet_id             = module.vpc.public_subnet_id
  security_group_ids    = [module.security_groups.django_sg_id]
  instance_profile_name = aws_iam_instance_profile.ec2.name
  key_name              = var.key_name
  tags                  = { Role = "django" }
}

module "postgres" {
  source = "../../modules/ec2"

  name                  = "${local.name}-postgres"
  ami_id                = data.aws_ami.ubuntu.id
  instance_type         = var.postgres_instance_type
  subnet_id             = module.vpc.public_subnet_id
  security_group_ids    = [module.security_groups.postgres_sg_id]
  instance_profile_name = aws_iam_instance_profile.ec2.name
  key_name              = var.key_name
  tags                  = { Role = "postgres" }
}

module "postgres_data" {
  source = "../../modules/ebs"

  name              = "${local.name}-postgres-data"
  availability_zone = module.postgres.availability_zone
  instance_id       = module.postgres.id
  size              = var.postgres_data_volume_size
}
