# Whispc-API Application

This project is a transcription service using `whisper-ctranslate2` and `ffmpeg` to convert audio/video files to text in JSON format. The service accepts file uploads via a REST API, processes them with `whisper-ctranslate2`, and returns the transcription in real-time.

## Features

- Upload audio/video files for transcription.
- Supported file formats: MP3, MP4, WAV, and WebM.
- Real-time progress feedback via server-sent events (SSE).
- Returns transcription as a JSON response.

## Prerequisites

- Docker installed on your machine.
- Optional: Node.js and npm (if running locally).

## Setup and Usage

### 1. Clone the Repository

Clone the repository to your local machine:

```bash
git clone <repository-url>
cd whisper-api-app
```

### 2. Build the Docker Image

To build the Docker image, run the following command in the root of the project:

```bash
docker build -t whisper-api .
```

### 3. Run the Docker Container

Once the image is built, you can run the Docker container:

```bash
docker run -d -p 3000:3000 --name whisper-api-container whisper-api
```

This will start the application on port `3000`.

### 4. Sending Requests to the API

You can now send a POST request to the `/wispapi` endpoint with an audio or video file. This will return real-time progress updates and the transcription once completed.

#### Example using `curl`

```bash
curl -X POST http://localhost:3000/wispapi \
  -F "file=@path/to/your/audio_or_video_file.mp4" \
  --output output.json
```

#### Example Response

You will receive progress updates as the file is uploaded and processed. The final response will include the transcription in JSON format:

```json
{
  "segments": [
    {
      "start": 0.0,
      "end": 3.5,
      "text": "Hello, this is a test transcription."
    },
    {
      "start": 3.5,
      "end": 7.0,
      "text": "This transcription uses Whisper for audio recognition."
    }
  ]
}
```

### 5. Stopping the Docker Container

To stop the running container:

```bash
docker stop whisper-api-container
```

### 6. Removing the Docker Container

If you want to remove the container:

```bash
docker rm whisper-api-container
```

### Running Locally (Without Docker)

To run the application locally without Docker:

1. Ensure you have `Node.js` installed.
2. Install the dependencies:

    ```bash
    npm install
    ```

3. Set up `whisper-ctranslate2` and other dependencies as mentioned in the Dockerfile.
4. Run the application:

    ```bash
    node server.js
    ```

The API will be available at `http://localhost:3000`.

## Environment Variables

The application uses environment variables to configure `whisper-ctranslate2`. You can specify these in a `.env` file in the root of your project:

```bash
WHISPER_MODEL=medium
WHISPER_OUTPUT_FORMAT=json
WHISPER_WORD_TIMESTAMP=true
WHISPER_DEVICE=cpu
```

## Health Check

You can check if the server is running by visiting the following endpoint:

```bash
GET http://localhost:3000/
```

It will return a simple JSON message confirming the server status.

## Project Structure

```bash
.
├── Dockerfile           # Dockerfile to build the application image
├── README.md            # Project documentation
├── server.js            # Main Express server handling file uploads and processing
├── whisper.sh           # Bash script that runs ffmpeg and whisper-ctranslate2
├── .env                 # Environment configuration for whisper-ctranslate2
└── temp/                # Directory where uploaded files are stored temporarily
```

## Troubleshooting

1. **Port Conflict:**
   - If port `3000` is in use, you can run the container on another port by changing `-p 3000:3000` to `-p <new-port>:3000`.

2. **File Upload Errors:**
   - Ensure you are uploading supported file types (`MP3`, `MP4`, `WAV`, `WebM`).

3. **Real-time Feedback Not Working:**
   - The application uses Server-Sent Events (SSE) for real-time feedback. Ensure your client supports SSE.

## License

This project is licensed under the MIT License.

### How to Use the API

1. **Upload an audio/video file to the `/wispapi` endpoint.**
2. **Get real-time progress via SSE during the processing of the file.**
3. **Receive a JSON file containing the transcription once completed.**
