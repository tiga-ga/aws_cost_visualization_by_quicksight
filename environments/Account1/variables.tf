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