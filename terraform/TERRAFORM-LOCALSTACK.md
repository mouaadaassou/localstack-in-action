#### Terraform met Localstack:
In order to provision the AWS resources on localstack using terraform, we need first to override the AWS resources endpoints - as each AWS resource has a specific endpoint,
for example, EC2 endpoint is https://ec2.region-name-here.awsamazon.com, ...

for that, we will add this configuration to our terraform main.tf:
```terraform
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
```

#### Creating SNS:

##### Testing the SNS using AWS CLI:
```
# To avoid setting the endpoint-url everytime...
alias stck='aws --endpoint-url=http://localhost:4566'

# Publishing some messages to SNS
stck sns publish --topic-arn arn:aws:sns:eu-central-1:000000000000:localstack_sns.fifo --message-deduplication-id '2' --message-group 'localstack' --message 'two-message'
```

##### Testing SQS Subscription to SNS:
```
# first we can list all queues, to copy the queue-url of our SQS
stck sqs list-queues

# now, we can receive the message previously published to the SNS
stck sqs receive-message --queue-url queue-url-from-previous-command
```

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "allowEc2InstanceToAssumeRole",
    "Action": "sts:AssumeRole",
    "Effect": "Allow",
    "Principal": {
      "Service": "ec2.awsamazon.com"
    }
  }]
}
```


## LocalStack Limitation:
So far, LocalStack does not enforce/validate the IAM policies, so don't rely on Localstack to test
you IAM policies and roles... they are providing a pro/enterprise version - 24$/month - that provide this feature
of validating and enforcing IAM permissions.