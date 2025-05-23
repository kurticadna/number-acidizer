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

# API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name = "${local.name}-api"
}

resource "aws_api_gateway_method" "get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "POST"
  authorization = "NONE"
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
  ]
}

# Only output what you need
output "api_url" {
  value = "https://${aws_api_gateway_rest_api.api.id}.execute-api.us-east-1.amazonaws.com/${var.environment}"
}