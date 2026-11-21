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

variable "device_name" {
  type    = string
  default = "/dev/sdf"
}
