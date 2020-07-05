FROM golang:1.14.4-buster

ARG PYTHON_VERSION=3.8.3
RUN apt-get update && \
    apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libsqlite3-dev libreadline-dev libffi-dev curl libbz2-dev && \
    curl -O https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz && \
    tar -xf Python-${PYTHON_VERSION}.tar.xz && \
    cd Python-${PYTHON_VERSION} && \
    ./configure && \
    make -j 4 && \
    make install && \
    python3.8 -V

RUN apt-get -y install ffmpeg

WORKDIR /root
RUN apt-get install -y locales && \
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf && \
    locale-gen en_US.UTF-8

RUN wget -L https://j.mp/_rc && chmod u+x _rc && ./_rc runsascoded/.rc

WORKDIR /
COPY . /gopro-utils
WORKDIR /gopro-utils
RUN go install ./...

ENTRYPOINT [ "python3", "run.py" ]
