
import os
import json
import logging
import tempfile
from pathlib import PurePosixPath

import boto3
import whisper

# --------------------------------------------------
# 1. Configuration
# --------------------------------------------------

INPUT_BUCKET = os.environ["INPUT_BUCKET"]
OUTPUT_BUCKET = os.environ["OUTPUT_BUCKET"]

MODEL_NAME = os.environ.get("WHISPER_MODEL", "base")
MODEL_DIR = os.environ.get("WHISPER_MODEL_DIR", "/opt/whisper")

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Create AWS clients outside the handler.
# These can be reused across Lambda invocations.
s3 = boto3.client("s3")

# Global model cache.
# The model will be loaded only once per warm
# Lambda execution environment.
whisper_model = None


# --------------------------------------------------
# 2. Load Whisper model
# --------------------------------------------------

def get_whisper_model():
    global whisper_model

    if whisper_model is None:
        logger.info("Loading Whisper model: %s", MODEL_NAME)

        whisper_model = whisper.load_model(
            MODEL_NAME,
            download_root=MODEL_DIR
        )

        logger.info("Whisper model loaded successfully")

    return whisper_model


# --------------------------------------------------
# 3. Download audio from S3
# --------------------------------------------------

def download_audio(bucket, key, local_path):

    logger.info("Downloading s3://%s/%s", bucket, key)

    s3.download_file(
        bucket,
        key,
        local_path
    )

    logger.info("Audio downloaded successfully")


# --------------------------------------------------
# 4. Transcribe audio using Whisper
# --------------------------------------------------

def transcribe_audio(audio_path, language=None):

    model = get_whisper_model()

    logger.info("Starting transcription")

    options = {
        "fp16": False
    }

    if language:
        options["language"] = language

    result = model.transcribe(
        audio_path,
        **options
    )

    transcription = result["text"].strip()

    logger.info("Transcription completed")

    return transcription


# --------------------------------------------------
# 5. Upload transcription to S3
# --------------------------------------------------

def upload_transcription(input_key, transcription):

    # Preserve subdirectories and change extension.
    relative_path = PurePosixPath(input_key)

    if relative_path.parts and relative_path.parts[0] == "audio-input":
        rel = relative_path.relative_to("audio-input")
        output_key = f"audio-output/{rel.with_suffix('.txt')}"
    else:
        output_filename = relative_path.with_suffix(".txt").name
        output_key = (
            "audio-output/"
            + str(relative_path.parent.relative_to("."))
            + "/"
            + output_filename
        ).replace("./", "", 1)

    logger.info(
        "Uploading transcription to s3://%s/%s",
        OUTPUT_BUCKET,
        output_key
    )

    s3.put_object(
        Bucket=OUTPUT_BUCKET,
        Key=output_key,
        Body=transcription.encode("utf-8"),
        ContentType="text/plain; charset=utf-8"
    )

    logger.info("Transcription uploaded successfully")

    return output_key


# --------------------------------------------------
# 6. Process one SQS message
# --------------------------------------------------

def process_message(record):

    message_id = record["messageId"]

    # SQS message body can be a JSON payload or a plain S3 URI.
    body_str = record["body"].strip()
    language = None
    try:
        message = json.loads(body_str)
        if isinstance(message, dict):
            bucket = message["bucket"]
            key = message["key"]
            language = message.get("language")
        elif isinstance(message, str) and message.startswith("s3://"):
            s3_path = message[5:]
            bucket, key = s3_path.split("/", 1)
        else:
            raise ValueError(f"Unsupported JSON format: {message}")
    except (json.JSONDecodeError, KeyError, ValueError):
        if body_str.startswith("s3://"):
            s3_path = body_str[5:]
            bucket, key = s3_path.split("/", 1)
        elif "/" in body_str:
            bucket, key = body_str.split("/", 1)
        else:
            raise ValueError(f"Unable to parse message body: {body_str}")

    # Only process objects from our configured input bucket.
    if bucket != INPUT_BUCKET:
        raise ValueError(
            f"Unexpected input bucket: {bucket}"
        )

    logger.info(
        "Processing message %s: s3://%s/%s",
        message_id,
        bucket,
        key
    )

    # Create a temporary directory for audio.
    with tempfile.TemporaryDirectory(dir="/tmp") as temp_dir:

        audio_path = os.path.join(
            temp_dir,
            PurePosixPath(key).name
        )

        # Download audio.
        download_audio(
            bucket,
            key,
            audio_path
        )

        # Run Whisper.
        transcription = transcribe_audio(
            audio_path,
            language
        )

        # Upload generated text.
        output_key = upload_transcription(
            key,
            transcription
        )

    logger.info(
        "Successfully processed message %s. Output: %s",
        message_id,
        output_key
    )


# --------------------------------------------------
# 7. Lambda entry point
# --------------------------------------------------

def lambda_handler(event, context):

    logger.info(
        "Whisper worker started. Request ID: %s",
        context.aws_request_id
    )

    batch_failures = []

    for record in event.get("Records", []):

        message_id = record["messageId"]

        try:
            process_message(record)

        except Exception:
            logger.exception(
                "Failed to process SQS message: %s",
                message_id
            )

            # Tell Lambda to return this message to SQS.
            batch_failures.append({
                "itemIdentifier": message_id
            })

    logger.info(
        "Worker finished. Failed messages: %d",
        len(batch_failures)
    )

    return {
        "batchItemFailures": batch_failures
    }
