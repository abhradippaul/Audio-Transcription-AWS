import os
import urllib.parse
import boto3

sqs = boto3.client("sqs")

def handler(event, context):
    print(event)
    for rec in event.get("Records", []):
        bucket = rec["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(rec["s3"]["object"]["key"])
        s3_path = f"s3://{bucket}/{key}"

        sqs.send_message(
            QueueUrl=os.environ["QUEUE_URL"],
            MessageBody=s3_path
        )
        print(f"Accepted {s3_path}")
