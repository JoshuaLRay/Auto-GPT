# --- build stage: compile a static binary (pure-Go SQLite => CGO off) ---
FROM golang:1.25 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/streamhub ./cmd/streamhub

# --- runtime stage: minimal image with FFmpeg (the only external dependency) ---
FROM alpine:3.20
RUN apk add --no-cache ffmpeg ca-certificates
COPY --from=build /out/streamhub /usr/local/bin/streamhub

ENV STREAMHUB_DATA_DIR=/data \
    STREAMHUB_MEDIA_DIRS=/media \
    STREAMHUB_ADDR=:8080
VOLUME ["/data", "/media"]
EXPOSE 8080

ENTRYPOINT ["streamhub"]
