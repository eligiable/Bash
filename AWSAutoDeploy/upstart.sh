#!/bin/sh
source ~/.bashrc

# change it to "production" (without quotes) for on deploying proceess
CONFIG_ENV=$1

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! #
# DO NOT CHANGE ENYTHINK UNDER THIS LINE  #
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! #

#ELB_SEC_PRIVATE_IP="10.0.0.0/8"
#ELB_SSL_PRIVATE_IP="10.0.0.0/8"

export CONFIG_ENV

if [ $CONFIG_ENV == "staging" ]; then
HOSTNAME=staging.{YOUR_VALUE}.com && export HOSTNAME
echo $HOSTNAME > /etc/hostname
fi

if [ $CONFIG_ENV == "production" ]; then
HOSTNAME=secure.{YOUR_VALUE}.com && export HOSTNAME
echo $HOSTNAME > /etc/hostname
export ELB_PRIVATE_IP
fi

if [ $CONFIG_ENV == "eu" ]; then
HOSTNAME=eu.{YOUR_VALUE}.com && export HOSTNAME
echo $HOSTNAME > /etc/hostname
export ELB_PRIVATE_IP
fi

# setting hostname
/bin/hostname $HOSTNAME
/bin/sed -i "s/HOSTNAME=.*/HOSTNAME=${HOSTNAME}/g" /etc/sysconfig/network
/bin/echo "127.0.0.1   localhost localhost.localdomain" > /etc/hosts
/sbin/service rsyslog restart

#motd
#/bin/echo $HOSTNAME ${CONFIG_ENV} > /etc/update-motd.d/90-hostname-env
#/bin/chmod 0755 /etc/update-motd.d/90-hostname-env

# puppet
#PUPPET_MASTER_IP="127.0.0.1"
#PUPPET_MASTER_IP=$(host my_puppet_master.company.com | grep "has address" | head -1 | awk '{print $NF}')
#echo $PUPPET_MASTER_IP puppet >> /etc/hosts
#puppet apply /etc/puppet/manifests/init.pp

# seting config_env
/bin/echo $CONFIG_ENV > /etc/CONFIG_ENV
/bin/echo "export CONFIG_ENV=${CONFIG_ENV}" > /etc/profile.d/configenv.sh
/bin/chmod 0644 /etc/profile.d/configenv.sh

# some php fixes
#/usr/init.d/create_php_sess_dirs.sh
#/bin/mkdir -p /dev/shm/php/eaccelerator
#/bin/chown -R www.www /dev/shm/php/eaccelerator

# {YOUR_VALUE} - WALTER
if [ $CONFIG_ENV == "staging" ]; then
 /bin/rm -rf /secure/www/{YOUR_VALUE}/core/config.php
 /bin/ln -s /secure/www/{YOUR_VALUE}/core/config.staging.php /secure/www/{YOUR_VALUE}/core/config.php
 /bin/rm -rf /secure/www/{YOUR_VALUE}/core/Laravel/.env
 /bin/ln -s /secure/www/{YOUR_VALUE}/core/Laravel/.env.staging /secure/www/{YOUR_VALUE}/core/Laravel/.env
fi

if [ $CONFIG_ENV == "production" ]; then
 /bin/rm -rf /secure/www/{YOUR_VALUE}/core/config.php
 /bin/ln -s /secure/www/{YOUR_VALUE}/core/config.production.php /secure/www/{YOUR_VALUE}/core/config.php
 /bin/rm -rf /secure/www/{YOUR_VALUE}/core/Laravel/.env
 /bin/ln -s /secure/www/{YOUR_VALUE}/core/Laravel/.env.production /secure/www/{YOUR_VALUE}/core/Laravel/.env
fi

if [ $CONFIG_ENV == "eu" ]; then
 /bin/rm -rf /secure/www/{YOUR_VALUE}/core/config.php
 /bin/ln -s /secure/www/{YOUR_VALUE}/core/config.eu.php /secure/www/{YOUR_VALUE}/core/config.php
 /bin/rm -rf /secure/www/{YOUR_VALUE}/core/Laravel/.env
 /bin/ln -s /secure/www/{YOUR_VALUE}/core/Laravel/.env.eu /secure/www/{YOUR_VALUE}/core/Laravel/.env
fi

/bin/chown -R nginx:nginx /secure/www/{YOUR_VALUE}/core/config.php
/bin/chown -R nginx:nginx /secure/www/{YOUR_VALUE}/core/Laravel/.env

