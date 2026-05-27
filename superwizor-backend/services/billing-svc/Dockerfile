FROM golang:1.26-alpine AS builder
WORKDIR /app

# Build in single-module mode — billing-svc's go.mod only needs gen/go and
# pkg/cors (via replace directives), nothing else from pkg/* or other services.
# Skipping go.work keeps the image lean and the build cache stable across
# unrelated services.
ENV GOWORK=off

COPY services/billing-svc services/billing-svc
COPY gen/ gen/
COPY pkg/cors pkg/cors

WORKDIR /app/services/billing-svc
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /server /server
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
