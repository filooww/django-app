variable "name" {
  type = string
}

variable "availability_zone" {
  type = string
}

variable "instance_id" {
  type = string
}

variable "size" {
  type    = number
  default = 20
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "device_name" {
  type    = string
  default = "/dev/sdf"
}
