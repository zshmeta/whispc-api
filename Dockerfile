# Dockerfile

# Use an official Node.js runtime as the base image
FROM node:18-slim

# Set environment variables
ENV NODE_ENV=production

# Install necessary system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    python3-pip \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Install whisper-ctranslate2
RUN pip3 install --no-cache-dir whisper-ctranslate2

# Create a non-root user
RUN useradd -ms /bin/bash app

# Switch to the non-root user
USER app

# Set working directory
WORKDIR /home/app/app

# Copy package.json and package-lock.json
COPY --chown=app:app package*.json ./

# Install Node.js dependencies
RUN npm install --production

# Copy the rest of the application code
COPY --chown=app:app . .

# Make the bash script executable
RUN chmod +x whisper.sh

# Expose the port the app runs on
EXPOSE 9000

# Define the default command to run the application
CMD ["node", "server.js"]
