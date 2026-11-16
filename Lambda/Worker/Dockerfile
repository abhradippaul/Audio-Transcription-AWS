FROM public.ecr.aws/lambda/python:3.13

# Install FFmpeg using static binaries
COPY --from=mwader/static-ffmpeg:latest /ffmpeg /ffprobe /usr/local/bin/

# Install Python dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}

RUN pip install --no-cache-dir \
    -r requirements.txt

# Pre-download Whisper model into the image
ENV WHISPER_MODEL_DIR=/opt/whisper
RUN mkdir -p /opt/whisper && python -c "import whisper; whisper.load_model('base', download_root='/opt/whisper')"

# Copy application
COPY main.py ${LAMBDA_TASK_ROOT}

# Lambda handler
CMD ["main.lambda_handler"]
