# 収集先のS3バケット
resource "aws_s3_bucket" "cur_destination" {
  bucket   = var.destination_bucket_name
  force_destroy = true # バケットを削除するときにオブジェクトも削除する(実際に使う場合はfalseにする)
}

# 送信先バケットのバージョニング設定
resource "aws_s3_bucket_versioning" "cur_destination" {
  bucket = aws_s3_bucket.cur_destination.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 収集先のバケットポリシー
resource "aws_s3_bucket_policy" "cur_destination" {
  bucket   = aws_s3_bucket.cur_destination.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "Permissions on objects and buckets"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "s3:List*",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:ReplicateDelete",
          "s3:ReplicateObject",
          "s3:ObjectOwnerOverrideToBucketOwner"
        ]
        Resource = [
          "arn:aws:s3:::${var.destination_bucket_name}",
          "arn:aws:s3:::${var.destination_bucket_name}/*"
        ]
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = [
              for account_id in var.source_account_list :
              "arn:aws:iam::${account_id}:role/s3-replication-role"
            ]
          }
        }
      }
    ]
  })
}

# Glueデータベースの作成
resource "aws_glue_catalog_database" "cur_database" {
  for_each = toset(var.source_account_list)
  name     = "cur-database-${each.value}"
}

# Glueクローラーの作成
resource "aws_glue_crawler" "cur_crawler" {
  for_each = toset(var.source_account_list)
  depends_on    = [aws_s3_bucket.cur_destination, aws_glue_catalog_database.cur_database]
  database_name = aws_glue_catalog_database.cur_database[each.value].name
  name          = "cur-crawler-${each.value}"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.cur_destination.id}/store-cur-data/cur-report-${each.value}/"
    exclusions = ["**[!.csv.gz]"] # csv.gz以外のファイルを除外
  }
  
  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      Tables = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
  })

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }
}

# Glue用のIAMロール
resource "aws_iam_role" "glue_role" {
  name = "cudos-glue-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume_role_policy.json
}

# Glue用のポリシー
resource "aws_iam_role_policy" "glue_policy" {
  name = "cudos-glue-policy"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:*",
          "s3:*",
          "ec2:*",
          "logs:*",
          "iam:*",
          "cloudwatch:*",
        ]
        Resource = [
          "*"
        ]
      }
    ]
  })
}

# ETLスクリプトのアップロード
resource "aws_s3_object" "etl_script" {
  bucket   = aws_s3_bucket.cur_destination.id
  key      = "scripts/extract_cur_data.py"
  source   = "${path.module}/scripts/extract_cur_data.py"
  etag     = filemd5("${path.module}/scripts/extract_cur_data.py")
}

# Glue ETLジョブ
resource "aws_glue_job" "extract_cur_data" {
  for_each = toset(var.source_account_list)
  
  name         = "extract-cur-data-${each.value}"
  role_arn     = aws_iam_role.glue_role.arn
  glue_version = "4.0"
  
  command {
    script_location = "s3://${aws_s3_bucket.cur_destination.id}/scripts/extract_cur_data.py"
    python_version  = "3"
  }

  default_arguments = {
    "--database_name" = aws_glue_catalog_database.cur_database[each.value].name
    "--output_path"   = "s3://${aws_s3_bucket.cur_destination.id}/extracted-data/${each.value}"
    "--output_filename" = "cur-summary-${each.value}"
    "--enable-spark-ui" = "true"
    "--enable-metrics" = "true"
    "--enable-continuous-cloudwatch-log" = "true"
  }
}

# Step Functions用のIAMロール
resource "aws_iam_role" "stepfunctions_role" {
  name     = "cudos-stepfunctions-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

# Step Functions用のポリシー
resource "aws_iam_role_policy" "stepfunctions_policy" {
  name     = "cudos-stepfunctions-policy"
  role     = aws_iam_role.stepfunctions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:*",
          "logs:*",
          "s3:*",
          "ec2:*",
          "iam:*",
        ]
        Resource = [
          "*",
          "arn:aws:s3:::${aws_s3_bucket.cur_destination.id}",
          "arn:aws:s3:::${aws_s3_bucket.cur_destination.id}/*"
        ]
      }
    ]
  })
}

# Step Functionsステートマシン
resource "aws_sfn_state_machine" "cur_workflow" {
  
  name        = "BillingDataExtract"
  role_arn    = aws_iam_role.stepfunctions_role.arn
  definition  = file("${path.module}/stepfunctions/cur-data-process.json")
  type        = "STANDARD"
}

# EventBridgeルール
resource "aws_cloudwatch_event_rule" "start_workflow" {
  
  name        = "start-BillingDataExtract-workflow"
  description = "Start BillingDataExtract workflow"
  
  schedule_expression = var.schedule
}

# EventBridge用のIAMロール
resource "aws_iam_role" "eventbridge_role" {
  name     = "cudos-eventbridge-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

# EventBridge用のポリシー
resource "aws_iam_role_policy" "eventbridge_policy" {
  name     = "cudos-eventbridge-policy"
  role     = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = [
          aws_sfn_state_machine.cur_workflow.arn
        ]
      }
    ]
  })
}

# EventBridgeターゲット
resource "aws_cloudwatch_event_target" "workflow_target" {
  rule      = aws_cloudwatch_event_rule.start_workflow.name
  target_id = "StartCURWorkflow"
  arn       = aws_sfn_state_machine.cur_workflow.arn
  role_arn  = aws_iam_role.eventbridge_role.arn
  input     = jsonencode({
    source_account_id = var.source_account_list
    bucket_name = aws_s3_bucket.cur_destination.id
  })
}

# マニフェストのアップロード
resource "aws_s3_object" "manifest" {
  bucket = aws_s3_bucket.cur_destination.id
  key    = "manifest.json"
  content = jsonencode({
    fileLocations = [
      {
        URIPrefixes = [
          "https://${aws_s3_bucket.cur_destination.bucket_regional_domain_name}/extracted-data",
        ]
      }
    ],
    globalUploadSettings = {
      format = "CSV"
    }
  })
}

