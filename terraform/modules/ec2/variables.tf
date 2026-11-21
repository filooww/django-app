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
