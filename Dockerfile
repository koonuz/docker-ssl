FROM debian:11-slim
COPY test.sh /root/test.sh
RUN apt-get -y update && \
    apt-get install -y --no-install-recommends ca-certificates wget runit curl socat cron && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY runit /etc/service
RUN chmod +x /etc/service/acme/run
WORKDIR /root
CMD [ "runsvdir", "-P", "/etc/service"]
