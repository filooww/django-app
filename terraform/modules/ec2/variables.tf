variable "name" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "instance_profile_name" {
  type = string
}

variable "key_name" {
  type = string
}

variable "root_volume_size" {
  type    = number
  default = 20
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "metadata_hop_limit" {
  type        = number
  default     = 1
  description = "IMDSv2 hop limit. 2 lets containers in a Docker bridge network reach the instance role credentials"

  validation {
    condition     = var.metadata_hop_limit >= 1 && var.metadata_hop_limit <= 2
    error_message = "metadata_hop_limit must be 1 or 2."
  }
}
