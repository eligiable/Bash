#!/bin/bash
        #Change Settings below as per need
        SleepTime="15"
        TotalConnections="50"

if curl -s --insecure --head  --request GET https://example.com | grep "200\|301\|302" > /dev/null 2>&1; then
        echo "example.com is UP" >> /tmp/isUpDown.log
else
        rm -rf /tmp/isUpDown.log
        echo "example.com is DOWN" >> /tmp/isUpDown.log

        #Get Sleep Requests
        #mysql -h100.121.31.99 -uroot -1q2w3e4r5t_ -e "SELECT CONCAT('KILL ',ID,';') FROM information_schema.processlist WHERE COMMAND = 'Sleep' AND TIME >= '${SleepTime}'" >> /tmp/isUpDown.txt

        #Remove Unwanted Text
        #sed -i "/CONCAT('KILL ',ID,';')/d" /tmp/isUpDown.txt

        #Get Total Sleep Requests
        TotalSleeps="$(mysql -B --column-names=0 -h100.121.31.99 -uroot -1q2w3e4r5t_ -e "SELECT @SleepRequests := COUNT(*) FROM information_schema.processlist WHERE COMMAND = 'Sleep';")" >> /tmp/isUpDown.txt

        echo Sleep Time = "${SleepTime}" >> /tmp/isUpDown.log
        echo Total Conneciton = "${TotalConnections}" >> /tmp/isUpDown.log
        echo Total Sleeps = "${TotalSleeps}" >> /tmp/isUpDown.log

        if [ "${TotalSleeps}" -le "${TotalConnections}" ]; then
                #cat /tmp/isUpDown.txt >> /tmp/isUpDown.log && $(which mail) -s "URGENT | Example Down" it-support@example.com < /tmp/isUpDown.log -a From:"Example <no-reply@example.com>" >> /dev/null 2>&1
                $(which mail) -s "URGENT Notification | Example Down" it-support@example.com < /tmp/isUpDown.log -a From:"Example TV<no-reply@example.com>"  > /dev/null 2>&1;
        else
                #Kill MySQL Requests
                #mysql -h192.168.1.55 -uroot -pmagento -e "source /tmp/isUpDown.txt"

                #Restart PHP-FPM
                service php7.0-fpm restart >> /tmp/isUpDown.log

                $(which mail) -s "Restarted | Example was Down" it-support@example.com < /tmp/isUpDown.log -a From:"Example TV<no-reply@example.com>" > /dev/null 2>&1;
        fi
fi
