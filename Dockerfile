# Build the manager binary
FROM golang:1.15-alpine3.13 AS builder
RUN apk add --update --no-cache git musl-dev linux-headers

# Fetch dependencies (cached)
WORKDIR /workspace
COPY go.mod go.sum ./
RUN go mod download

# Copy the go source
COPY cmd/manager/main.go cmd/manager/main.go
COPY api/ api/
COPY internal/template internal/template
COPY internal/utils internal/utils
COPY internal/controllers internal/controllers

# Build
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GO111MODULE=on go build -a -o manager ./cmd/manager

# Use distroless as minimal base image to package the manager binary
# Refer to https://github.com/GoogleContainerTools/distroless for more details
FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY --from=builder /workspace/manager .
USER 65532:65532

ENTRYPOINT ["/manager"]
