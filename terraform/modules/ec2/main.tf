resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.key_name

  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true

    tags = { Name = "${var.name}-root" }
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = merge(var.tags, { Name = var.name })

  lifecycle {
    ignore_changes = [ami]
  }
}
