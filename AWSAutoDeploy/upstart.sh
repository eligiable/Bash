#!/bin/sh

# change it to "production" (without quotes) for on deploying proceess
CONFIG_ENV=$1

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! #
# DO NOT CHANGE ENYTHINK UNDER THIS LINE  #
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! #

#ELB_SEC_PRIVATE_IP="10.0.0.0/8"
#ELB_SSL_PRIVATE_IP="10.0.0.0/8"

export CONFIG_ENV

if [ $CONFIG_ENV == "staging" ]; then
HOSTNAME=staging.ahaseeb.com && export HOSTNAME
fi

if [ $CONFIG_ENV == "production" ]; then
HOSTNAME=secure.ahaseeb.com && export HOSTNAME
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

# ahaseeb
if [ $CONFIG_ENV == "staging" ]; then
 /bin/rm -rf /secure/www/ahaseeb/core/config.php
 /bin/ln -s /secure/www/ahaseeb/core/config.staging.php /secure/www/ahaseeb/core/config.php
 /bin/rm -rf /secure/www/ahaseeb/core/Laravel/.env
 /bin/ln -s /secure/www/ahaseeb/core/Laravel/.env.staging /secure/www/ahaseeb/core/Laravel/.env
fi

if [ $CONFIG_ENV == "production" ]; then
 /bin/rm -rf /secure/www/ahaseeb/core/config.php
 /bin/ln -s /secure/www/ahaseeb/core/config.production.php /secure/www/ahaseeb/core/config.php
 /bin/rm -rf /secure/www/ahaseeb/core/Laravel/.env
 /bin/ln -s /secure/www/ahaseeb/core/Laravel/.env.production /secure/www/ahaseeb/core/Laravel/.env
fi

/bin/chown -R www:www /secure/www/ahaseeb/core/config.php
/bin/chown -R www:www /secure/www/ahaseeb/core/Laravel/.env

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
/bin/sed -i "s/CONFIG_ENV=[^ ]*/CONFIG_ENV=${CONFIG_ENV}/g"  /var/spool/cron/www

#php: error
if [ $CONFIG_ENV == "staging" ]; then
 /bin/ln -sf /etc/php-7.1.ini.staging /etc/php-7.1.ini
fi
if [ $CONFIG_ENV == "production" ]; then
 /bin/ln -sf /etc/php-7.1.ini.production /etc/php-7.1.ini
fi

#php: php-fpm CONFIG_ENV
rm /etc/php-fpm.d/current.conf 
if [ $CONFIG_ENV == "staging" ]; then
 /bin/ln -sf /etc/php-fpm.d/staging /etc/php-fpm.d/current.conf 
fi
if [ $CONFIG_ENV == "production" ]; then
 /bin/ln -sf /etc/php-fpm.d/production /etc/php-fpm.d/current.conf 
fi


# vhosts
/bin/rm /etc/nginx/vhosts/current.conf
if [ $CONFIG_ENV == "staging" ]; then
#  /bin/mv /etc/httpd/vhosts/30-secure.ahaseeb.com.conf.enabled /etc/httpd/vhosts/30-secure.ahaseeb.com.conf.disabled
#  /bin/mv /etc/httpd/vhosts/60-staging.ahaseeb.com.conf.disabled /etc/httpd/vhosts/60-staging.ahaseeb.com.conf.enabled
#  /bin/mv /etc/nginx/conf.d/vhosts/openidstaging.ahaseeb.com/openidstaging.ahaseeb.com /etc/nginx/conf.d/vhosts/openidstaging.ahaseeb.com/openidstaging.ahaseeb.com.conf
#  /bin/mv /etc/nginx/conf.d/vhosts/staging.ahaseeb.com/staging.ahaseeb.com /etc/nginx/conf.d/vhosts/staging.ahaseeb.com/staging.ahaseeb.com.conf
#  /bin/mv /etc/nginx/conf.d/vhosts/secure.ahaseeb.com/secure.ahaseeb.com.conf /etc/nginx/conf.d/vhosts/secure.ahaseeb.com/secure.ahaseeb.com
#  /bin/mv /etc/nginx/conf.d/vhosts/openid.ahaseeb.com/openid.ahaseeb.com.conf /etc/nginx/conf.d/vhosts/openid.ahaseeb.com/openid.ahaseeb.com
 ln -sf /etc/nginx/vhosts/staging.ahaseeb.com /etc/nginx/vhosts/current.conf 
fi

if [ $CONFIG_ENV == "production" ]; then
#  /bin/mv /etc/httpd/vhosts/30-secure.ahaseeb.com.conf.disabled /etc/httpd/vhosts/30-secure.ahaseeb.com.conf.enabled
#  /bin/mv /etc/httpd/vhosts/60-staging.ahaseeb.com.conf.enabled /etc/httpd/vhosts/60-staging.ahaseeb.com.conf.disabled
#  /bin/mv /etc/nginx/conf.d/vhosts/openidstaging.ahaseeb.com/openidstaging.ahaseeb.com.conf /etc/nginx/conf.d/vhosts/openidstaging.ahaseeb.com/openidstaging.ahaseeb.com
#  /bin/mv /etc/nginx/conf.d/vhosts/staging.ahaseeb.com/staging.ahaseeb.com.conf /etc/nginx/conf.d/vhosts/staging.ahaseeb.com/staging.ahaseeb.com
#  /bin/mv /etc/nginx/conf.d/vhosts/secure.ahaseeb.com/secure.ahaseeb.com /etc/nginx/conf.d/vhosts/secure.ahaseeb.com/secure.ahaseeb.com.conf
#  /bin/mv /etc/nginx/conf.d/vhosts/openid.ahaseeb.com/openid.ahaseeb.com /etc/nginx/conf.d/vhosts/openid.ahaseeb.com/openid.ahaseeb.com.conf
 ln -sf /etc/nginx/vhosts/secure.ahaseeb.com /etc/nginx/vhosts/current.conf 
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
 #bin/chmod 755 /etc/cron.daily/update-motd /etc/cron.daily/yum-update /etc/cron.daily/ahaseeb
 /bin/chmod 755 /etc/cron.daily/ahaseeb
fi

if [ $CONFIG_ENV == "production" ]; then
 #/bin/chmod 000 /etc/cron.daily/update-motd /etc/cron.daily/yum-update /etc/cron.daily/ahaseeb
 /bin/chmod 000 /etc/cron.daily/ahaseeb
fi

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
rm /etc/php-fpm-7.1.d/www.conf
/sbin/service php-fpm-7.1 restart
/sbin/service nginx restart
