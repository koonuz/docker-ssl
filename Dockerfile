FROM debian:11-slim
COPY ssl.sh /root/ssl.sh
RUN apt-get -y update && \
    apt-get install -y --no-install-recommends ca-certificates wget curl socat cron && \
    apt-get clean && \
    cd /usr/local && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
    
WORKDIR /root
CMD [ "./sh", "-P", "/etc/service"]
