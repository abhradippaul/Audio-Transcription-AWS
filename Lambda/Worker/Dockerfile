FROM public.ecr.aws/lambda/python:3.13

# Install FFmpeg
RUN dnf install -y ffmpeg \
    && dnf clean all

# Install Python dependencies
COPY requirements.txt ${LAMBDA_TASK_ROOT}

RUN pip install --no-cache-dir \
    -r requirements.txt

# Copy application
COPY worker.py ${LAMBDA_TASK_ROOT}

# Download Whisper model during image build
RUN python -c "import whisper; whisper.load_model('base')"

# Lambda handler
CMD ["worker.lambda_handler"]