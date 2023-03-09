FROM alpine:latest
COPY ssl.sh /root/ssl.sh
RUN apk update && \
    apk add --no-cache tzdata runit acme.sh dcron && \
    rm -rf /var/cache/apk/*
COPY runit /etc/service
RUN chmod +x /etc/service/acme/run /root/test.sh
WORKDIR /root
CMD [ "runsvdir", "-P", "/etc/service"]
