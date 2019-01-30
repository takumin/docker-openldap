#!/bin/sh

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

  if [ -z "${OPENLDAP_CONFIG_ROOTDN}" ]; then
    OPENLDAP_CONFIG_ROOTDN="cn=admin,cn=config"
  fi
  if [ -z "${OPENLDAP_CONFIG_ROOTPW}" ]; then
    OPENLDAP_CONFIG_ROOTPW="config"
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

  if [ ! -d "/etc/openldap/schema" ]; then
    cp -r "/usr/share/openldap/schema" "/etc/openldap/schema"
  fi

  if [ ! -d "/etc/openldap/slapd.d" ]; then
    mkdir -p "/etc/openldap/slapd.d"
  fi

  if [ ! -d "/run/openldap" ]; then
    mkdir -p "/run/openldap"
  fi

  ##############################################################################
  # Config
  ##############################################################################

  if [ ! -f "/etc/openldap/slapd.conf" ]; then
    dockerize -template /usr/local/etc/slapd.conf.tmpl:/etc/openldap/slapd.conf
  fi

  ##############################################################################
  # Permission
  ##############################################################################

  chown -R openldap:openldap /etc/openldap
  chown -R openldap:openldap /run/openldap
  chown -R openldap:openldap /var/lib/openldap

  ##############################################################################
  # Check
  ##############################################################################

  /usr/sbin/slaptest -v -d ${OPENLDAP_DEBUG} -u -f /etc/openldap/slapd.conf -F /etc/openldap/slapd.d

  ##############################################################################
  # Daemon
  ##############################################################################

  OPTS=""
  OPTS="${OPTS} -d ${OPENLDAP_DEBUG}"
  OPTS="${OPTS} -f /etc/openldap/slapd.conf"
  OPTS="${OPTS} -F /etc/openldap/slapd.d"
  OPTS="${OPTS} -u ${OPENLDAP_UID}"
  OPTS="${OPTS} -g ${OPENLDAP_GID}"

  mkdir -p /etc/sv/openldap
  echo '#!/bin/sh'                    >  /etc/sv/openldap/run
  echo 'set -e'                       >> /etc/sv/openldap/run
  echo 'exec 2>&1'                    >> /etc/sv/openldap/run
  echo "exec /usr/sbin/slapd ${OPTS}" >> /etc/sv/openldap/run
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
