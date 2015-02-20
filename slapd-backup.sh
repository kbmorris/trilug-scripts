#!/bin/sh

# /root/scripts/slapd-backup.sh
#
# Backup the OpenLDAP data and configuration as compressed LDIF files.
# Also backup the entire OpenLDAP directory and daemon configuration.
#
# David Robillard, April 23rd, 2012.

umask 022

PATH="/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin"
export PATH

DATE=`date +%Y%m%d`
BACKUP_DIR="/root/backup/slapd"
BACKUP_DATA_FILENAME="slapd.data.${DATE}.ldif"
BACKUP_CONFIG_FILENAME="slapd.config.${DATE}.ldif"
BACKUP_TAR_FILENAME="slapd.directory.${DATE}.tar.gz"
CA_TLS_CERT="/etc/pki/tls/certs/companyCA.crt"
DIT_CONFIG="cn=config"
DIT_SUFFIX="dc=company,dc=com"
SLAPD_CONFIG_FILENAME="/etc/ldap.conf"
SLAPD_DIR="/etc/ldap"
SLAPD_LOG_ROTATION="/etc/logrotate.d/slapd"
SLAPD_TLS_CERT="/etc/pki/tls/certs/alice.company.com.pem"
SLAPD_TLS_KEY="/etc/pki/tls/certs/alice.company.com.key"
SLAPCAT_OPTIONS="-F /etc/ldap/slapd.d"
LOGFILE="/var/log/backup/slapd.log"
KEEP="30"

# Make sure we have a log file.
if [ ! -f ${LOGFILE} ]; then
touch ${LOGFILE}

if [ "$?" -ne "0" ]; then
echo "ERROR: could not create the log file."
exit 1
fi
fi

# Check if root is running this script.
if [ `id -u` -ne "0" ]; then
echo "ERROR: only root can run this script." | tee -a ${LOGFILE}
exit 1
fi

# Make sure we have a backup directory.
if [ ! -d ${BACKUP_DIR} ]; then
mkdir -p ${BACKUP_DIR}

if [ "$?" -ne "0" ]; then
echo "ERROR: could not create the backup directory." | tee -a ${LOGFILE}
exit 1
fi
fi

# Make sure we don't have too much backup files piling up in our backup directory.
FILES=`find ${BACKUP_DIR} -type f -name "slapd.*" -print | wc -l`

if [ "${FILES}" -gt "${KEEP}" ]; then

OVER=`echo ${FILES}-${KEEP} | bc`
RMFILES=`find ${BACKUP_DIR} -type f -name "slapd.*" -print | sort -r | tail -${OVER}`
echo "NOTE: removing ${RMFILES} from the backup directory." >> ${LOGFILE}
rm ${RMFILES}
fi

# Backup the DIT data.
slapcat ${SLAPCAT_OPTIONS} -b ${DIT_SUFFIX} -l ${BACKUP_DIR}/${BACKUP_DATA_FILENAME} >/dev/null 2>&1

if [ "$?" -eq "0" ]; then

gzip -f ${BACKUP_DIR}/${BACKUP_DATA_FILENAME} 2>&1 >> ${LOGFILE}

if [ "$?" -ne "0" ] ; then
echo "ERROR: dump file compression problem." | tee -a ${LOGFILE}
exit 1
fi
else
echo "ERROR: problem running slapcat(8C) for the DIT data backup." | tee -a ${LOGFILE}
rm ${BACKUP_DIR}/${BACKUP_DATA_FILENAME}
exit 1
fi

# Backup the DIT config as an LDIF file.
slapcat ${SLAPCAT_OPTIONS} -b ${DIT_CONFIG} -l ${BACKUP_DIR}/${BACKUP_CONFIG_FILENAME} >/dev/null 2>&1

if [ "$?" -eq "0" ]; then

gzip -f ${BACKUP_DIR}/${BACKUP_CONFIG_FILENAME} 2>&1 >> ${LOGFILE}

if [ "$?" -ne "0" ] ; then
echo "ERROR: dump file compression problem." | tee -a ${LOGFILE}
exit 1
fi
else
echo "ERROR: problem running slapcat(8C) for the DIT config backup." | tee -a ${LOGFILE}
rm ${BACKUP_DIR}/${BACKUP_CONFIG_FILENAME}
exit 1
fi

# Backup the entire configuration directory.
BACKUP_FILES_LIST="${CA_TLS_CERT} ${SLAPD_CONFIG_FILENAME} ${SLAPD_DIR} ${SLAPD_LOG_ROTATION} ${SLAPD_TLS_CERT} ${SLAPD_TLS_KEY}"

tar zcf ${BACKUP_DIR}/${BACKUP_TAR_FILENAME} ${BACKUP_FILES_LIST} >/dev/null 2>&1

if [ "$?" -ne "0" ]; then
echo "ERROR: problem running config directory tar." | tee -a ${LOGFILE}
rm ${BACKUP_DIR}/${BACKUP_TAR_FILENAME}
exit 1
fi

# EOF
