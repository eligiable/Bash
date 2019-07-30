#!/bin/bash -x
{
# Prserve Magento2 Admin Users
rm -rf /tmp/magento2_live_adminusers.sql
mysqldump -u root -pmagento magento2_live_adminusers > /tmp/magento2_live_adminusers.sql
mysql --user=root --password=magento -e "source ~/scripts/process_magento2_live_adminusers.sql"

# Unzip the Downloaded Backup
mysql_dump="$(ls /tmp/magento2_live_*.*.sql.gz | tail -n 1)"
gzip -d "${mysql_dump}" >> /tmp/download_magento_live.log

# Restore Database to magento2_live
mysql_sql="$(ls /tmp/magento2_live_*.*.sql | tail -n 1)"
sed -i 's/ROW_FORMAT=FIXED//g' "${mysql_sql}"
mysql -u root --password=magento magento2_live < "${mysql_sql}"

# Process magento2_live to replicate INT
mysql --user=root --password=magento -e "source ~/scripts/process_magento2_live.sql"

# Process magento2_live to UPDATE Auto_Increment values
#mysql --user=root --password=magento -e "source ~/scripts/process_magento2_live_tableincrement.sql"

# Change the Database Name in the Extracted Backup
sed -i 's|magento2_live|magento_production_backup|' "${mysql_sql}"

# Restore Database to magento_production_backup
mysql -u root --password=magento magento_production_backup < "${mysql_sql}"

RETVAL=$?
[ $RETVAL -eq 0 ] && echo "${mysql_sql}" has been successfully restored to magento2_live and magento_production_backup databases.
[ $RETVAL -ne 0 ] && echo "Restoration Failed"
}  2>&1 | tee /tmp/download_magento2_live_script.log
