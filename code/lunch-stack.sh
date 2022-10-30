#!/bin/zsh
#!/usr/bin/env bash

export AWS_PAGER=""
alias awsls='aws --endpoint-url http://localhost:4566'
printf "\n\n#############################\n"
printf "### SNS-SQS-Lambda-S3 Lab ###\n"
printf "#############################\n"
printf "Do you want to lunch the stack or destroy it:\n\t * PRESS 1\n\t * PRESS 2\nOption to Select: "
read STACK_STATE

function creatingAwsLocalstackComponents() {
  printf "\nCreating FIFO SNS Topic\n"
  awsls sns create-topic --name "localstack-lab-sns.fifo" --attributes FifoTopic=true,ContentBasedDeduplication=false
  printf "\nCreating FIFO SQS DLQ\n"
  awsls sqs create-queue --queue-name localstack-lab-sqs-dlq.fifo --attributes FifoQueue=true,ContentBasedDeduplication=false,DelaySeconds=0
  printf "\nCreating FIFO SQS Queue\n"
  awsls sqs create-queue --queue-name localstack-lab-sqs.fifo --attributes file://code/queue-attributes.json
  printf "\nListing Queue Attributes\n"
  awsls sqs get-queue-attributes --queue-url http://localhost:4566/000000000000/localstack-lab-sqs.fifo --attribute-names All
  printf "\nSubscribing SQS to SNS topic\n"
  awsls sns subscribe --topic-arn arn:aws:sns:eu-central-1:000000000000:localstack-lab-sns.fifo --protocol sqs --notification-endpoint  arn:aws:sqs:eu-central-1:000000000000:localstack-lab-sqs.fifo
  printf "\nCreating S3 Bucket\n"
  awsls s3 mb s3://localstack-lab-bucket
  printf "\nZipping the Python lambda handler\n"
  zip lambda-handler.zip lambda.py
  printf "\nCreating The Lambda function\n"
  awsls lambda create-function --function-name queue-reader --zip-file fileb://lambda-handler.zip --handler lambda.lambda_handler --runtime python3.8 --role arn:aws:iam::000000000000:role/fake-role-role --environment Variables={bucket_name=localstack-lab-bucket}
  printf "\nCreating a mapping between an event source and an Lambda function\n"
  awsls lambda create-event-source-mapping --function-name queue-reader --batch-size 5 --maximum-batching-window-in-seconds 60  --event-source-arn arn:aws:sqs:eu-central-1:000000000000:localstack-lab-sqs.fifo
  printf "\nTesting Listing all Topics'n"
  awsls sns list-topics
  printf "\nTesting Listing all Queues\n"
  awsls sqs list-queues
  printf "\nTesting Listing S3 buckets\n"
  awsls s3 ls
  printf "\nTesting Listing Lambdas\n"
  awsls lambda list-functions
  printf "\n\n##Testing The Whole Flow ##\n\n"
  printf "\nSending an events to SNS\n"
  awsls sns publish --topic-arn arn:aws:sns:eu-central-1:000000000000:localstack-lab-sns.fifo --message-group-id='test' --message-deduplication-id='1111'  --message file://code/sqs-message.json
  printf "\nChecking that the SNS message is written to the S3 bucket\n"
  awsls s3 ls --recursive s3://localstack-lab-bucket
}

if [[ $STACK_STATE == '1' ]]; then
  printf "\nLunching localstack container\n"
  docker-compose -f "$(pwd)"/docker/docker-compose.yaml up -d && sleep 5
  printf "\nCreating AWS Lab Components\n"
  creatingAwsLocalstackComponents
elif [[ $STACK_STATE == '2' ]]; then
  printf "\ndeleting localstack container\n"
  docker-compose -f "$(pwd)"/docker/docker-compose.yaml down
else
  printf "Nothing to perform, please select option 1 or 2\n"
fi