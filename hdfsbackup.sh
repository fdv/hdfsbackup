#!/bin/bash

###
# VARS 
#########
HDFS_BIN=$(which gohdfs)
BACKUP_ROOT="/backups"
BACKUP_HOSTDIR="${BACKUP_ROOT}/$(hostname -d | sed -E 'H;g;:t;s/(.*)(\n)(.*)(\.)(.*)/\1\4\5\2\3/;tt;s/\.(.*)\n/\1./')"
BACKUP_DIR="${BACKUP_HOSTDIR}/$(date +%Y%m%d%H%M)"
CONFIG_DIR="/etc/hdfsbackup"
INCLUDES_FILE="${CONFIG_DIR}/includes.cfg"
CONFIG_FILE="${CONFIG_DIR}/config.cfg"

###
# MAIN, DO NOT CHANGE!
#########################

if [ ! -z ${HDFS_BIN} ] || [ ! -x ${HDFS_BIN} ]; then
  echo "hdfs missing or not executable, exiting"
  exit 1
fi

if [ ! -f ${INCLUDES_FILE} ]; then
  echo "includes not found in ${INCLUDES_FILE}, exiting"
  exit 1
fi

if [ ! -f ${CONFIG_FILE} ]; then
  echo "configuration not found in ${CONFIG_FILE}, exiting"
  exit 1
fi

source ${CONFIG_FILE}

${HDFS_BIN} mkdir -p ${BACKUP_DIR}

for file in $(cat ${INCLUDES_FILE}); do
  ${HDFS_BIN} put ${file} ${BACKUP_DIR}
done

exit 0
