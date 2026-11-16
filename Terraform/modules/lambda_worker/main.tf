data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  platform = var.architecture == "arm64" ? "linux/arm64" : "linux/amd64"
  image_tag = substr(sha256(join("", [
    filesha256("${var.source_path}/Dockerfile"),
    filesha256("${var.source_path}/requirements.txt"),
    filesha256("${var.source_path}/main.py"),
    var.architecture
  ])), 0, 8)
}

# IAM role for Lambda execution
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "this" {
  name               = "lambda_execution_role_processor"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_execution" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

data "aws_iam_policy_document" "lambda_s3" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = ["${var.s3_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "lambda_s3" {
  name   = "lambda_s3_policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.lambda_s3.json
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# Build and push container image to ECR using local-exec
resource "terraform_data" "lambda_package" {
  triggers_replace = [
    local.image_tag,
    local.platform
  ]

  provisioner "local-exec" {
    command = <<EOT
      set -e
      PROFILE_FLAG="${var.aws_profile != "" ? "--profile ${var.aws_profile}" : ""}"
      aws ecr get-login-password --region ${data.aws_region.current.region} $PROFILE_FLAG | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com

      # Create a buildx builder capable of multi-platform builds (no-op if it already exists)
      docker buildx inspect multiarch >/dev/null 2>&1 || docker buildx create --name multiarch --driver docker-container
      
      docker buildx build \
        --builder multiarch \
        --platform ${local.platform} \
        --provenance=false \
        --sbom=false \
        --output type=image,push=true,oci-mediatypes=false \
        -t ${var.ecr_repository_url}:latest \
        -t ${var.ecr_repository_url}:${local.image_tag} \
        ${var.source_path}
    EOT
  }
}

# Lambda function
resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.this.arn
  package_type  = "Image"
  memory_size   = var.memory_size
  timeout       = var.timeout
  image_uri     = "${var.ecr_repository_url}:${local.image_tag}"
  architectures = [var.architecture]

  ephemeral_storage {
    size = var.ephemeral_storage
  }

  # Advanced logging configuration
  logging_config {
    log_format            = "JSON"
    application_log_level = "INFO"
    system_log_level      = "INFO"
  }

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_sqs_execution,
    aws_iam_role_policy.lambda_s3,
    terraform_data.lambda_package
  ]

  environment {
    variables = var.environment_variables
  }

  tags = var.tags
}

resource "aws_lambda_event_source_mapping" "this" {
  event_source_arn        = var.sqs_arn
  function_name           = aws_lambda_function.this.arn
  batch_size              = 1
  function_response_types = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = 5
  }
}
