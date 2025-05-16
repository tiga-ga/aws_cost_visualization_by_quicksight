provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      repository_name = "aws_cost_visualization_by_quicksight"
    }
  }
}

# us-east-1 (バージニア) リージョン用のプロバイダー
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      repository_name = "aws_cost_visualization_by_quicksight"
    }
  }
}