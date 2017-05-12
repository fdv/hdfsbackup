#!/bin/bash

###
# VARS 
#########
HDFS_BIN=$(which gohdfs)
LOGGER_BIN=$(which logger)
SYSLOG_FACILITY="local5"
SYSLOG_DEBUG="${SYSLOG_FACILITY}.debug"
SYSLOG_INFO="${SYSLOG_FACILITY}.info"
SYSLOG_ERROR="${SYSLOG_FACILITY}.err"
BACKUP_ROOT="/backups"
BACKUP_HOSTDIR="${BACKUP_ROOT}/$(hostname -f | sed -E 'H;g;:t;s/(.*)(\n)(.*)(\.)(.*)/\1\4\5\2\3/;tt;s/\.(.*)\n/\1./')"
BACKUP_DIR="${BACKUP_HOSTDIR}/$(date +%Y%m%d%H%M)"
CONFIG_DIR="/etc/hdfsbackup"
INCLUDES_FILE="${CONFIG_DIR}/includes.cfg"
CONFIG_FILE="${CONFIG_DIR}/config.cfg"
LOG_LEVEL=info # debug, info, error

###
# MAIN, DO NOT CHANGE!
#########################

function log_debug() {
  if [ "${LOG_LEVEL}" == "debug" ]; then
    ${LOGGER_BIN} -t "hdfsbackup" -s -p ${SYSLOG_DEBUG} "${1}"
  fi
}

function log_info() {
  if [ "${LOG_LEVEL}" == "debug" ] || [ "${LOG_LEVEL}" == "info" ]; then
    ${LOGGER_BIN} -t "hdfsbackup" -s -p ${SYSLOG_INFO} "${1}"
  fi  
}

function log_error() {
  ${LOGGER_BIN} -t "hdfsbackup" -s -p ${SYSLOG_ERROR} "${1}"
  exit 1
}

if [ ! -f ${INCLUDES_FILE} ]; then
  log_error "Error: includes not found in ${INCLUDES_FILE}, exiting"
fi

if [ ! -f ${CONFIG_FILE} ]; then
  log_error "Error: configuration not found in ${CONFIG_FILE}, exiting"
fi

source ${CONFIG_FILE}

if [ ! -z ${HDFS_BIN} ] || [ ! -x ${HDFS_BIN} ]; then
  log_error "Error: hdfs missing or not executable, exiting"
fi

log_info "Starting backup"

${HDFS_BIN} mkdir -p ${BACKUP_DIR}

if [ $? != 0 ]; then
  log_error "Error: can't create backup directory ${BACKUP_DIR}, exiting"
fi

for file in $(cat ${INCLUDES_FILE}); do
  log_debug "Starting to backup ${file}"
  ${HDFS_BIN} put ${file} ${BACKUP_DIR}/
  log_debug "Finished to process ${file}"
done

log_info "Backup finished"

exit 0
