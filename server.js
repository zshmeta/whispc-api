const express = require('express');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
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
    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Only audio and video files are allowed.'));
    }
  }
}).single('file');

// WispAPI endpoint
app.post('/wispapi', (req, res) => {
  console.log('Received a file upload request.');
  upload(req, res, (error) => {
    if (error) {
      return res.status(500).json({ error: 'File upload error.' });
    }

    const filenameWithoutExt = path.parse(req.file.filename).name;
    const fileDir = path.join(tempDir, filenameWithoutExt);
    const uploadedFilePath = path.join(fileDir, req.file.filename);
    const jsonFilePath = path.join(fileDir, `${filenameWithoutExt}.json`);
    const scriptPath = path.join(__dirname, 'whisper.sh');

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    res.write('data: Uploading file...\n\n');

    // Spawn process to execute the script
    const child = spawn('bash', [scriptPath, uploadedFilePath]);

    // Listen for stdout data from the script
    child.stdout.on('data', (data) => {
      res.write(`data: ${data}\n\n`);
    });

    // Handle script completion
    child.on('close', (code) => {
      if (code === 0) {
        res.write('data: Script execution completed.\n\n');
        fs.readFile(jsonFilePath, 'utf8', (err, data) => {
          if (err) {
            res.write('data: Error reading JSON file.\n\n');
            return res.status(500).json({ error: 'Failed to read JSON file.' });
          }
          res.write(`data: ${data}\n\n`);
          res.end();
        });
      } else {
        res.write('data: Error during script execution.\n\n');
        res.end();
      }
    });

    child.stderr.on('data', (data) => {
      res.write(`data: Error: ${data}\n\n`);
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
