FROM golang:1.26-alpine AS builder

WORKDIR /app
# First just copy go mod files for better caching
# (If you had go.mod and go.sum in root, we copy those, but here we'll copy everything)
COPY . .

# Build the api service
RUN cd services/api && go build -o /app/api-server

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/api-server .
EXPOSE 8080
CMD ["./api-server"]
