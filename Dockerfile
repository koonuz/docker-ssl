FROM alpine:latest
COPY ssl.sh /root/ssl.sh
COPY runit /etc/service
RUN apk update && \
    apk add --no-cache tzdata runit dcron curl socat acme.sh && \
    rm -rf /var/cache/apk/* && \
    chmod +x /root/ssl.sh /etc/service/acme/run
WORKDIR /root
CMD ["runsvdir", "-P", "/etc/service"]
