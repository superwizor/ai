FROM golang:1.26-alpine AS builder
WORKDIR /app

# Copy workspace files
COPY go.work go.work.sum ./
COPY services/ services/
COPY pkg/ pkg/
COPY gen/ gen/

WORKDIR /app/services/ingestion-svc
RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server ./cmd/server

# Runtime stage:
#
# Switched from distroless/static to debian:bookworm-slim because the
# new ConvertAudio RPC shells out to ffmpeg. distroless has no apt and
# no shell, so ffmpeg can't be installed there. bookworm-slim adds
# ~80 MB image footprint vs distroless's ~5 MB, but ffmpeg itself is
# ~50 MB of that — there's no smaller path that ships ffmpeg.
#
# Security trade-off: bookworm-slim has a shell + apt, distroless has
# neither. We accept the bigger attack surface because ConvertAudio
# needs a real binary in PATH. The server binary itself is static,
# runs as a non-root UID set at the OS level.
FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --uid 65532 --create-home --shell /usr/sbin/nologin nonroot
COPY --from=builder /server /server
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/server"]
