# Stage 1: Build Frontend (Node.js)
FROM node:20-alpine AS frontend-builder
WORKDIR /app/client
COPY client/package*.json ./
RUN npm install
COPY client/ .
RUN npm run build

# Stage 2: Build Backend (Swift 6.0)
FROM swift:6.0-jammy AS swift-builder
WORKDIR /app/server-swift
COPY server-swift/Package.swift server-swift/Package.resolved* ./
COPY server-swift/Sources ./Sources
RUN swift build -c release --product App

# Stage 3: Final Production Image
FROM swift:6.0-jammy-slim
WORKDIR /app

# Copy compiled Swift release binary
COPY --from=swift-builder /app/server-swift/.build/release/App /app/server

# Copy compiled frontend distribution
COPY --from=frontend-builder /app/client/dist /app/dist

EXPOSE 8081
ENV ENV=production
ENV PORT=8081

CMD ["/app/server"]

