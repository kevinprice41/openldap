#!/bin/sh

set -eu

if [ ! -e /etc/ldap/bootstrap.lock ]; then
  echo "Configuring OpenLDAP"
  cat <<EOF | debconf-set-selections
slapd slapd/internal/generated_adminpw password ${ADMIN_PASSWORD:-secret}
slapd slapd/internal/adminpw password ${ADMIN_PASSWORD:-secret}
slapd slapd/password2 password ${ADMIN_PASSWORD:-secret}
slapd slapd/password1 password ${ADMIN_PASSWORD:-secret}
slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
slapd slapd/domain string ${DOMAIN:-example.com}
slapd shared/organization string ${ORGANIZATION:-Example Corporation}
slapd slapd/backend string HDB
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/no_configuration boolean false
slapd slapd/dump_database select when needed
EOF

cat >>/etc/ldap/ldap.conf <<EOF
index           cn eq

access to attrs=userPassword,shadowLastChange
        by dn="cn=admin,dc=${DOMAIN:-example},dc=com" write
        by dn="cn=pwmadmin,dc=${DOMAIN:-example},dc=com" write
        by anonymous auth
        by self write
        by * none
        
access to dn.subtree="ou=Accounts,dc=${DOMAIN:-example},dc=com"
        by dn="cn=admin,dc=${DOMAIN:-example},dc=com" write
        by dn="cn=pwmadmin,dc=${DOMAIN:-example},dc=com" write
        by anonymous auth
        by self write
        by * none
        
access to *
        by dn="cn=admin,dc=${DOMAIN:-example},dc=com" write
        by dn="cn=pwmadmin,dc=${DOMAIN:-example},dc=com" read
        by * none
EOF

cat >>/etc/ldap/schema/openldap.ldif <<EOF
dn: cn=pwm,cn=schema,cn=config
objectClass: olcSchemaConfig
cn: pwm
olcAttributeTypes: {0}( 1.3.6.1.4.1.35015.1.2.1 NAME 'pwmEventLog' E
 QUALITY octetStringMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.40 )
olcAttributeTypes: {1}( 1.3.6.1.4.1.35015.1.2.2 NAME 'pwmResponseSet
 ' EQUALITY octetStringMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.40 )
olcAttributeTypes: {2}( 1.3.6.1.4.1.35015.1.2.3 NAME 'pwmLastPwdUpda
 te' SYNTAX 1.3.6.1.4.1.1466.115.121.1.24 )
olcAttributeTypes: {3}( 1.3.6.1.4.1.35015.1.2.4 NAME 'pwmGUID' SYNTA
 X 1.3.6.1.4.1.1466.115.121.1.15 )
olcAttributeTypes: {1}( 1.3.6.1.4.1.35015.1.2.6 NAME 'pwmOtpSecret '
 EQUALITY octetStringMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.40 )
olcObjectClasses: {0}( 1.3.6.1.4.1.591242.1.2010.04.16.1 NAME 'pwmUser' AUXILI
 ARY MAY ( pwmLastPwdUpdate $ pwmEventLog $ pwmResponseSet $ pwmOtpSecret $ pw
 mGUID ) )
EOF

cat >>/etc/ldap/schema/openldap.schema <<EOF
# We try to define OID's "correctly" as outlined here:
#
# http://www.openldap.org/doc/admin23/schema.html
#
# 1.3.6.1.4.1 base OID
# 35015 organization idenfifier
# 1.1 if an objectclass
# 1.2 if an attribute
# n extra identifier
#
attributetype ( 1.3.6.1.4.1.35015.1.2.1
        NAME 'pwmEventLog'
        EQUALITY octetStringMatch
        SYNTAX 1.3.6.1.4.1.1466.115.121.1.40 )

attributetype ( 1.3.6.1.4.1.35015.1.2.2
        NAME 'pwmResponseSet'
        EQUALITY octetStringMatch
        SYNTAX 1.3.6.1.4.1.1466.115.121.1.40 )

attributetype ( 1.3.6.1.4.1.35015.1.2.3
        NAME 'pwmLastPwdUpdate'
        SYNTAX 1.3.6.1.4.1.1466.115.121.1.24 )

attributetype ( 1.3.6.1.4.1.35015.1.2.4
        NAME 'pwmGUID'
        SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 )

attributetype ( 1.3.6.1.4.1.35015.1.2.6
        NAME 'pwmOtpSecret'
        EQUALITY octetStringMatch
        SYNTAX 1.3.6.1.4.1.1466.115.121.1.40 )

objectclass ( 1.3.6.1.4.1.35015.1.1.1
        NAME 'pwmUser'
        AUXILIARY
        MAY ( pwmLastPwdUpdate $ pwmEventLog $ pwmResponseSet $
                pwmOtpSecret $ pwmGUID ) )
EOF

cat >>/etc/ldap/base.ldif <<EOF
dn: dc=example,dc=com
objectClass: dcObject
objectClass: organization
o: example.com
dc: example
dn: ou=Accounts,dc=example,dc=com
objectClass: organizationalUnit
objectClass: top
ou: Accounts
EOF

  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -f noninteractive slapd

  echo "Bootstrap finished."
  touch /etc/ldap/bootstrap.lock
else
  echo "Already bootstrapped. Skipping."
fi

echo "Starting OpenLDAP"
exec slapd -h "ldap:/// ldapi:///" -u openldap -g openldap ${LDAP_OPTS:-} -d ${LDAP_DEBUG:-"stats"}
ldapadd -x -D "cn=admin,dc=example,dc=com" -w secret -f /etc/ldap/base.ldif
