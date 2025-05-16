variable "destination_bucket_name" {
  description = "Name of the destination S3 bucket in the management account"
  type        = string
}

variable "source_account_list" {
  description = "List of source account ARNs that will replicate CUR data"
  type        = list(string)
}

variable "schedule" {
  description = "Schedule for the CloudWatch Event"
  type        = string
}