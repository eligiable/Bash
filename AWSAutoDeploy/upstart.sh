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
HOSTNAME={YOUR_VALUE} && export HOSTNAME
echo $HOSTNAME > /etc/hostname
fi

if [ $CONFIG_ENV == "production" ]; then
HOSTNAME={YOUR_VALUE} && export HOSTNAME
echo $HOSTNAME > /etc/hostname
export ELB_PRIVATE_IP
fi

if [ $CONFIG_ENV == "eu" ]; then
HOSTNAME={YOUR_VALUE} && export HOSTNAME
echo $HOSTNAME > /etc/hostname
export ELB_PRIVATE_IP
fi

# setting hostname
/bin/hostname $HOSTNAME
/bin/sed -i "s/HOSTNAME=.*/HOSTNAME=${HOSTNAME}/g" /etc/sysconfig/network
/bin/echo "127.0.0.1   localhost localhost.localdomain" > /etc/hosts
/sbin/service rsyslog restart

# seting config_env
/bin/echo $CONFIG_ENV > /etc/CONFIG_ENV
/bin/echo "export CONFIG_ENV=${CONFIG_ENV}" > /etc/profile.d/configenv.sh
/bin/chmod 0644 /etc/profile.d/configenv.sh

# update config_env
if [ $CONFIG_ENV == "staging" ]; then
 /bin/rm -rf /var/www/{YOUR_VALUE}/core/config.php
 /bin/ln -s /var/www/{YOUR_VALUE}/core/config.staging.php /var/www/{YOUR_VALUE}/core/config.php
 /bin/rm -rf /var/www/{YOUR_VALUE}/core/Laravel/.env
 /bin/ln -s /var/www/{YOUR_VALUE}/core/Laravel/.env.staging /var/www/{YOUR_VALUE}/core/Laravel/.env
fi

if [ $CONFIG_ENV == "production" ]; then
 /bin/rm -rf /var/www/{YOUR_VALUE}/core/config.php
 /bin/ln -s /var/www/{YOUR_VALUE}/core/config.production.php /var/www/{YOUR_VALUE}/core/config.php
 /bin/rm -rf /var/www/{YOUR_VALUE}/core/Laravel/.env
 /bin/ln -s /var/www/{YOUR_VALUE}/core/Laravel/.env.production /var/www/{YOUR_VALUE}/core/Laravel/.env
fi

if [ $CONFIG_ENV == "eu" ]; then
 /bin/rm -rf /var/www/{YOUR_VALUE}/core/config.php
 /bin/ln -s /var/www/{YOUR_VALUE}/core/config.eu.php /var/www/{YOUR_VALUE}/core/config.php
 /bin/rm -rf /var/www/{YOUR_VALUE}/core/Laravel/.env
 /bin/ln -s /var/www/{YOUR_VALUE}/core/Laravel/.env.eu /var/www/{YOUR_VALUE}/core/Laravel/.env
fi

/bin/chown -R nginx:nginx /var/www/{YOUR_VALUE}/core/config.php
/bin/chown -R nginx:nginx /var/www/{YOUR_VALUE}/core/Laravel/.env

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
 ln -sf /etc/nginx/vhosts/{YOUR_VALUE} /etc/nginx/vhosts/current.conf 
fi

if [ $CONFIG_ENV == "production" ]; then
 ln -sf /etc/nginx/vhosts/{YOUR_VALUE} /etc/nginx/vhosts/current.conf 
fi

if [ $CONFIG_ENV == "eu" ]; then
 ln -sf /etc/nginx/vhosts/{YOUR_VALUE} /etc/nginx/vhosts/current.conf
fi

#sys updates
if [ $CONFIG_ENV == "staging" ]; then
 /bin/chmod 755 /etc/cron.daily/rkhunter
fi

if [ $CONFIG_ENV == "production" ]; then
 /bin/chmod 000 /etc/cron.daily/rkhunter
fi

if [ $CONFIG_ENV == "eu" ]; then
 /bin/chmod 000 /etc/cron.daily/rkhunter
fi

#logs + cache
rm -fr /var/www/{YOUR_VALUE}/core/Cache/DeviceDetector/*
rm -fr /var/www/{YOUR_VALUE}/core/Cache/IpModelCollection/*
rm -fr /var/www/{YOUR_VALUE}/core/Logs/*.log
rm -fr /var/www/{YOUR_VALUE}/core/Laravel/storage/logs/*.log
/bin/supervisorctl restart all

/sbin/service php-fpm restart
/sbin/service nginx restart
