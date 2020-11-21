ARG GO_VERSION=1.15.4
FROM golang:${GO_VERSION}-buster

WORKDIR /
COPY . /src
WORKDIR /src
RUN go install ./...

ENV PATH="/home/go/bin:$PATH"
ENTRYPOINT [ "gopro2json" ]
