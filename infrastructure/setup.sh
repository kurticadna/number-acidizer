#!/bin/bash

aws ecr create-repository --repository-name acidizer-dev-backend 2>/dev/null
aws dynamodb create-table --table-name acidizer-dev-counter --attribute-definitions AttributeName=id,AttributeType=S --key-schema AttributeName=id,KeyType=HASH --billing-mode PAY_PER_REQUEST 2>/dev/null
aws iam create-role --role-name acidizer-dev-lambda-role --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' 2>/dev/null
aws iam put-role-policy --role-name acidizer-dev-lambda-role --policy-name acidizer-dev-lambda-policy --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],"Resource":"arn:aws:logs:*:*:*"},{"Effect":"Allow","Action":["dynamodb:GetItem","dynamodb:UpdateItem"],"Resource":"arn:aws:dynamodb:us-east-1:*:table/acidizer-dev-counter"}]}'

terraform import aws_ecr_repository.backend acidizer-dev-backend 2>/dev/null
terraform import aws_dynamodb_table.counter acidizer-dev-counter 2>/dev/null
terraform import aws_iam_role.lambda_role acidizer-dev-lambda-role 2>/dev/null
terraform import aws_lambda_function.backend acidizer-dev-backend 2>/dev/null