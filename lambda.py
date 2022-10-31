from datetime import datetime
import boto3
import os

# use this http://localhost:4566 as endpoint_url in case you set the lambda execution to local,
# or you did not mount the Docker socket to the localstack container.
s3 = boto3.resource('s3', endpoint_url='http://host.docker.internal:4566')
BUCKET_NAME = os.environ['bucket_name']


def lambda_handler(event, context):
    print("Job Started...!")
    for record in event['Records']:
        bodyContent = record['body']
        date = datetime.now().strftime("%Y_%m_%d-%I_%M_%S")
        file_name = '/processed/message-' + date + '.json'
        object = s3.Object(BUCKET_NAME, file_name)
        object.put(Body=bodyContent)
    print("Job Ended  ...!")
    return {
        "statusCode": 200
    }
