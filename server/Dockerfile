# Stage 1: Build Frontend (Node.js)
FROM node:20-alpine AS frontend-builder
WORKDIR /app/client
# Copy package files first to cache dependencies
COPY client/package*.json ./
RUN npm install
# Copy the rest of the frontend code and build
COPY client/ .
RUN npm run build

# Stage 2: Build Backend (Go)
FROM golang:1.23-alpine AS backend-builder
RUN apk add --no-cache git ca-certificates
WORKDIR /app/server
# Copy go mod files to cache dependencies
COPY server/go.mod server/go.sum* ./
RUN go mod download
# Copy the rest of the backend code and build
COPY server/ .
RUN CGO_ENABLED=0 GOOS=linux go build -o /server_bin ./cmd/game

# Stage 3: Final Image
FROM alpine:latest
WORKDIR /app

# Copy the compiled Go binary
COPY --from=backend-builder /server_bin /app/server_bin

# Copy the compiled frontend game to /app/dist
COPY --from=frontend-builder /app/client/dist /app/dist

# Expose the WebSocket port
EXPOSE 8081

# Run the server
CMD ["/app/server_bin", "--env=production"]
