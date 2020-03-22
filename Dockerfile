FROM golang:1.14.1-alpine3.11 as builder

ARG CLOUDREVE_VERSION="3.0.0-rc1"

WORKDIR /ProjectCloudreve

RUN echo ">>>>>> install dependencies" \
    && apk update \
    && apk add git yarn build-base gcc abuild binutils binutils-doc gcc-doc

RUN echo ">>>>>> clone Cloudreve from GitHub" \
    && git clone --recurse-submodules https://github.com/cloudreve/Cloudreve.git

RUN echo ">>>>>> build frontend" \
    && cd ./Cloudreve/assets \
    && yarn install \
    && yarn run build

RUN echo ">>>>>> build backend" \
    && cd ./Cloudreve \
    && go get github.com/rakyll/statik \
    && statik -src=assets/build/ -include=*.html,*.js,*.json,*.css,*.png,*.svg,*.ico -f \
    && git checkout ${CLOUDREVE_VERSION} \
    && export COMMIT_SHA=$(git rev-parse --short HEAD) \
    && go build -a -o cloudreve -ldflags " -X 'github.com/HFO4/cloudreve/pkg/conf.BackendVersion=$CLOUDREVE_VERSION' -X 'github.com/HFO4/cloudreve/pkg/conf.LastCommit=$COMMIT_SHA'"

FROM lsiobase/alpine:3.11

ENV PUID=1000
ENV PGID=1000
ENV TZ="Asia/Shanghai"

LABEL MAINTAINER="Xavier Niu"

WORKDIR /cloudreve

COPY --from=builder /ProjectCloudreve/Cloudreve/cloudreve ./

RUN echo ">>>>>> update dependencies <<<<<<" \
    && apk update && apk add tzdata \
    && echo ">>>>>> set up timezone <<<<<<" \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && echo ">>>>>> clean up <<<<<<" \
    && apk del tzdata \
    && mv ./cloudreve ./main \
    && chmod +x ./main

VOLUME ["/cloudreve/uploads", "/downloads","/cloudreve/conf.ini", "/cloudreve/cloudreve.db"]

EXPOSE 5212

ENTRYPOINT ["./main"]
