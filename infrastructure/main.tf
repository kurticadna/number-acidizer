terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "lambda_image_uri" {
  description = "ECR image URI for Lambda function"
  type        = string
}

locals {
  name_prefix = "acidizer-${var.environment}"
}

# ECR Repository
resource "aws_ecr_repository" "backend" {
  name = "${local.name_prefix}-backend"

  lifecycle {
    prevent_destroy = true
  }
}

# DynamoDB Table
resource "aws_dynamodb_table" "counter" {
  name         = "${local.name_prefix}-counter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  lifecycle {
    prevent_destroy = true
  }
}

# Lambda basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# DynamoDB policy for Lambda
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${local.name_prefix}-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ]
      Resource = aws_dynamodb_table.counter.arn
    }]
  })
}

# Lambda Function
resource "aws_lambda_function" "backend" {
  function_name = "${local.name_prefix}-backend"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = var.lambda_image_uri

  timeout     = 30
  memory_size = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.counter.name
      ENVIRONMENT         = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.lambda_dynamodb,
  ]
}

# API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name        = "${local.name_prefix}-api"
  description = "API for Number Acidizer"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Methods
resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "POST"
  authorization = "NONE"
}

# API Gateway Integrations
resource "aws_api_gateway_integration" "