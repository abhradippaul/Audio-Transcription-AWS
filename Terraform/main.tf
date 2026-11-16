module "lambda_module_dispatcher" {
  source = "./modules/lambda_dispatcher"

  function_name = var.lambda_function_name_dispatcher
  source_path   = var.lambda_source_path_dispatcher
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  tags          = var.tags
  s3_bucket_arn = module.s3_bucket_module.s3_bucket_arn
  sqs_arn       = module.sqs_module.sqs_queue_arn
  environment_variables = {
    QUEUE_URL = module.sqs_module.sqs_queue_url
  }
}

module "sqs_module" {
  source = "./modules/sqs"

  name                       = var.sqs_name
  delay_seconds              = var.sqs_queue_delay_seconds
  max_message_size           = var.sqs_queue_max_message_size
  message_retention_seconds  = var.sqs_queue_message_retention_seconds
  receive_wait_time_seconds  = var.sqs_queue_receive_wait_time_seconds
  visibility_timeout_seconds = var.sqs_queue_visibility_timeout_seconds
  tags                       = var.tags
}

module "s3_bucket_module" {
  source = "./modules/s3_bucket"

  bucket_name         = var.bucket_name
  tags                = var.tags
  lambda_function_arn = module.lambda_module_dispatcher.lambda_function_arn
}

module "ecr_module" {
  source              = "./modules/ecr"
  ecr_repository_name = var.ecr_repository_name
  tags                = var.tags
}

module "lambda_module_worker" {
  source = "./modules/lambda_worker"

  function_name      = var.lambda_function_name_worker
  source_path        = var.lambda_source_path_worker
  tags               = var.tags
  s3_bucket_arn      = module.s3_bucket_module.s3_bucket_arn
  sqs_arn            = module.sqs_module.sqs_queue_arn
  ecr_repository_url = module.ecr_module.repository_url
  memory_size        = var.lambda_worker_memory_size
  timeout            = var.lambda_worker_timeout
  aws_profile        = var.aws_profile
  ephemeral_storage  = var.lambda_worker_ephemeral_storage
  architecture       = var.lambda_worker_architecture


  environment_variables = {
    INPUT_BUCKET      = module.s3_bucket_module.s3_bucket_name
    OUTPUT_BUCKET     = module.s3_bucket_module.s3_bucket_name
    WHISPER_MODEL     = "base"
    WHISPER_MODEL_DIR = "/opt/whisper"
  }

  depends_on = [module.ecr_module]
}
