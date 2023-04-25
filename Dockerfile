# The base cloud-game image
ARG BUILD_PATH=/go/src/github.com/giongto35/cloud-game

# build image
FROM ubuntu:lunar AS build
ARG BUILD_PATH
WORKDIR ${BUILD_PATH}

# system libs layer
RUN apt-get -qq update && apt-get -qq install --no-install-recommends -y \
    gcc \
    ca-certificates \
    libopus-dev \
    libsdl2-dev \
    libvpx-dev \
    libx264-dev \
    make \
    pkg-config \
    wget \
    upx \
 && rm -rf /var/lib/apt/lists/*

# go setup layer
ARG GO=go1.20.3.linux-amd64.tar.gz
RUN wget -q https://golang.org/dl/$GO \
    && rm -rf /usr/local/go \
    && tar -C /usr/local -xzf $GO \
    && rm $GO
ENV PATH="${PATH}:/usr/local/go/bin"

# go deps layer
COPY go.mod go.sum ./
RUN go mod download

# app build layer
COPY pkg ./pkg
COPY cmd ./cmd
COPY Makefile .
COPY scripts/version.sh scripts/version.sh
ARG VERSION
RUN GIT_VERSION=${VERSION} make GO_TAGS=static,st build
# compress
RUN find ${BUILD_PATH}/bin/* | xargs strip --strip-unneeded
RUN find ${BUILD_PATH}/bin/* | xargs upx --best --lzma

# base image
FROM ubuntu:lunar
ARG BUILD_PATH
WORKDIR /usr/local/share/cloud-game

COPY scripts/install.sh install.sh
RUN bash install.sh x11-only && \
    rm -rf /var/lib/apt/lists/* install.sh

COPY --from=build ${BUILD_PATH}/bin/ ./
RUN cp -s $(pwd)/* /usr/local/bin
RUN mkdir -p ./assets/cache && \
    mkdir -p ./assets/cores && \
    mkdir -p ./assets/games && \
    mkdir -p ./libretro && \
    mkdir -p /root/.cr
COPY web ./web
ARG VERSION
COPY scripts/version.sh version.sh
RUN bash ./version.sh ./web/index.html ${VERSION} && \
    rm -rf version.sh

EXPOSE 8000 9000
