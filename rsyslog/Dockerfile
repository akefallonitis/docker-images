FROM debian:jessie

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -yq --no-install-recommends \
        rsyslog \
        rsyslog-elasticsearch \
        rsyslog-hiredis 

EXPOSE 514 514/udp

VOLUME [ "/var/log", "/etc/rsyslog.d" ]

ENTRYPOINT [ "rsyslogd", "-n", "-f", "/etc/rsyslog.conf", "-i", "/tmp/rsyslog.pid" ]
