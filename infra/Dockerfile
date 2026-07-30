# Stage 1: Сборка
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /infra .

# Stage 2: Минимальный образ
FROM scratch
COPY --from=builder /infra /infra
COPY static/ /static/
EXPOSE 8080
ENTRYPOINT ["/infra"]
