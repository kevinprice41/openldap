#!/bin/bash

set -e

#Several application front ends could leverage this configuration.  
#Verify back end configuration is not already complete.
if [[ ! -f /etc/ldap/ldap.configured ]]; then

    #If the system is not configured the admin password is required
    if [[ -z "$ADMIN_PASSWORD" ]]; then
        echo >&2 "Error: slapd not configured and ADMIN_PASSWORD not set"
	echo >&2 "Did you forget to add -e ADMIN_PASSWORD=... ?"
	exit 1
    fi

    ORGANIZATION="${ORGANIZATION:-nodomain}"
    DOMAIN="${DOMAIN:-nodomain}"
    BACKEND="${BACKEND:-HDB}"
    ALLOW_V2="${ALLOW_V2:-false}"
    PURGE_DB="${PURGE_DB:-false}"
    MOVE_OLD_DB="${MOVE_OLD_DB:-true}"

    cat <<-EOF | debconf-set-selections
	slapd slapd/no_configuration  boolean false
	slapd slapd/password1         password $ADMIN_PASSWORD
	slapd slapd/password2         password $ADMIN_PASSWORD
	slapd shared/organization     string $ORGANIZATION
	slapd slapd/domain            string $DOMAIN
	slapd slapd/backend           select $BACKEND
	slapd slapd/allow_ldap_v2     boolean $ALLOW_V2
	slapd slapd/purge_database    boolean $PURGE_DB
	slapd slapd/move_old_database boolean $MOVE_OLD_DB
EOF

   dpkg-reconfigure slapd >/tmp/slapd.reconfigure 2>&1
   date +%s > /etc/ldap/ldap.configured
   
    #Updated configuration to support pwm
    cat >>/etc/ldap/slapd.conf <<-EOL
	index           cn eq
	access to attrs=userPassword,shadowLastChange
        	by dn="cn=admin,dc=domain,dc=com" write
        	by dn="cn=pwmadmin,dc=domain,dc=com" write
        	by anonymous auth
        	by self write
        	by * none
	access to dn.subtree="ou=Accounts,dc=domain,dc=com"
        	by dn="cn=admin,dc=domain,dc=com" write
        	by dn="cn=pwmadmin,dc=domain,dc=com" write
        	by anonymous auth
        	by self write
        	by * none
	access to dn.base="" by * read
	access to *
        	by dn="cn=admin,dc=domain,dc=com" write
        	by dn="cn=pwmadmin,dc=domain,dc=com" read
        	by * none
EOL
   

    cat >>/etc/ldap/schema <<-EOL
	attributetype ( 1.3.6.1.4.1.591242.2.2010.04.16.1
        	NAME 'pwmEventLog'
        	SYNTAX 1.3.6.1.4.1.1466.115.121.1.40 )
	attributetype ( 1.3.6.1.4.1.591242.2.2010.04.16.2
        	NAME 'pwmResponseSet'
        	SYNTAX 1.3.6.1.4.1.1466.115.121.1.40 )
	attributetype ( 1.3.6.1.4.1.591242.2.2010.04.16.3
		NAME 'pwmLastPwdUpdate'
        	SYNTAX 1.3.6.1.4.1.1466.115.121.1.24 )
	attributetype ( 1.3.6.1.4.1.591242.2.2010.04.16.4
        	NAME 'pwmGUID'
        	SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 )
	objectclass ( 1.3.6.1.4.1.591242.1.2010.04.16.1
        	NAME 'pwmUser'
        	AUXILIARY
        	MAY ( pwmLastPwdUpdate $ pwmEventLog $ pwmResponseSet $ pwmGUID )
EOL
   
fi

exec slapd -h "ldap:/// ldapi:///" -u openldap -g openldap ${LDAP_OPTS:-} -d ${LDAP_DEBUG:-"stats"}
