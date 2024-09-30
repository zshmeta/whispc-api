# Dockerfile

# Use an official Node.js runtime as the base image
FROM node:18-slim

# Set environment variables
ENV NODE_ENV=production
ENV PIPX_HOME=/home/app/.pipx
ENV PIPX_BIN_DIR=/home/app/.local/bin

# Install necessary system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    python3-pip \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -ms /bin/bash app

# Switch to the non-root user
USER app

# Update PATH for pipx
ENV PATH=$PATH:/home/app/.local/bin

# Install pipx
RUN pip3 install --user pipx \
    && pipx ensurepath

# Install whisper-ctranslate2 using pipx
RUN pipx install whisper-ctranslate2

# Create app directory
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
EXPOSE 3000

# Define the default command to run the application
CMD ["node", "server.js"]
