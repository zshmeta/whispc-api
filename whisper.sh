#!/bin/bash

set -euo pipefail

# Function to log errors
error() {
    echo "Error: $1" >&2
}

# Function to show usage
usage() {
    echo "Usage: $0 <file>"
    exit 1
}

# Check number of arguments
if [ "$#" -ne 1 ]; then
    error "Incorrect number of arguments."
    usage
fi

INPUT_FILE="$1"

# Check if input file exists and is a regular file
if [ ! -f "$INPUT_FILE" ]; then
    error "File '$INPUT_FILE' does not exist or is not a regular file."
    exit 1
fi

# Check required commands
for cmd in ffmpeg whisper-ctranslate2; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "Required command '$cmd' is not installed or not in PATH."
        exit 1
    fi
done

# Get file information
BASENAME=$(basename "$INPUT_FILE")
FILENAME="${BASENAME%.*}"
DIR=$(dirname "$INPUT_FILE")
TEMP_DIR="$DIR/temp_$FILENAME"

# Create temp directory
mkdir -p "$TEMP_DIR"

# Define output paths
WAV_FILE="$TEMP_DIR/${FILENAME}.wav"
JSON_OUTPUT="$DIR/${FILENAME}.json"

# Remove existing JSON output if any
if [ -f "$JSON_OUTPUT" ]; then
    rm -f "$JSON_OUTPUT"
fi

# Source .env if exists
if [ -f "$DIR/.env" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$DIR/.env"
    set +a
fi

# Determine number of CPU cores
THREADS=$(nproc)

# Define desired audio parameters (can be set via .env or defaults)
DESIRED_SAMPLE_RATE="${DESIRED_SAMPLE_RATE:-16000}"
DESIRED_CHANNELS="${DESIRED_CHANNELS:-1}"
DESIRED_AUDIO_CODEC="${DESIRED_AUDIO_CODEC:-pcm_s16le}"

# Log the conversion details
echo "Converting '$INPUT_FILE' to WAV format with sample rate $DESIRED_SAMPLE_RATE Hz and $DESIRED_CHANNELS channel(s)."

# Convert input file to WAV using ffmpeg
# -y: overwrite output files without asking
# -vn: disable video
# -acodec: specify audio codec
# -ar: set audio sample rate
# -ac: set number of audio channels

# Using bash's set -x for debugging could be enabled here if needed

if ! ffmpeg -y -i "$INPUT_FILE" \
    -vn \
    -acodec "$DESIRED_AUDIO_CODEC" \
    -ar "$DESIRED_SAMPLE_RATE" \
    -ac "$DESIRED_CHANNELS" \
    "$WAV_FILE" \
    2> "$TEMP_DIR/ffmpeg_error.log"; then
    error "ffmpeg failed to convert '$INPUT_FILE' to WAV. Check '$TEMP_DIR/ffmpeg_error.log' for details."
    exit 1
fi

# Verify that WAV file was created
if [ ! -f "$WAV_FILE" ]; then
    error "WAV file '$WAV_FILE' was not created."
    exit 1
fi

echo "Successfully converted to WAV: '$WAV_FILE'"

# Run whisper-ctranslate2
# Capture stderr for logging
echo "Starting transcription with whisper-ctranslate2..."

if ! whisper-ctranslate2 --model "$WHISPER_MODEL" \
    --output_format "$WHISPER_OUTPUT_FORMAT" \
    --word_timestamps "$WHISPER_WORD_TIMESTAMP" \
    --output_dir "$DIR" \
    --device "$WHISPER_DEVICE" \
    --compute_type "int8" \
    --threads "$THREADS" \
    --vad_filter True \
    --vad_threshold 0.5 \
    --vad_min_speech_duration_ms 500 \
    --vad_max_speech_duration_s 30 \
    --verbose True \
    "$WAV_FILE" \
    2> "$TEMP_DIR/whisper_error.log"; then
    error "whisper-ctranslate2 failed on '$WAV_FILE'. Check '$TEMP_DIR/whisper_error.log' for details."
    exit 1
fi

# Verify that JSON output was created
if [ ! -f "$JSON_OUTPUT" ]; then
    error "JSON output '$JSON_OUTPUT' was not created."
    exit 1
fi

echo "Transcription completed successfully. Output: '$JSON_OUTPUT'"
