// server.js
const express = require('express');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');

const app = express();
const PORT = process.env.PORT || 9000;

// Configure Multer for file uploads
const upload = multer({
  dest: 'uploads/', // Temporary storage directory
  limits: { fileSize: 500 * 1024 * 1024 }, // Set file size limit as needed
  fileFilter: (req, file, cb) => {
    const filetypes = /mp3|mp4|webm|wav|m4a|aac|ogg/;
    const extname = filetypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = filetypes.test(file.mimetype) || file.mimetype === 'application/octet-stream';
    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Only audio and video files are allowed.'));
    }
  },
});

// POST /whispapi endpoint
app.post('/whispapi', upload.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No file uploaded.' });
  }

  const uploadedFilePath = path.resolve(req.file.path);
  const scriptPath = path.resolve(__dirname, 'transcribe.sh'); // Update the script name if needed

  // Execute the transcription script
  execFile(scriptPath, [uploadedFilePath], (error, stdout, stderr) => {
    if (error) {
      console.error('Script Error:', stderr.trim());
      // Attempt to parse stderr as JSON
      try {
        const errorObj = JSON.parse(stderr.trim());
        return res.status(500).json(errorObj);
      } catch (parseError) {
        return res.status(500).json({ error: 'Internal Server Error.' });
      }
    }

    // Attempt to parse stdout as JSON
    try {
      const transcriptionData = JSON.parse(stdout.trim());
      return res.json(transcriptionData);
    } catch (parseError) {
      console.error('JSON Parse Error:', parseError.message);
      console.error('Received Output:', stdout.trim());
      return res.status(500).json({ error: 'Failed to parse transcription data.' });
    }
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
