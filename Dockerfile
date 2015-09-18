FROM debian:jessie
MAINTAINER Kevin Price <kevinprice41@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
  apt-get -y install slapd ldap-utils ldapscripts && \
  rm -rf /var/lib/apt/lists/*

EXPOSE 389

# Add VOLUMEs to allow backup of configs, database, etc
# This is meant to be leveraged by mounting volumes to a
# higly available datastore for multiple application front ends
VOLUME ["/etc/ldap", "/var/lib/ldap", "/run/slapd"]

ADD script/start.sh /usr/local/bin/start

ENTRYPOINT ["slapd"]
CMD ["-h", "ldap:/// ldapi:///", "-u", "openldap", "-g", "openldap", "-d0"]
