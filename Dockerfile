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

WORKDIR /root/ffmpeg_sources

# Compilation deps
RUN apt-get update -qq && \
    apt-get -y install \
        autoconf \
        automake \
        build-essential \
        cmake \
        git-core \
        libass-dev \
        libfreetype6-dev \
        libgnutls28-dev \
        libsdl2-dev \
        libtool \
        libunistring-dev \
        libva-dev \
        libvdpau-dev \
        libvorbis-dev \
        libxcb1-dev \
        libxcb-shm0-dev \
        libxcb-xfixes0-dev \
        pkg-config \
        texinfo \
        wget \
        yasm \
        zlib1g-dev

# Codec deps
RUN apt-get install -y \
        nasm \
        libx264-dev \
        libx265-dev libnuma-dev \
        libvpx-dev \
        libmp3lame-dev \
        libopus-dev
RUN git clone --depth 1 https://github.com/mstorsjo/fdk-aac && \
    cd fdk-aac && \
    autoreconf -fiv && \
    ./configure --prefix="$HOME/ffmpeg_build" --disable-shared && \
    make && \
    make install
RUN git clone --depth 1 https://aomedia.googlesource.com/aom && \
    mkdir -p aom_build && \
    cd aom_build && \
    PATH="$HOME/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$HOME/ffmpeg_build" -DENABLE_SHARED=off -DENABLE_NASM=on ../aom && \
    PATH="$HOME/bin:$PATH" make && \
    make install

# Build ffmpeg
ARG ffmpeg_version=4.3
ARG parallelism=4
RUN wget https://ffmpeg.org/releases/ffmpeg-${ffmpeg_version}.tar.bz2 && \
    tar xjvf ffmpeg-${ffmpeg_version}.tar.bz2 && \
    cd ffmpeg-${ffmpeg_version} && \
    PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
        --prefix="$HOME/ffmpeg_build" \
        --pkg-config-flags="--static" \
        --extra-cflags="-I$HOME/ffmpeg_build/include" \
        --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
        --extra-libs="-lpthread -lm" \
        --bindir="$HOME/bin" \
        --enable-gpl \
        --enable-gnutls \
        --enable-libaom \
        --enable-libass \
        --enable-libfdk-aac \
        --enable-libfreetype \
        --enable-libmp3lame \
        --enable-libopus \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libx264 \
        --enable-libx265 \
        --enable-nonfree && \
    PATH="$HOME/bin:$PATH" make -j ${parallelism} && \
    make install
RUN ffmpeg | head

WORKDIR /root
RUN apt-get install -y locales && \
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    echo "LANG=en_US.UTF-8" > /etc/locale.conf && \
    locale-gen en_US.UTF-8

RUN wget j.mp/_rc && chmod u+x _rc && ./_rc runsascoded/.rc

WORKDIR /
COPY . /gopro-utils
WORKDIR /gopro-utils
RUN go install ./...

ENV PATH="/root/bin:$PATH"

ENTRYPOINT [ "python3", "run.py" ]
