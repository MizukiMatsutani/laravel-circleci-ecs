FROM nginx:1.18-alpine
SHELL ["/bin/ash", "-oeux", "pipefail", "-c"]

RUN apk update && \
    apk add --update --no-cache --virtual=.build-dependencies g++

COPY ./src/public /work/public
COPY ./infrastructure/nginx/nginx.conf /etc/nginx/nginx.conf
COPY ./infrastructure/nginx/default.conf /etc/nginx/conf.d/default.conf

WORKDIR /work