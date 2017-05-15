FROM debian:jessie

ENV DEBIAN_FRONTEND noninteractive

RUN echo "deb http://ftp.us.debian.org/debian unstable main contrib non-free" >> /etc/apt/sources.list.d/unstable.list && \ 
    apt-get update && apt-get install -yq --no-install-recommends \
        rsyslog \
        rsyslog-elasticsearch \
        redis-server \
    && \
    echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list.d/jessie-backports.list && \ 
    apt-get update && apt-get -t jessie-backports install -yq --no-install-recommends \
        rsyslog-hiredis 


EXPOSE 514 514/udp 6379

VOLUME [ "/var/log", "/etc/rsyslog.d" ]

ENTRYPOINT [ "rsyslogd", "-n", "-f", "/etc/rsyslog.conf", "-i", "/tmp/rsyslog.pid" ]
