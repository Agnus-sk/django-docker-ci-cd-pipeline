terraform {
  backend "s3" {
    bucket         = "django-terraform-state-aamy"
    key            = "global/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}
