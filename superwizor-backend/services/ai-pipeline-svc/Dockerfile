FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copy the entire backend directory to resolve go.work dependencies
COPY . .

# Build the binary
RUN go build -o ai-pipeline-svc ./services/ai-pipeline-svc/cmd/server/main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /root/
COPY --from=builder /app/ai-pipeline-svc .

EXPOSE 8080
CMD ["./ai-pipeline-svc"]
