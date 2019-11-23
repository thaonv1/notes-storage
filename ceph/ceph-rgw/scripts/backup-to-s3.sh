#!/bin/bash
export PATH=/bin:/usr/bin:/usr/local/bin
TODAY=`date +"%d%b%Y-%H"`

################## Update below values  ########################

BACKUP_PATH='/backup/dbbackup'
MYSQL_HOST='localhost'
MYSQL_PORT='3306'
MYSQL_USER='root'
MYSQL_PASSWORD='lovely9x'
DATABASE_NAME='backupdulieu'
BACKUP_RETAIN_DAYS=30   ## Number of days to keep local backup copy
FOLDER_WP='/var/www/html/backupdulieu'

###Backup DB#########

mkdir -p ${BACKUP_PATH}/${TODAY}
echo "Backup started for database - ${DATABASE_NAME}"


mysqldump -h ${MYSQL_HOST} \
   -P ${MYSQL_PORT} \
   -u ${MYSQL_USER} \
   -p${MYSQL_PASSWORD} \
   ${DATABASE_NAME} | gzip > ${BACKUP_PATH}/${TODAY}/${DATABASE_NAME}-${TODAY}.sql.gz

if [ $? -eq 0 ]; then
  echo "Database backup successfully completed"
else
  echo "Error found during backup"
  exit 1
fi

############# Backup sourcode #### Images

echo "Backup started for sourcecode - ${DATABASE_NAME}"
if [[ -d ${FOLDER_WP} ]]; then
  tar -czvf ${BACKUP_PATH}/${TODAY}/Source-${TODAY}.tar.gz ${TODAY}  > /dev/null 2>&1
fi

####### Push to S3 ################

if [[ -e ${BACKUP_PATH}/${TODAY}/${DATABASE_NAME}-${TODAY}.sql.gz ]]; then
  s3cmd put ${BACKUP_PATH}/${TODAY}/${DATABASE_NAME}-${TODAY}.sql.gz s3://backupdulieu
fi

if [[ -e ${BACKUP_PATH}/${TODAY}/Source-${TODAY}.tar.gz ]]; then
  s3cmd put ${BACKUP_PATH}/${TODAY}/Source-${TODAY}.tar.gz s3://backupdulieu
fi

##### Remove backups older than {BACKUP_RETAIN_DAYS} days  #####

DBDELDATE=`date +"%d%b%Y" --date="${BACKUP_RETAIN_DAYS} days ago"`

if [ ! -z ${BACKUP_PATH} ]; then
      cd ${BACKUP_PATH}
      if [ ! -z ${DBDELDATE} ] && [ -d ${DBDELDATE} ]; then
            rm -rf ${DBDELDATE}
      fi
fi

### End of script ####
