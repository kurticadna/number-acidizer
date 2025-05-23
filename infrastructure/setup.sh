#!/bin/bash

ENV=${TF_VAR_environment:-dev}

aws ecr create-repository --repository-name acidizer-$ENV-backend 2>/dev/null
aws dynamodb create-table --table-name acidizer-$ENV-counter --attribute-definitions AttributeName=id,AttributeType=S --key-schema AttributeName=id,KeyType=HASH --billing-mode PAY_PER_REQUEST 2>/dev/null
aws iam create-role --role-name acidizer-$ENV-lambda-role --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' 2>/dev/null
aws iam put-role-policy --role-name acidizer-$ENV-lambda-role --policy-name acidizer-$ENV-lambda-policy --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],"Resource":"arn:aws:logs:*:*:*"},{"Effect":"Allow","Action":["dynamodb:GetItem","dynamodb:UpdateItem"],"Resource":"arn:aws:dynamodb:us-east-1:*:table/acidizer-'$ENV'-counter"}]}'

terraform import aws_ecr_repository.backend acidizer-$ENV-backend 2>/dev/null
terraform import aws_dynamodb_table.counter acidizer-$ENV-counter 2>/dev/null
terraform import aws_iam_role.lambda_role acidizer-$ENV-lambda-role 2>/dev/null
terraform import aws_lambda_function.backend acidizer-$ENV-backend 2>/dev/null