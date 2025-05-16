variable "destination_account_id" {
  description = "AWS account ID where the CUR data will be stored"
  type        = string
  default     = ""
}

variable "destination_bucket_name" {
  description = "Name of the S3 bucket to store CUR data"
  type        = string
  default     = ""
} 

variable "source_account_list" {
  description = "List of AWS account IDs to collect CUR data from"
  type        = list(string)
  default     = []
}

variable "schedule" {
  description = "Cron expression for the Glue job schedule"
  type        = string
  default     = ""
}