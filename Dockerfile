# Build Stage
FROM golang:1.22 as builder

WORKDIR /app

COPY go.mod ./
# COPY go.sum ./ # Uncomment when dependencies are added
RUN go mod download

COPY *.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o /secure-api

# Runtime Stage
FROM gcr.io/distroless/static:nonroot

WORKDIR /

COPY --from=builder /secure-api /secure-api

USER nonroot:nonroot

ENTRYPOINT ["/secure-api"]
