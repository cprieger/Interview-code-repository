# Stage 1: Build
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o weather-api cmd/server/main.go

# Stage 2: Final
FROM alpine:latest
WORKDIR /root/
COPY --from=builder /app/weather-api .
EXPOSE 8080
CMD ["./weather-api"]