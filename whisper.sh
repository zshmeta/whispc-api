#!/bin/bash

# Exit immediately if a command exits with a non-zero status,
# if undefined variables are used, and if any command in a pipeline fails
set -euo pipefail

# Function to print error messages to stderr
error() {
    echo "Error: $1" >&2
}

# Function to print usage information
usage() {
    echo "Usage: $0 <file>"
    exit 1
}

# Check if exactly one argument is provided
if [ "$#" -ne 1 ]; then
    error "Incorrect number of arguments."
    usage
fi

INPUT_FILE="$1"

# Check if the input file exists and is a regular file
if [ ! -f "$INPUT_FILE" ]; then
    error "File '$INPUT_FILE' does not exist or is not a regular file."
    exit 1
fi

# Ensure required dependencies are installed
for cmd in ffmpeg whisper-ctranslate2; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "Required command '$cmd' is not installed or not in PATH."
        exit 1
    fi
done

# Extract the base filename without directory and extension
BASENAME=$(basename "$INPUT_FILE")
FILENAME="${BASENAME%.*}"

# Create the temporary directory
DIR=$(dirname "$INPUT_FILE")

# Define paths for intermediate and output files
TEMP_WAV_FILE="$DIR/${FILENAME}_temp.wav"
WAV_FILE="$DIR/${FILENAME}.wav"
JSON_OUTPUT="$DIR/${FILENAME}.json"

echo "Processing file: '$INPUT_FILE'"

# Convert the input file to WAV format
echo "Converting to WAV format..."

# Run ffmpeg to convert the input to WAV
# -y: overwrite output files without asking
# -ar 16000: set audio sampling rate to 16000 Hz
# -ac 1: set number of audio channels to 1
# -c:a pcm_s16le: set audio codec to PCM signed 16-bit little-endian
if ! ffmpeg -y -i "$INPUT_FILE" -ar 16000 -ac 1 -c:a pcm_s16le "$TEMP_WAV_FILE"; then
    error "ffmpeg failed to convert '$INPUT_FILE' to WAV."
    exit 1
fi

# Move the temporary WAV file to the final WAV file location
mv -f "$TEMP_WAV_FILE" "$WAV_FILE"

echo "Conversion to WAV successful: '$WAV_FILE'"

echo "Running whisper-ctranslate2 on WAV file..."

# Run whisper-ctranslate2 with specified options
# --output-format json: set output format to JSON
# --timestamp_word true: include word-level timestamps
# --output_dir: specify the output directory for JSON results
# if JSON_OUTPUT exists we remove it
if [ -f "$JSON_OUTPUT" ]; then
    rm -f "$JSON_OUTPUT"
fi

# shellcheck disable=SC1091
source .env

# Run whisper-ctranslate2 with options loaded from .env
if ! whisper-ctranslate2 --model "$WHISPER_MODEL" \
    --output_format "$WHISPER_OUTPUT_FORMAT" \
    --word_timestamp "$WHISPER_WORD_TIMESTAMP" \
    --output_dir "$DIR" \
    --device "$WHISPER_DEVICE" "$WAV_FILE"; then
    error "whisper-ctranslate2 failed on '$WAV_FILE'."
    exit 1
fi

echo "whisper-ctranslate2 processing complete. Output saved to '$JSON_OUTPUT'"

exit 0