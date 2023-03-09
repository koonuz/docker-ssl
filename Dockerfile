FROM alpine:latest
COPY ssl.sh /root/ssl.sh
RUN apk update && \
    apk add --no-cache tzdata curl socat bash acme.sh && \
    rm -rf /var/cache/apk/*
WORKDIR /root
CMD ["/bin/bash","-C","acme.sh"]