# stunnel
#if [ $CONFIG_ENV == "staging" ]; then
# /bin/rm -rf /etc/stunnel/syslog-client.conf;
# /bin/ln -s /etc/stunnel/syslog-client.conf.staging /etc/stunnel/syslog-client.conf
#fi

#if [ $CONFIG_ENV == "production" ]; then
# /bin/rm -rf /etc/stunnel/syslog-client.conf;
# /bin/ln -s /etc/stunnel/syslog-client.conf.production /etc/stunnel/syslog-client.conf
#fi

#/sbin/service stunnel restart

# rsyslog
# if [ $CONFIG_ENV == "staging" ]; then
#  /bin/rm -rf /etc/rsyslog.conf
#  /bin/ln -s /etc/rsyslog-remote.conf.staging /etc/rsyslog.conf
#  #/bin/ln -s /etc/rsyslog-local.conf /etc/rsyslog.conf
# fi

# if [ $CONFIG_ENV == "production" ]; then
#  /bin/rm -rf /etc/rsyslog.conf
#  /bin/ln -s /etc/rsyslog-remote.conf.production /etc/rsyslog.conf
# fi

# /sbin/service rsyslog restart

# cron
/bin/sed -i "s/CONFIG_ENV=[^ ]*/CONFIG_ENV=${CONFIG_ENV}/g"  /var/spool/cron/nginx

#php: error
if [ $CONFIG_ENV == "staging" ]; then
 /bin/ln -sf /etc/php-7.1.ini.staging /etc/php.ini
fi
if [ $CONFIG_ENV == "production" ]; then
 /bin/ln -sf /etc/php-7.1.ini.production /etc/php.ini
fi
if [ $CONFIG_ENV == "eu" ]; then
 /bin/ln -sf /etc/php-7.1.ini.eu /etc/php.ini
fi

#php: php-fpm CONFIG_ENV
rm /etc/php-fpm.d/www.conf 
if [ $CONFIG_ENV == "staging" ]; then
 /bin/ln -sf /etc/php-fpm.d/staging /etc/php-fpm.d/www.conf 
fi
if [ $CONFIG_ENV == "production" ]; then
 /bin/ln -sf /etc/php-fpm.d/production /etc/php-fpm.d/www.conf 
fi

if [ $CONFIG_ENV == "eu" ]; then
 /bin/ln -sf /etc/php-fpm.d/eu /etc/php-fpm.d/www.conf
fi

# vhosts
/bin/rm /etc/nginx/vhosts/current.conf
if [ $CONFIG_ENV == "staging" ]; then
#  /bin/mv /etc/httpd/vhosts/30-secure.{YOUR_VALUE}.com.conf.enabled /etc/httpd/vhosts/30-secure.{YOUR_VALUE}.com.conf.disabled
#  /bin/mv /etc/httpd/vhosts/60-staging.{YOUR_VALUE}.com.conf.disabled /etc/httpd/vhosts/60-staging.{YOUR_VALUE}.com.conf.enabled
#  /bin/mv /etc/nginx/conf.d/vhosts/openidstaging.{YOUR_VALUE}.com/openidstaging.{YOUR_VALUE}.com /etc/nginx/conf.d/vhosts/openidstaging.{YOUR_VALUE}.com/openidstaging.{YOUR_VALUE}.com.conf
#  /bin/mv /etc/nginx/conf.d/vhosts/staging.{YOUR_VALUE}.com/staging.{YOUR_VALUE}.com /etc/nginx/conf.d/vhosts/staging.{YOUR_VALUE}.com/staging.{YOUR_VALUE}.com.conf
#  /bin/mv /etc/nginx/conf.d/vhosts/secure.{YOUR_VALUE}.com/secure.{YOUR_VALUE}.com.conf /etc/nginx/conf.d/vhosts/secure.{YOUR_VALUE}.com/secure.{YOUR_VALUE}.com
#  /bin/mv /etc/nginx/conf.d/vhosts/openid.{YOUR_VALUE}.com/openid.{YOUR_VALUE}.com.conf /etc/nginx/conf.d/vhosts/openid.{YOUR_VALUE}.com/openid.{YOUR_VALUE}.com
 ln -sf /etc/nginx/vhosts/staging.{YOUR_VALUE}.com /etc/nginx/vhosts/current.conf 
fi

