#!/bin/sh
# vim: set noet :

if [ "$1" = 'openldap' ]; then
	set -e

	##############################################################################
	# Default
	##############################################################################

	if [ -z "${OPENLDAP_UID}" ]; then
		OPENLDAP_UID=1000
	fi
	if [ -z "${OPENLDAP_GID}" ]; then
		OPENLDAP_GID=1000
	fi

	if [ -z "${OPENLDAP_DEBUG}" ]; then
		OPENLDAP_DEBUG=0
	fi

	if [ -z "${OPENLDAP_CONFIG_DN}" ]; then
		OPENLDAP_CONFIG_DN="cn=admin,cn=config"
	fi
	if [ -z "${OPENLDAP_CONFIG_PW}" ]; then
		OPENLDAP_CONFIG_PW="admin"
	fi

	##############################################################################
	# Check
	##############################################################################

	if echo -n "${OPENLDAP_UID}" | grep -Eqsv '^[0-9]+$'; then
		echo 'Please numric value: OPENLDAP_UID'
		exit 1
	fi
	if [ "${OPENLDAP_UID}" -le 0 ]; then
		echo 'Please 0 or more: OPENLDAP_UID'
		exit 1
	fi
	if [ "${OPENLDAP_UID}" -ge 60000 ]; then
		echo 'Please 60000 or less: OPENLDAP_UID'
		exit 1
	fi

	if echo -n "${OPENLDAP_GID}" | grep -Eqsv '^[0-9]+$'; then
		echo 'Please numric value: OPENLDAP_GID'
		exit 1
	fi
	if [ "${OPENLDAP_GID}" -le 0 ]; then
		echo 'Please 0 or more: OPENLDAP_GID'
		exit 1
	fi
	if [ "${OPENLDAP_GID}" -ge 60000 ]; then
		echo 'Please 60000 or less: OPENLDAP_GID'
		exit 1
	fi

	if echo -n "${OPENLDAP_DEBUG}" | grep -Eqsv '^[0-9]+$'; then
		echo 'Please numric value: OPENLDAP_DEBUG'
		exit 1
	fi
	if [ "${OPENLDAP_DEBUG}" -lt 0 ]; then
		echo 'Please 0 or more: OPENLDAP_DEBUG'
		exit 1
	fi
	if [ "${OPENLDAP_DEBUG}" -ge 256 ]; then
		echo 'Please 256 or less: OPENLDAP_DEBUG'
		exit 1
	fi

	##############################################################################
	# Clear
	##############################################################################

	if getent passwd | awk -F ':' -- '{print $1}' | grep -Eqs '^openldap$'; then
		deluser 'openldap'
	fi
	if getent passwd | awk -F ':' -- '{print $3}' | grep -Eqs "^${OPENLDAP_UID}$"; then
		deluser "${OPENLDAP_UID}"
	fi
	if getent group | awk -F ':' -- '{print $1}' | grep -Eqs '^openldap$'; then
		delgroup 'openldap'
	fi
	if getent group | awk -F ':' -- '{print $3}' | grep -Eqs "^${OPENLDAP_GID}$"; then
		delgroup "${OPENLDAP_GID}"
	fi

	##############################################################################
	# Group
	##############################################################################

	addgroup -g "${OPENLDAP_GID}" 'openldap'

	##############################################################################
	# User
	##############################################################################

	adduser -h '/nonexistent' \
		-g 'openldap,,,' \
		-s '/usr/sbin/nologin' \
		-G 'openldap' \
		-D \
		-H \
		-u "${OPENLDAP_UID}" \
		'openldap'

	##############################################################################
	# Initialize
	##############################################################################

	if [ ! -d "/etc/openldap" ]; then
		mkdir -p "/etc/openldap"
	fi

	if [ ! -d "/etc/openldap/schema" ]; then
		cp -r "/usr/share/openldap/schema" "/etc/openldap/schema"
	fi

	if [ ! -d "/run/openldap" ]; then
		mkdir -p "/run/openldap"
	fi

	if [ ! -d "/var/lib/openldap" ]; then
		mkdir -p "/var/lib/openldap"
	fi

	if [ ! -d "/var/lib/openldap/cache" ]; then
		mkdir -p "/var/lib/openldap/cache"
	fi

	if [ ! -d "/var/lib/openldap/data" ]; then
		mkdir -p "/var/lib/openldap/data"
	fi

	if [ ! -d "/var/lib/openldap/slapd.d" ]; then
		mkdir -p "/var/lib/openldap/slapd.d"
	fi

	##############################################################################
	# Config
	##############################################################################

	if [ -f /etc/openldap/slapd.conf.tmpl ]; then
		dockerize -template /etc/openldap/slapd.conf.tmpl:/run/openldap/slapd.conf
	elif [ -f /etc/openldap/slapd.conf ]; then
		cp /etc/openldap/slapd.conf /run/openldap/slapd.conf
	else
		cat > /run/openldap/slapd.conf <<- __EOF__
		pidfile  /run/openldap/slapd.pid
		argsfile /run/openldap/slapd.args
		database config
		rootdn   "${OPENLDAP_CONFIG_DN}"
		rootpw   ${OPENLDAP_CONFIG_PW}
		__EOF__
	fi

	if [ -f /etc/openldap/slapd.ldif.tmpl ]; then
		dockerize -template /etc/openldap/slapd.ldif.tmpl:/run/openldap/slapd.ldif
	elif [ -f /etc/openldap/slapd.ldif ]; then
		cp /etc/openldap/slapd.ldif /run/openldap/slapd.ldif
	fi

	if [ ! -f /run/openldap/slapd.ldif ]; then
		slaptest -v -d "${OPENLDAP_DEBUG}" -f /run/openldap/slapd.conf -n 0 -F /var/lib/openldap/slapd.d
	else
		slapadd -v -d "${OPENLDAP_DEBUG}" -F /var/lib/openldap/slapd.d -n 0 -l /run/openldap/slapd.ldif
	fi

	##############################################################################
	# Permission
	##############################################################################

	chmod 0700 /var/lib/openldap/cache
	chmod 0700 /var/lib/openldap/data

	chown -R openldap:openldap /etc/openldap
	chown -R openldap:openldap /run/openldap
	chown -R openldap:openldap /var/lib/openldap

	##############################################################################
	# Daemon
	##############################################################################

	SERV_OPTS=""
	SERV_OPTS="${SERV_OPTS} -d ${OPENLDAP_DEBUG}"
	SERV_OPTS="${SERV_OPTS} -F /var/lib/openldap/slapd.d"
	SERV_OPTS="${SERV_OPTS} -u ${OPENLDAP_UID}"
	SERV_OPTS="${SERV_OPTS} -g ${OPENLDAP_GID}"

	mkdir -p /etc/sv/openldap
	echo '#!/bin/sh'                         >  /etc/sv/openldap/run
	echo 'set -e'                            >> /etc/sv/openldap/run
	echo 'exec 2>&1'                         >> /etc/sv/openldap/run
	echo "exec /usr/sbin/slapd ${SERV_OPTS}" >> /etc/sv/openldap/run
	chmod 0755 /etc/sv/openldap/run

	##############################################################################
	# Service
	##############################################################################

	ln -s /etc/sv/openldap /etc/service/openldap

	##############################################################################
	# Running
	##############################################################################

	echo 'Starting Server'
	exec runsvdir /etc/service
fi

exec "$@"
