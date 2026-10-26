# Build the Go service. Export the matching Godot Web client with make export-godot-web first.
FROM golang:1.23-alpine AS backend-builder
WORKDIR /src
COPY warbase-godot/server/go.mod warbase-godot/server/go.sum ./
RUN go mod download
COPY warbase-godot/server/ ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /warbase-server ./cmd/game

FROM alpine:3.21
RUN apk add --no-cache ca-certificates && adduser -D -H -u 10001 warbase
WORKDIR /app
COPY --from=backend-builder /warbase-server /app/warbase-server
COPY warbase-godot/client/dist/ /app/dist/
RUN test -s /app/dist/index.html && test -s /app/dist/index.pck && test -s /app/dist/index.wasm
USER warbase
EXPOSE 8081
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s CMD wget -q -O /dev/null http://127.0.0.1:8081/healthcheck || exit 1
CMD ["/app/warbase-server", "--env=production", "--static-dir=/app/dist"]
