terraform {
  backend "s3" {
    bucket       = "saynow-prod-terraform-state-494873119837"
    key          = "prod/saynow-iac/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
