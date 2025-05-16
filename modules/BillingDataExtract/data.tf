data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "glue_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "glue_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion", 
      "s3:ListBucket",
      "s3:ListBucketVersions"
    ]
    resources = [
      "${aws_s3_bucket.cur_destination.arn}",
      "${aws_s3_bucket.cur_destination.arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "glue:*",
      "athena:*"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "quicksight_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = ["quicksight.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "quicksight_policy" {
  statement {
    effect = "Allow"
    actions = [
      "athena:*",
      "glue:GetTable",
      "glue:GetTables", 
      "glue:GetDatabase",
      "glue:GetDatabases"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "${aws_s3_bucket.cur_destination.arn}",
      "${aws_s3_bucket.cur_destination.arn}/*"
    ]
  }
}