#!/bin/bash

set -euo pipefail

error() {
    echo "Error: $1" >&2
}

usage() {
    echo "Usage: $0 <file>"
    exit 1
}

if [ "$#" -ne 1 ]; then
    error "Incorrect number of arguments."
    usage
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    error "File '$INPUT_FILE' does not exist or is not a regular file."
    exit 1
fi

for cmd in ffmpeg whisper-ctranslate2; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "Required command '$cmd' is not installed or not in PATH."
        exit 1
    fi
done

BASENAME=$(basename "$INPUT_FILE")
FILENAME="${BASENAME%.*}"
DIR=$(dirname "$INPUT_FILE")
TEMP_WAV_FILE="$DIR/${FILENAME}_temp.wav"
WAV_FILE="$DIR/${FILENAME}.wav"
JSON_OUTPUT="$DIR/${FILENAME}.json"

echo "Preparing transcription..."

# Add stdbuf here to force immediate output
if ! ffmpeg -y -i "$INPUT_FILE" -ar 16000 -ac 1 -c:a pcm_s16le "$TEMP_WAV_FILE" &>/dev/null; then
    error "ffmpeg failed to convert '$INPUT_FILE' to WAV."
    exit 1
fi

mv -f "$TEMP_WAV_FILE" "$WAV_FILE"

if [ -f "$JSON_OUTPUT" ]; then
    rm -f "$JSON_OUTPUT"
fi

# shellcheck disable=SC1091
source .env

echo "Transcribing your media..."
# Add stdbuf to the whisper-ctranslate2 call
if ! stdbuf -oL whisper-ctranslate2 --model "$WHISPER_MODEL" \
    --output_format "$WHISPER_OUTPUT_FORMAT" \
    --word_timestamp "$WHISPER_WORD_TIMESTAMP" \
    --output_dir "$DIR" \
    --device "$WHISPER_DEVICE" "$WAV_FILE" &>/dev/null; then
    error "whisper-ctranslate2 failed on '$WAV_FILE'."
    exit 1
fi
