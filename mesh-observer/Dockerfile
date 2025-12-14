FROM node:20-alpine

WORKDIR /app

# Install build dependencies for native modules (better-sqlite3)
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package*.json ./

# Install dependencies (including native modules)
RUN npm ci --only=production

# Create data directory for SQLite database
RUN mkdir -p /app/data

# Copy built files
COPY dist/ ./dist/

# Expose port
EXPOSE 3001

# Volume for persistent database
VOLUME ["/app/data"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3001/health || exit 1

# Run the server
CMD ["node", "dist/index.js"]
