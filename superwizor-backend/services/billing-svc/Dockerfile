FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copy the entire backend directory to resolve go.work dependencies
COPY . .

# Build the binary
RUN go build -o billing-svc ./services/billing-svc/main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /root/
COPY --from=builder /app/billing-svc .

EXPOSE 8080
CMD ["./billing-svc"]
