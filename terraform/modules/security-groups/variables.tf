variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "admin_cidr" {
  type        = string
  description = "Admin IP in CIDR form, e.g. 203.0.113.10/32"

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr must be a valid CIDR and must not be 0.0.0.0/0."
  }
}

variable "app_allowed_cidrs" {
  type    = list(string)
  default = []
}

variable "app_port" {
  type    = number
  default = 8000
}
