variable "function_name" {
  type        = string
  description = "The name of the Lambda function."
}

variable "source_path" {
  type        = string
  description = "The path to the Lambda function code."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the Lambda function."
  default     = {}
}

variable "log_retention_days" {
  type        = number
  description = "The number of days to retain the log group."
  default     = 14
}

variable "sqs_arn" {
  type        = string
  description = "The ARN of the SQS queue."
}

variable "s3_bucket_arn" {
  type        = string
  description = "The ARN of the S3 bucket for audio input and transcription output."
}

variable "ecr_repository_url" {
  type        = string
  description = "The URL of the ECR repository."
}

variable "memory_size" {
  type        = number
  description = "The memory size of the Lambda function."
  default     = 3072
}

variable "timeout" {
  type        = number
  description = "The timeout of the Lambda function."
  default     = 300
}

variable "environment_variables" {
  type        = map(string)
  description = "The environment variables of the Lambda function."
  default     = {}
}

variable "aws_profile" {
  type        = string
  description = "AWS profile to use for Docker authentication."
}

variable "ephemeral_storage" {
  type        = number
  description = "The ephemeral storage size of the Lambda function."
  default     = 10240
}

variable "architecture" {
  type        = string
  description = "The architecture of the Lambda function (arm64 or x86_64)."
  default     = "x86_64"
}
