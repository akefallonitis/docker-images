FROM debian:jessie

ENV DEBIAN_FRONTEND noninteractive

RUN echo "deb http://ftp.us.debian.org/debian unstable main contrib non-free" >> /etc/apt/sources.list.d/unstable.list && \ 
    apt-get update && apt-get install -yq --no-install-recommends \
        rsyslog \
        rsyslog-elasticsearch \
        rsyslog-hiredis 


EXPOSE 514 514/udp

VOLUME [ "/var/log", "/etc/rsyslog.d" ]

ENTRYPOINT [ "rsyslogd", "-n", "-f", "/etc/rsyslog.conf", "-i", "/tmp/rsyslog.pid" ]
