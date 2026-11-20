terraform {
  backend "s3" {
    key          = "dev/terraform.tfstate"
    region       = "eu-central-1"
    profile      = "devops"
    encrypt      = true
    use_lockfile = true
  }
}