if [ $CONFIG_ENV == "production" ]; then
#  /bin/mv /etc/httpd/vhosts/30-secure.{YOUR_VALUE}.com.conf.disabled /etc/httpd/vhosts/30-secure.{YOUR_VALUE}.com.conf.enabled
#  /bin/mv /etc/httpd/vhosts/60-staging.{YOUR_VALUE}.com.conf.enabled /etc/httpd/vhosts/60-staging.{YOUR_VALUE}.com.conf.disabled
#  /bin/mv /etc/nginx/conf.d/vhosts/openidstaging.{YOUR_VALUE}.com/openidstaging.{YOUR_VALUE}.com.conf /etc/nginx/conf.d/vhosts/openidstaging.{YOUR_VALUE}.com/openidstaging.{YOUR_VALUE}.com
#  /bin/mv /etc/nginx/conf.d/vhosts/staging.{YOUR_VALUE}.com/staging.{YOUR_VALUE}.com.conf /etc/nginx/conf.d/vhosts/staging.{YOUR_VALUE}.com/staging.{YOUR_VALUE}.com
#  /bin/mv /etc/nginx/conf.d/vhosts/secure.{YOUR_VALUE}.com/secure.{YOUR_VALUE}.com /etc/nginx/conf.d/vhosts/secure.{YOUR_VALUE}.com/secure.{YOUR_VALUE}.com.conf
#  /bin/mv /etc/nginx/conf.d/vhosts/openid.{YOUR_VALUE}.com/openid.{YOUR_VALUE}.com /etc/nginx/conf.d/vhosts/openid.{YOUR_VALUE}.com/openid.{YOUR_VALUE}.com.conf
 ln -sf /etc/nginx/vhosts/secure.{YOUR_VALUE}.com /etc/nginx/vhosts/current.conf 
fi

if [ $CONFIG_ENV == "eu" ]; then
#  /bin/mv /etc/httpd/vhosts/30-secure.{YOUR_VALUE}.com.conf.disabled /etc/httpd/vhosts/30-secure.{YOUR_VALUE}.com.conf.enabled
#  /bin/mv /etc/httpd/vhosts/60-staging.{YOUR_VALUE}.com.conf.enabled /etc/httpd/vhosts/60-staging.{YOUR_VALUE}.com.conf.disabled
#  /bin/mv /etc/nginx/conf.d/vhosts/openidstaging.{YOUR_VALUE}.com/openidstaging.{YOUR_VALUE}.com.conf /etc/nginx/conf.d/vhosts/openidstaging.{YOUR_VALUE}.com/openidstaging.{YOUR_VALUE}.com
#  /bin/mv /etc/nginx/conf.d/vhosts/staging.{YOUR_VALUE}.com/staging.{YOUR_VALUE}.com.conf /etc/nginx/conf.d/vhosts/staging.{YOUR_VALUE}.com/staging.{YOUR_VALUE}.com
#  /bin/mv /etc/nginx/conf.d/vhosts/secure.{YOUR_VALUE}.com/secure.{YOUR_VALUE}.com /etc/nginx/conf.d/vhosts/secure.{YOUR_VALUE}.com/secure.{YOUR_VALUE}.com.conf
#  /bin/mv /etc/nginx/conf.d/vhosts/openid.{YOUR_VALUE}.com/openid.{YOUR_VALUE}.com /etc/nginx/conf.d/vhosts/openid.{YOUR_VALUE}.com/openid.{YOUR_VALUE}.com.conf
 ln -sf /etc/nginx/vhosts/eu.{YOUR_VALUE}.com /etc/nginx/vhosts/current.conf
fi

#memcached
# if [ $CONFIG_ENV == "staging" ]; then
#  /sbin/service memcached start
#  /sbin/chkconfig memcached on
# fi

# if [ $CONFIG_ENV == "production" ]; then
#  /sbin/service memcached stop
#  /sbin/chkconfig memcached off
# fi

#sys updates
if [ $CONFIG_ENV == "staging" ]; then
 #bin/chmod 755 /etc/cron.daily/update-motd /etc/cron.daily/yum-update /etc/cron.daily/rkhunter
 /bin/chmod 755 /etc/cron.daily/rkhunter
fi

if [ $CONFIG_ENV == "production" ]; then
 #/bin/chmod 000 /etc/cron.daily/update-motd /etc/cron.daily/yum-update /etc/cron.daily/rkhunter
 /bin/chmod 000 /etc/cron.daily/rkhunter
fi

if [ $CONFIG_ENV == "eu" ]; then
 #/bin/chmod 000 /etc/cron.daily/update-motd /etc/cron.daily/yum-update /etc/cron.daily/rkhunter
 /bin/chmod 000 /etc/cron.daily/rkhunter
fi

