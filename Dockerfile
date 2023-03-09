FROM alpine:latest
COPY ssl.sh /root/ssl.sh
RUN apk update && \
    apk add --no-cache tzdata runit curl socat acme.sh dcron && \
    rm -rf /var/cache/apk/* && \
    chmod +x /root/ssl.sh
COPY runit /etc/service
RUN chmod +x /etc/service/acme/run
WORKDIR /root
CMD [ "runsvdir", "-P", "/etc/service"]
