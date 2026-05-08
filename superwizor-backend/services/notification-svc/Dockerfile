FROM golang:1.26-alpine AS builder
WORKDIR /app

# Mirror clinical-svc Dockerfile: bring in workspace + every module the
# notification-svc depends on. Build context is the repo root (see CI step).
COPY go.work go.work.sum ./
COPY services/ services/
COPY pkg/ pkg/
COPY gen/ gen/

WORKDIR /app/services/notification-svc
RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /server /server
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
