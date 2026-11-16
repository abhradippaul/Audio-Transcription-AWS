variable "aws_profile" {
  type        = string
  description = "AWS CLI profile to use."
  default     = "pa-abhradip"
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy to."
  default     = "ap-south-1"
}

variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket."
  default     = "audio-transcription-aws-bucket"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the S3 bucket."
  default = {
    Name        = "Audio-Transcription-AWS"
    Environment = "Dev"
    Project     = "Audio-Transcription-AWS"
  }
}

variable "lambda_function_name_dispatcher" {
  type        = string
  description = "The name of the Lambda function."
  default     = "audio-transcription-aws-dispatcher"
}

variable "lambda_source_path_dispatcher" {
  type        = string
  description = "The path to the Lambda function code."
  default     = "../Lambda/Dispatcher"
}

variable "lambda_function_name_worker" {
  type        = string
  description = "The name of the Lambda function."
  default     = "audio-transcription-aws-worker"
}

variable "lambda_source_path_worker" {
  type        = string
  description = "The path to the Lambda function code."
  default     = "../Lambda/Worker"
}

variable "lambda_handler" {
  type        = string
  description = "The handler of the Lambda function."
  default     = "main.handler"
}

variable "lambda_runtime" {
  type        = string
  description = "The runtime of the Lambda function."
  default     = "python3.13"
}

variable "lambda_worker_memory_size" {
  type        = number
  description = "The memory size of the worker Lambda function."
  default     = 3008
}

variable "lambda_worker_timeout" {
  type        = number
  description = "The timeout of the worker Lambda function."
  default     = 900
}

variable "lambda_worker_architecture" {
  type        = string
  description = "The architecture of the worker Lambda function (arm64 or x86_64)."
  default     = "x86_64"
}

variable "sqs_name" {
  type        = string
  description = "The name of the SQS queue."
  default     = "audio-transcription-aws-sqs"
}

variable "sqs_queue_delay_seconds" {
  type        = number
  description = "The delay of the SQS queue."
  default     = 0
}

variable "sqs_queue_max_message_size" {
  type        = number
  description = "The maximum message size of the SQS queue."
  default     = 262144
}

variable "sqs_queue_message_retention_seconds" {
  type        = number
  description = "The message retention period of the SQS queue."
  default     = 345600
}

variable "sqs_queue_receive_wait_time_seconds" {
  type        = number
  description = "The receive wait time of the SQS queue."
  default     = 0
}

variable "sqs_queue_visibility_timeout_seconds" {
  type        = number
  description = "The visibility timeout of the SQS queue."
  default     = 300
}

variable "ecr_repository_name" {
  type        = string
  description = "The name of the ECR repository."
  default     = "audio-transcription-aws-ecr"
}

variable "lambda_worker_ephemeral_storage" {
  type        = number
  description = "The ephemeral storage size of the worker Lambda function."
  default     = 10240
}
