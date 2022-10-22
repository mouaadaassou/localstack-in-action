provider "aws" {
  access_key                  = "foo"
  secret_key                  = "bar"
  region                      = "eu-central-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    apigateway     = "http://localhost:4566"
    apigatewayv2   = "http://localhost:4566"
    cloudformation = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    es             = "http://localhost:4566"
    elasticache    = "http://localhost:4566"
    firehose       = "http://localhost:4566"
    iam            = "http://localhost:4566"
    kinesis        = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    rds            = "http://localhost:4566"
    redshift       = "http://localhost:4566"
    route53        = "http://localhost:4566"
    s3             = "http://s3.localhost.localstack.cloud:4566"
    secretsmanager = "http://localhost:4566"
    ses            = "http://localhost:4566"
    sns            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    ssm            = "http://localhost:4566"
    stepfunctions  = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }

}

resource "aws_sns_topic" "localstack_sns-fifo" {
  fifo_topic = true
  name = "localstack_sns.fifo"
  display_name = "localstack_sns.fifo"
  # as this topic is a FIFO topic, it will discard duplicate messages within an interval of 5min, for that, we must provide tell SNS how to filter them - based on the message content,
  # or specify the deduplicate id at the time when sending the message - we will use a dedicated deduplication id.
  content_based_deduplication = false

  delivery_policy = jsonencode({
    defaultHealthyRetryPolicy = {
      minDelayTarget = 0,
      maxDelayTarget = 0,
      numRetries = 2,
      numMaxDelayRetries = 0,
      numNoDelayRetries = 0,
      numMinDelayRetries = 0,
      backoffFunction = "linear"
    },
    disableSubscriptionOverrides = true,
    defaultThrottlePolicy = {
      maxReceivesPerSecond = 1
    }
  })
}

resource "aws_s3_bucket" "localstack_bucket" {
  bucket = "localstack-bucket"
}

resource "aws_s3_bucket_acl" "localstack-bucket-acl" {
  bucket = aws_s3_bucket.localstack_bucket.id
  acl = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "localstack-bucket-standard-to-ia-to-glacier" {
  bucket = aws_s3_bucket.localstack_bucket.id


  rule {
    id = "log"
    status = "Enabled"

    transition {
      storage_class = "STANDARD_IA"
      days = 60
    }

    transition {
      storage_class = "GLACIER"
      days = 90
    }
  }
}