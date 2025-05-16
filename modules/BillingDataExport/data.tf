data "aws_iam_policy_document" "source" {
  statement {
    sid    = "AllowCURReport"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketPolicy",
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.source.arn}",
      "${aws_s3_bucket.source.arn}/*"
    ]
  }
}