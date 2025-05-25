terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "lambda_image_uri" { type = string }
variable "environment" { default = "dev" }

locals {
  name = "acidizer-${var.environment}"
}

# Reference existing resources
data "aws_ecr_repository" "backend" { name = "${local.name}-backend" }
data "aws_dynamodb_table" "counter" { name = "${local.name}-counter" }
data "aws_iam_role" "lambda_role" { name = "${local.name}-lambda-role" }

# Lambda function (the backend brain)
resource "aws_lambda_function" "backend" {
  function_name = "${local.name}-backend"
  role          = data.aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = var.lambda_image_uri
  timeout       = 30
  memory_size   = 256
  environment {
    variables = {
      DYNAMODB_TABLE_NAME = data.aws_dynamodb_table.counter.name
    }
  }
}

# API Gateway with throttling (senior approach)
resource "aws_api_gateway_rest_api" "api" {
  name = "${local.name}-api"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Throttling configuration
resource "aws_api_gateway_usage_plan" "api_plan" {
  name = "${local.name}-usage-plan"

  throttle_settings {
    rate_limit  = 10   # 10 requests per second
    burst_limit = 20   # 20 burst capacity
  }

  quota_settings {
    limit  = 10000     # 10k requests per day
    period = "DAY"
  }

  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_deployment.api.stage_name
  }
}

# Request validator for size limits
resource "aws_api_gateway_request_validator" "validator" {
  name                        = "${local.name}-validator"
  rest_api_id                = aws_api_gateway_rest_api.api.id
  validate_request_body       = true
  validate_request_parameters = false
}

# Methods with validation
resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "post" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_rest_api.api.root_resource_id
  http_method          = "POST"
  authorization        = "NONE"
  request_validator_id = aws_api_gateway_request_validator.validator.id
}

# Integrations
resource "aws_api_gateway_integration" "options" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  http_method             = "OPTIONS"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.backend.invoke_arn
}

resource "aws_api_gateway_integration" "get" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  http_method             = "GET"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.backend.invoke_arn
}

resource "aws_api_gateway_integration" "post" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  http_method             = "POST"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.backend.invoke_arn
}

resource "aws_lambda_permission" "api" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = var.environment
  depends_on = [
    aws_api_gateway_integration.get,
    aws_api_gateway_integration.post,
    aws_api_gateway_integration.options,
  ]
}

# Frontend S3 bucket
resource "aws_s3_bucket" "frontend" {
  bucket = "${local.name}-frontend"
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"  # SPA fallback
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  depends_on = [aws_s3_bucket_public_access_block.frontend]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      },
    ]
  })
}

# CloudFront distribution for frontend (with caching and HTTPS)
resource "aws_cloudfront_distribution" "frontend" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.frontend.website_endpoint
    origin_id   = "S3-${aws_s3_bucket.frontend.id}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.frontend.id}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # SPA fallback - serve index.html for all 404s
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${local.name}-frontend"
    Environment = var.environment
  }
}

# Outputs
output "api_url" {
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.us-east-1.amazonaws.com/${var.environment}"
  description = "Backend API URL"
}

output "frontend_bucket" {
  value       = aws_s3_bucket.frontend.bucket
  description = "Frontend S3 bucket name"
}

output "frontend_url" {
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
  description = "Frontend CloudFront URL"
}