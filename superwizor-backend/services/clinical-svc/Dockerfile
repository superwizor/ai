FROM golang:1.26-alpine AS builder
WORKDIR /app

# Copy workspace files
COPY go.work go.work.sum ./
COPY services/clinical-svc services/clinical-svc
COPY services/identity-svc services/identity-svc
COPY pkg/ pkg/
COPY gen/ gen/

WORKDIR /app/services/clinical-svc
RUN go mod download

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /server /server
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
