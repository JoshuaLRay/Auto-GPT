# Build context is the streamhub/ directory (see deploy/docker-compose.yml),
# so both the server and the web client are available to copy.

# --- web stage: build the static web app ---
FROM node:22-alpine AS web
WORKDIR /web
COPY clients/web/package.json clients/web/package-lock.json ./
RUN npm ci
COPY clients/web/ ./
RUN npm run build   # -> /web/dist

# --- server stage: compile a static binary (pure-Go SQLite => CGO off) ---
FROM golang:1.25 AS build
WORKDIR /src
COPY server/go.mod server/go.sum ./
RUN go mod download
COPY server/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/streamhub ./cmd/streamhub

# --- runtime stage: minimal image with FFmpeg (the only external dependency) ---
FROM alpine:3.20
RUN apk add --no-cache ffmpeg ca-certificates
COPY --from=build /out/streamhub /usr/local/bin/streamhub
COPY --from=web /web/dist /web

ENV STREAMHUB_DATA_DIR=/data \
    STREAMHUB_MEDIA_DIRS=/media \
    STREAMHUB_ADDR=:8080 \
    STREAMHUB_WEB_DIR=/web
VOLUME ["/data", "/media"]
EXPOSE 8080

# Serves both the API and the web app on :8080.
ENTRYPOINT ["streamhub"]
