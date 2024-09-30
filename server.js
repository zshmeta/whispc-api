const express = require('express');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const app = express();
const PORT = process.env.PORT || 3000;

// Ensure temp directory exists
const tempDir = path.join(__dirname, 'temp');
if (!fs.existsSync(tempDir)) {
  fs.mkdirSync(tempDir, { recursive: true });
}

// Configure Multer
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const filenameWithoutExt = path.parse(file.originalname).name;
    const fileDir = path.join(tempDir, filenameWithoutExt);
    if (!fs.existsSync(fileDir)) {
      fs.mkdirSync(fileDir, { recursive: true });
    }
    cb(null, fileDir);
  },
  filename: (req, file, cb) => {
    const filenameWithoutExt = path.parse(file.originalname).name;
    cb(null, `${filenameWithoutExt}${path.extname(file.originalname)}`);
  }
});

const upload = multer({
  storage: storage,
  fileFilter: (req, file, cb) => {
    const filetypes = /mp3|mp4|webm|wav/;
    const extname = filetypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = filetypes.test(file.mimetype) || file.mimetype === 'application/octet-stream';
    console.log(`File extension: ${path.extname(file.originalname).toLowerCase()}`);
    console.log(`MIME type: ${file.mimetype}`);
    if (mimetype && extname) {
      return cb(null, true);
    } else {
      console.error(`Rejected file: ${file.originalname}`);
      cb(new Error('Only audio and video files are allowed.'));
    }
  }
}).single('file');

// WispAPI endpoint
app.post('/wispapi', (req, res) => {
  console.log('Received a file upload request.');
  upload(req, res, (error) => {
    if (error) {
      console.error('Upload Error:', error); // Log the error
      if (error instanceof multer.MulterError) {
        let errorMessage = 'An error occurred during file upload.';
        if (error.code === 'LIMIT_FILE_SIZE') {
          errorMessage = 'File size exceeds the allowed limit.';
        } else if (error.code === 'LIMIT_UNEXPECTED_FILE') {
          errorMessage = 'Only video and audio files are allowed.';
        }
        return res.status(400).json({ error: errorMessage });
      }
      return res.status(500).json({ error: 'An error occurred during file upload.' });
    }

    console.log('File uploaded successfully:', req.file);

    const filenameWithoutExt = path.parse(req.file.filename).name;
    const fileDir = path.join(tempDir, filenameWithoutExt);
    const uploadedFilePath = path.join(fileDir, req.file.filename);
    const jsonFilePath = path.join(fileDir, `${filenameWithoutExt}.json`);

    const scriptPath = path.join(__dirname, 'whisper.sh');
    console.log(`Executing script: bash "${scriptPath}" "${uploadedFilePath}"`);

    exec(`bash "${scriptPath}" "${uploadedFilePath}"`, { cwd: __dirname, maxBuffer: 1024 * 1024 }, (err, stdout, stderr) => {
      if (err) {
        console.error('Script Execution Error:', err);
        console.error('Script stderr:', stderr);
        return res.status(500).json({ error: 'An error occurred while processing the video.' });
      }

      console.log('Script stdout:', stdout);
      if (stderr) {
        console.error('Script stderr:', stderr);
      }

      // Read the JSON file and respond
      fs.readFile(jsonFilePath, 'utf8', (err, data) => {
        if (err) {
          console.error('File Read Error:', err); // Log the error
          return res.status(500).json({ error: 'An error occurred while reading the JSON file.' });
        }
        try {
          const jsonData = JSON.parse(data);
          res.json(jsonData);
        } catch (parseError) {
          console.error('JSON Parse Error:', parseError);
          res.status(500).json({ error: 'Failed to parse JSON output.' });
        }
      });
    });
  });
});

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ message: 'Video Transcription Server is running.' });
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
