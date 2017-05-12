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
LOCK_FILE=/var/run/hdfsbackup.lock
HOURLY_BACKUPS=4
DAILY_BACKUPS=7
WEEKLY_BACKUPS=4
MONTHLY_BACKUPS=12
HOURLY_DIR=hourly
DAILY_DIR=daily
WEEKLY_DIR=weekly
MONTHLY_DIR=monthly

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

function clean_oldest_backup() {
  backup_dir=${1}
  retention=${2}
  oldest=$(( $retention - 1 ))
  
  log_debug "Removing oldest ${backup_dir} backup"
  
  ${HDFS_BIN} ls -h ${BACKUP_DIR}/${backup_dir}.${oldest} 2> /dev/null
  if [ ?$ -eq 0 ]; then
    ${HDFS_BIN} rm -rf ${BACKUP_DIR}/${backup_dir}.${oldest}
    
    if [ $? -gt 0 ]; then
      log_error "Removing ${BACKUP_DIR}/${backup_dir}.${oldest} failed, exiting"
    fi
  fi
  
  log_debug "Finished removing oldest ${backup_dir} backup"
}

function rotate_backups() {
  backup_dir=${1}
  retention=${2}
  oldest_possible=$(( $retention - 1 ))
  oldest_existing=$(( $oldest_possible - 1 ))
  
  for backup in {$oldest_existing..0}; do
    newoldest=$(( $backup + 1 ))
    ${HDFS_BIN} mv ${BACKUP_DIR}/${backup_dir}.${backup} ${BACKUP_DIR}/${backup_dir}.${newoldest}
  done    
}

if [ ${1} ]; then
  CONFIG_FILE=${1}
fi

if [ ! -f ${CONFIG_FILE} ]; then
  log_error "Error: configuration not found in ${CONFIG_FILE}, exiting"
fi

source ${CONFIG_FILE}

if [ -f ${LOCK_FILE} ]; then
  if [ $(cat ${LOCK_FILE}) -eq $$ ]; then
    log_error "A backup is already running with pid $(cat ${LOCK_FILE})"
  fi
  
  log_info "A lock file exists but no backup is running"
  echo $$ > ${LOCK_FILE}
  
  if [ $? -gt 0 ]; then
    log_error "Error: could not create lock file, exiting"
  fi
fi

if [ ! -f ${INCLUDES_FILE} ]; then
  log_error "Error: includes not found in ${INCLUDES_FILE}, exiting"
fi

if [ -z "${HDFS_BIN}" ] || [ ! -x ${HDFS_BIN} ]; then
  log_error "Error: hdfs missing or not executable, exiting"
fi

log_info "Starting backup"

${HDFS_BIN} mkdir -p ${BACKUP_DIR}

if [ $? != 0 ]; then
  log_error "Error: can't create backup directory ${BACKUP_DIR}, exiting"
fi

# Here we do the rolling stuff

# Is it the first rotation of the day?
first_daily=0
if [ $(( $(date +%k) - (( 24 / ${HOURLY_BACKUPS} )) )) -lt ${HOURLY_BACKUPS} ]; then
  first_daily=1
fi

# Monthly rotation:
# first of the mont
# during the first rotation
if [ $(date +%e ) -eq 1 ] && [ ${first_daily} -eq 1 ]; then
  clean_oldest_backup ${MONTHLY_DIR} ${MONTHLY_BACKUPS}
  rotate_backups ${MONTHLY_DIR} ${MONTHLY_BACKUPS}
  ${HDFS_BIN} mv ${BACKUP_DIR}/${WEEKLY_DIR}.$(( ${WEEKLY_BACKUPS} - 1 )) ${BACKUP_DIR}/${MONTHLY_DIR}.0
fi

# Weekly rotatopm
# sunday
# during the first rotation
if [ $(date +%w) -eq 0 ] && [ ${first_daily} -eq 1 ]; then
  rotate_backups ${WEEKLY_DIR} ${WEEKLY_BACKUPS}
  ${HDFS_BIN} mv ${BACKUP_DIR}/${DAILY_DIR}.$(( ${DAILY_BACKUPS} - 1 )) ${BACKUP_DIR}/${WEEKLY_DIR}.0
fi
  
# Daily
# daily.0 is the oldest hourly but only once a day
# check if current hour < 0 + (24 / number of rotations)
# if yes, do the daily rotation

if [ ${first_daily} -eq 1 ]; then
  rotate_backups ${DAILY_DIR} ${DAILY_BACKUPS}
  ${HDFS_BIN} mv ${BACKUP_DIR}/${HOURLY_DIR}.$(( ${HOURLY_BACKUPS} - 1 )) ${BACKUP_DIR}/${DAILY_DIR}.0
fi

# Hourly
rotate_backups ${HOURLY_DIR} ${HOURLY_BACKUPS}
backup_destination=${BACKUP_DIR}/${HOURLY_DIR}.0
${HDFS_BIN} mkdir -p ${backup_destination}

for file in $(cat ${INCLUDES_FILE}); do
  log_debug "Starting to backup ${file}"
  ${HDFS_BIN} put "${file}" "${backup_destination}/"
  log_debug "Finished to process ${file}"
done

log_info "Backup finished"

rm -f ${LOCK_FILE}

exit 0
