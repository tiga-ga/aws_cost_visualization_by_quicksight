terraform {
  backend "s3" {
    bucket = "tiga-terraform-aws-tfstate"
    key    = "terraform/aws_cost_visualization_by_quicksight/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
