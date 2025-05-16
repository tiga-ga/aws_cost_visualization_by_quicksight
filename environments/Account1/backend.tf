terraform {
  backend "s3" {
    bucket = "tiga-terraform-aws-tfstate2"
    key    = "terraform/aws_cost_visualization_by_quicksight/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
