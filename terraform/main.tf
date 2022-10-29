provider "aws" {
  access_key                  = "foo"
  secret_key                  = "bar"
  region                      = "eu-central-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    iam            = "http://localhost:4566"
    sts            = "http://localhost:4566"
    firehose       = "http://localhost:4566"
    kinesis        = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    s3             = "http://s3.localhost.localstack.cloud:4566"
    sns            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    stepfunctions  = "http://localhost:4566"
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
      numRetries = 3,
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

resource "aws_sns_topic_policy" "allow-everyone-to-publish" {
  arn    = aws_sns_topic.localstack_sns-fifo.arn
  policy = data.aws_iam_policy_document.allow-everyone-to-publish.json
}

resource "aws_sqs_queue" "localstack-sqs-fifo" {
  name = "localstack-sqs.fifo"
  delay_seconds = 0
  message_retention_seconds = 1209600 # 14 days
  visibility_timeout_seconds = 900 # 15 mins
  fifo_queue = true
  content_based_deduplication = false

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.localstack-sqs-dead-letter-fifo.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "localstack-sqs-dead-letter-fifo" {
  name = "localstack-sqs-dead-letter.fifo"
  fifo_queue = true
}
resource "aws_sns_topic_subscription" "user_updates_sqs_target" {
  topic_arn = aws_sns_topic.localstack_sns-fifo.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.localstack-sqs-fifo.arn
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

data "aws_iam_policy_document" "allow-everyone-to-publish" {
  version = "2012-10-17"
  statement {
    sid = "allowEveryoneToPublish"
    effect = "Allow"
    actions = ["sns:Publish*"]
    resources = [aws_sns_topic.localstack_sns-fifo.arn]
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
  }
}