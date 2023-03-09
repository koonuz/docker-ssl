FROM alpine:latest
COPY ssl.sh /root/ssl.sh
RUN apk update && \
    apk add --no-cache tzdata curl socat bash acme.sh runit && \
    rm -rf /var/cache/apk/*

COPY runit /etc/service
WORKDIR /root
CMD [ "runsvdir", "-P", "/etc/service"]