#logs + cache
rm -fr /secure/www/{YOUR_VALUE}/core/Cache/DeviceDetector/*
rm -fr /secure/www/{YOUR_VALUE}/core/Cache/IpModelCollection/*
rm -fr /secure/www/{YOUR_VALUE}/core/Logs/*.log
rm -fr /secure/www/{YOUR_VALUE}/core/Laravel/storage/logs/*.log
/bin/supervisorctl restart all

#ossec
# if [ $CONFIG_ENV == "staging" ]; then
#  /sbin/service ossec-hids stop
# fi

# if [ $CONFIG_ENV == "production" ]; then
#  /sbin/service ossec-hids start
#  /var/ossec/bin/syscheck_control -u all
# fi

#rpaf
# if [ $CONFIG_ENV == "staging" ]; then
#  /bin/mv /etc/httpd/conf.d/rpaf.conf /etc/httpd/conf.d/rpaf
# fi

# if [ $CONFIG_ENV == "production" ]; then
#  /bin/mv /etc/httpd/conf.d/rpaf /etc/httpd/conf.d/rpaf.conf
# /bin/sed -i "s/RPAFproxy_ips.*/RPAFproxy_ips ${ELB_SSL_PRIVATE_IP}/g" /etc/httpd/conf.d/rpaf.conf
# /bin/sed -i "s/set_real_ip_from.*/set_real_ip_from ${ELB_SEC_PRIVATE_IP};/g" /etc/nginx/nginx.conf
# fi

#clearing junk on prod
# if [ $CONFIG_ENV == "production" ]; then
#  /bin/rm /opt/*.gz
# fi

# restarting apache
#/sbin/service httpd restart
/sbin/service php-fpm restart
/sbin/service nginx restart

# activate cronjob only for the secure node with public ip address, do not change the indentation for the cron_command
get_instance_details=""
local_ip_address=$(ifconfig eth0 | awk '/inet /{print $2}' | cut -d':' -f2)

if [ "$CONFIG_ENV" == "production" ]; then
    get_instance_details=$(aws --region us-east-1 ec2 describe-instances \
        --filters "Name=tag:Name,Values=secure.{YOUR_VALUE}.com" "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId, PrivateIpAddress, PublicIpAddress]' \
        --output text | awk 'NR==1')
fi

if [ "$CONFIG_ENV" == "eu" ]; then
    get_instance_details=$(aws --region eu-west-1 ec2 describe-instances \
        --filters "Name=tag:Name,Values=eu.{YOUR_VALUE}.com" "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId, PrivateIpAddress, PublicIpAddress]' \
        --output text | awk 'NR==1')
fi

instance_id=$(echo "$get_instance_details" | awk '{print $1}')
private_ip_address=$(echo "$get_instance_details" | awk '{print $2}')
public_ip_address=$(echo "$get_instance_details" | awk '{print $3}')

if [ "$public_ip_address" == "None" ] && [ "$private_ip_address" == "$local_ip_address" ]; then
    echo "Cronjob not required to be present on this node."
else
    cron_command="CONFIG_ENV=$CONFIG_ENV
#Ansible: monthly
15 0 1 * * CONFIG_ENV=$CONFIG_ENV /usr/bin/php /secure/www/{YOUR_VALUE}/core/Cron/monthly.php
#Ansible: etl
10 0 * * * CONFIG_ENV=$CONFIG_ENV /usr/bin/php /secure/www/{YOUR_VALUE}/core/Cron/etl.php
#Ansible: daily
5 0 * * * CONFIG_ENV=$CONFIG_ENV /usr/bin/php /secure/www/{YOUR_VALUE}/core/Cron/daily.php
#Ansible: hourly
0 * * * * CONFIG_ENV=$CONFIG_ENV /usr/bin/php /secure/www/{YOUR_VALUE}/core/Cron/hourly.php
#Ansible: files
*/5 * * * * CONFIG_ENV=$CONFIG_ENV /usr/bin/php /secure/www/{YOUR_VALUE}/core/Cron/files.php
#Ansible: minutely
* * * * * CONFIG_ENV=$CONFIG_ENV /usr/bin/php /secure/www/{YOUR_VALUE}/core/Cron/minutely.php
#Ansible: darkweb
*/10 * * * * CONFIG_ENV=$CONFIG_ENV /usr/bin/php /secure/www/{YOUR_VALUE}/core/Cron/darkweb.php
#Webhooks
*/5 * * * * CONFIG_ENV=$CONFIG_ENV /usr/bin/php /secure/www/{YOUR_VALUE}/core/Cron/webhook.php"
    
    echo "$cron_command" | sudo -u nginx crontab -
    echo "Cronjobs added successfully."
fi
