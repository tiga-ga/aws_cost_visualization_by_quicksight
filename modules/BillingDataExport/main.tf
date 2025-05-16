data "aws_caller_identity" "current" {}

# 送信元バケットの作成
resource "aws_s3_bucket" "source" {
  bucket = "source-cur-data-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # バケットを削除するときにオブジェクトも削除する(実際に使う場合はfalseにする)
}

# 送信元バケットのバージョニング設定
resource "aws_s3_bucket_versioning" "source" {
  bucket = aws_s3_bucket.source.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 送信元バケットのバケットポリシー
resource "aws_s3_bucket_policy" "source" {
  bucket = aws_s3_bucket.source.id
  policy = data.aws_iam_policy_document.source.json
}

# レプリケーション設定
resource "aws_s3_bucket_replication_configuration" "replication" {
  depends_on = [aws_s3_bucket_versioning.source, aws_iam_role.replication]

  bucket = aws_s3_bucket_versioning.source.id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "replication1"
    status = "Enabled"

    filter {}

    destination {
      bucket = "arn:aws:s3:::${var.destination_bucket_name}"
      account = var.destination_account_id
      access_control_translation {
        owner = "Destination"
      }
      metrics {
        status = "Enabled"
      }
    }

    delete_marker_replication {
      status = "Enabled"
    }

    source_selection_criteria {
      replica_modifications {
        status = "Enabled"
      }
    }

    priority = 1
  }
}

# レプリケーション用のIAMロール
resource "aws_iam_role" "replication" {
  name = "s3-replication-role"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

# レプリケーション用のIAMポリシー
resource "aws_iam_role_policy" "replication" {
  name = "s3-replication-policy"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetSourceBucketConfiguration"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketAcl",
          "s3:GetReplicationConfiguration",
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = [
          aws_s3_bucket.source.arn,
          "${aws_s3_bucket.source.arn}/*"
        ]
      },
      {
        Sid    = "ReplicateToDestinationBuckets"
        Effect = "Allow"
        Action = [
          "s3:List*",
          "s3:*Object",
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = [
          "arn:aws:s3:::${var.destination_bucket_name}*",
          "arn:aws:s3:::${var.destination_bucket_name}/*"
        ]
      },
      {
        Sid    = "PermissionToOverrideBucketOwner"
        Effect = "Allow"
        Action = [
          "s3:ObjectOwnerOverrideToBucketOwner"
        ]
        Resource = [
          "arn:aws:s3:::${var.destination_bucket_name}*",
          "arn:aws:s3:::${var.destination_bucket_name}/*"
        ]
      }
    ]
  })
}

# CURレポートの設定
resource "aws_cur_report_definition" "example_cur_report_definition" {
  depends_on = [aws_s3_bucket_versioning.source, aws_iam_role.replication]
  provider                   = aws.us_east_1
  report_name                = "cur-report-${data.aws_caller_identity.current.account_id}"
  time_unit                  = "DAILY"
  format                     = "textORcsv"
  compression                = "GZIP"
  additional_schema_elements = ["RESOURCES"]
  s3_bucket                 = aws_s3_bucket.source.id
  s3_prefix                 = "store-cur-data"
  s3_region                  = "ap-northeast-1"
  report_versioning         = "OVERWRITE_REPORT"
  refresh_closed_reports    = true
  additional_artifacts      = []
}

