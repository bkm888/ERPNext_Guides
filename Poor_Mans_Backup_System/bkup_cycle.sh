#!/bin/bash
#
# This script performs on backup cycle. A cron job will be used
# to tell this script when to run therby generating the cycle.
#
### VARIABLES #######################################################

FRAPPE_DIR="[/path/to/frappe-directory]"   ### without '/' at the end
MYSQL_PASSWORD="[mariadb_root_password]"
MYDB="[mariadb_db_name]"
TARGET_IP="[ip-address-target-server]"

### END VARIABLES ###################################################

rm -f -r ${FRAPPE_DIR}/backup/bk_wip/*

mv ${FRAPPE_DIR}/backup/current/*.tar.gz ${FRAPPE_DIR}/backup/last/

find ${FRAPPE_DIR}/backup/last -maxdepth 1 -type f -name "*.tar.gz" -print0 | xargs -r0 ls -t | tail -n +16 | tr '\n' '\0' | xargs -r0 rm

mysqldump -u root -p${MYSQL_PASSWORD} ${MYDB} | gzip > ${FRAPPE_DIR}/backup/bk_wip/db_bkup.sql.gz

tar -czf ${FRAPPE_DIR}/backup/bk_wip/pri-files.tar.gz -C ${FRAPPE_DIR}/frappe-bench/sites/site1.local/private/files .

tar -czf ${FRAPPE_DIR}/backup/bk_wip/pub-files.tar.gz -C ${FRAPPE_DIR}/frappe-bench/sites/site1.local/public/files .

tar -czf ${FRAPPE_DIR}/backup/current/"$(date '+%m%d-%H%M').tar.gz" -C ${FRAPPE_DIR}/backup/bk_wip .

scp ${FRAPPE_DIR}/backup/current/*.tar.gz def_user@${TARGET_IP}:${FRAPPE_DIR}/drop/

exit

# This should complete the cycle
# BKM - Apr 08,2019 @ 2:24pm
