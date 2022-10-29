# Localstack for Local Development:

## Introduction:
Provisioning AWS Infrastructures to your applications can be complex - Creating the AWS infrastructures (SQS, SNS, Lambda, S3, ...) with a fine grained permissions model might tak times,
and then try to integrate your infrastructure with your Applications will take some time until you test ...
for that, usually teams split the responsibilities of provisioning the infrastructure and integrating them with your applications,
and...


### Starting And Managing Localstack:
You can set up localstack in different ways - install its binary script that starts a docker container,
and set all the infrastructure needed - or using Docker or docker-compose. for the full list of the available options [you can check this list](https://docs.localstack.cloud/get-started/)

In our Lab we will use docker-compose to lunch localstack, you can use the [docker-compose associated with tha lab](./docker/docker-compose.yaml).
I choose docker because I don't need to install any additional binary into my machine, I can lunch it and drop the container any time. 

### LocalStack with Docker and AWS CLI:
You can use [the official docker-compose file from Localstack repo](https://github.com/localstack/localstack/blob/master/docker-compose.yml), you can remove the unnecessary ports - only required for Pro - 
as we are using the free localstack.

the minimalist docker-compose.yaml [can be found here](./docker/docker-compose.yaml), and in order to lunch the service,
just execute the fol<lowing command - I am running it in the background (-d parameter)
```bash
docker compose -f docker/docker-compose.yaml up -d
```

## LocalStack Lab:
### Scenario:
In This Lab, We will create an SNS that has an SQS subscribed to it, and a Lambda that starts listens on that SQS, and then process the message and upload it to an S3. 
the lab will use AWS CLI to provision the infrastructure as a first option, then, we will try to do the same using terraform to create all these resources on both environments - local - using localstack, and on AWS.

![SNS-SQS-Lambda-S3-Scenario](./img/scenario.png)

### Provisioning the necessary AWS Infrastructure:


#### Setting Up the AWS Configuration for Localstack:
In order to interact with localstack, you can use the AWS CLI, but you have to configure it before. you can run aws configure command:
```bash
> aws configure --profile localstack
AWS Access Key ID [None]: foo
AWS Secret Access Key [None]: bar
Default region name [None]: eu-central-1
Default output format [None]: json
```

then try to set the profile in your CLI - so that you avoid specifying your profile everytime you use AWS CLI:
```bash
export AWS_PROFILE=localstack
```
I am also setting the AWS PAGER, so that It will send you command result into a pager
```bash
export AWS_PAGER=""
export EP='http://localhost:4566'
```

We can check our configuration by listing the topics:
```bash
> aws sns --endpoint-url $ET  list-topics
{
    "Topics": []
}
```

#### AWS CLI with Localstack:
The first place will be creating the SQS between the SNS as the Lambda function, use the following command to create it:
```bash
aws sns --endpoint-url $EP create-topic --name localstack-lab-sns
```

Now if you try to list the topics in localstack, you will find the one created just before:
```bash
> aws sns --endpoint-url $ET  list-topics
{
    "Topics": [
        {
            "TopicArn": "arn:aws:sns:eu-central-1:000000000000:localstack-lab-sns"
        }
    ]
}
```
Now we can create the SQS that will subscribe to the SNS, but before that, we need to create the DLQ associated with our future SQS:
```bash
> aws sqs --endpoint-url $EP create-queue --queue-name localstack-lab-sqs-dlq
{
    "QueueUrl": "http://localhost:4566/000000000000/localstack-lab-sqs-dlq"
} 
```

Now we created our DLQ, we can proceed and create the SQS:
```bash
>aws sqs --endpoint-url $EP create-queue --queue-name localstack-lab-sqs --attributes file://cli/queue-attributes.json
{
    "QueueUrl": "http://localhost:4566/000000000000/localstack-lab-sqs"
}
```
the queue-attributes.json file contains the attributes for the SQS:
```json
{
  "RedrivePolicy": "{\"deadLetterTargetArn\":\"http://localhost:4566/000000000000/localstack-lab-sqs-dlq\",\"maxReceiveCount\":\"3\"}",
  "MessageRetentionPeriod": "259200",
  "VisibilityTimeout": "900",
  "DelaySeconds": "0"
}
```

After creating the SNS, SQS, and the SQS DLQ, we need to subscribe SQS to the SNS topic, but for that, we need to get the queue arn first:
```bash
> aws sqs get-queue-attributes --endpoint-url $EP --queue-url http://localhost:4566/000000000000/localstack-lab-sqs --attribute-names All
{
    "Attributes": {
        "ApproximateNumberOfMessages": "0",
        "ApproximateNumberOfMessagesNotVisible": "0",
        "ApproximateNumberOfMessagesDelayed": "0",
        "CreatedTimestamp": "1667000993",
        "DelaySeconds": "0",
        "LastModifiedTimestamp": "1667000993",
        "MaximumMessageSize": "262144",
        "MessageRetentionPeriod": "259200",
        "QueueArn": "arn:aws:sqs:eu-central-1:000000000000:localstack-lab-sqs",
        "ReceiveMessageWaitTimeSeconds": "0",
        "VisibilityTimeout": "900",
        "SqsManagedSseEnabled": "false",
        "RedrivePolicy": "{\"deadLetterTargetArn\":\"http://localhost:4566/000000000000/localstack-lab-sqs-dlq\",\"maxReceiveCount\":\"3\"}"
    }
}
```

after getting the SQS arn, we can subscribe the queue to the SNS as follow:
```bash
> aws sns subscribe --endpoint-url $EP --topic-arn arn:aws:sns:eu-central-1:000000000000:localstack-lab-sns --protocol sqs --notification-endpoint  arn:aws:sqs:eu-central-1:000000000000:localstack-lab-sqs
{
    "SubscriptionArn": "arn:aws:sns:eu-central-1:000000000000:localstack-lab-sns:44ec830b-a570-4525-bf96-118ca4160bd3"
}
```

Now we can test the SQS subscription by publishing a message to the topic, and it must be received it by the SQS: 
```bash
> aws --endpoint-url $EP sns publish --topic-arn arn:aws:sns:eu-central-1:000000000000:localstack-lab-sns  --message 'two-message'
{
    "MessageId": "babff1a5-993f-42c2-99d5-0551c7f1083d"
}
```

Calling the SQS's receive-message to check if we have received the message from the SNS:
```bash
> aws sqs receive-message  --queue-url http://localhost:4566/000000000000/localstack-lab-sqs --endpoint-url $EP
{
    "Messages": [
        {
            "MessageId": "b622a77d-f411-40d9-9cb8-270abb13645a",
            "ReceiptHandle": "ODM3MTgxYjMtMTJkMC00ODI3LWJkYjUtYjBiMjdmOTZhMWUyIGFybjphd3M6c3FzOmV1LWNlbnRyYWwtMTowMDAwMDAwMDAwMDA6bG9jYWxzdGFjay1sYWItc3FzIGI2MjJhNzdkLWY0MTEtNDBkOS05Y2I4LTI3MGFiYjEzNjQ1YSAxNjY3MDAxODMzLjg4ODUyNzQ=",
            "MD5OfBody": "8fda4e7739d4037e60a18b8526b47aec",
            "Body": "{\"Type\": \"Notification\", \"MessageId\": \"babff1a5-993f-42c2-99d5-0551c7f1083d\", \"TopicArn\": \"arn:aws:sns:eu-central-1:000000000000:localstack-lab-sns\", \"Message\": \"two-message\", \"Timestamp\": \"2022-10-29T00:00:44.647Z\", \"SignatureVersion\": \"1\", \"Signature\": \"EXAMPLEpH+..\", \"SigningCertURL\": \"https://sns.us-east-1.amazonaws.com/SimpleNotificationService-0000000000000000000000.pem\", \"UnsubscribeURL\": \"http://localhost:4566/?Action=Unsubscribe&SubscriptionArn=arn:aws:sns:eu-central-1:000000000000:localstack-lab-sns:44ec830b-a570-4525-bf96-118ca4160bd3\"}"
        }
    ]
}
```
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