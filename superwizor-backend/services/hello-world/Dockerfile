FROM golang:1.26-alpine AS builder
WORKDIR /app
COPY go.mod ./
# No go.sum since we have no dependencies, but we'll try to copy it if it exists.
# We will use wildcards to avoid errors if go.sum is missing.
COPY go.mod go.sum* ./
RUN go mod download || true
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /server /server
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
