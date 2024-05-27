FROM --platform=linux/amd64 public.ecr.aws/docker/library/golang:1.22-alpine3.19 AS builder
ENV CGO_ENABLED 0
ARG BUILD_REF

WORKDIR /app

RUN apk update && apk upgrade && apk add --no-cache ca-certificates && update-ca-certificates

COPY . .

RUN go mod download && \
    go mod tidy

COPY . .

RUN GO111MODULE=on go work vendor

RUN go build -ldflags "-s -w -X main.build=${BUILD_REF}" -o /app/service /app/cmd/reverst/main.go

FROM --platform=linux/amd64 public.ecr.aws/docker/library/alpine:3.19.1
RUN apk add tzdata
RUN addgroup -g 5000 -S edge && \
    adduser -u 5000 -h /app -G edge -S edge

LABEL \
    org.opencontainers.image.authors="AJ <aj@edgescale.dev>" \
    org.opencontainers.image.title="edgescale-reverst-service" \
    org.opencontainers.image.revision="${BUILD_REF}" \
    org.opencontainers.image.created="${BUILD_DATE}" \ 
    org.opencontainers.image.vendor="Edge Scale Technologies"

WORKDIR /app
USER edge
CMD ["/app/service"] 

ARG BUILD_DATE
ARG BUILD_REF

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder --chown=edge:edge /app/service /app/service

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD [ "echo", "hi" ]