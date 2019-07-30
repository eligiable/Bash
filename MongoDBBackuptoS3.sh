#!/bin/sh
{
#Variables
HOST=localhost
DBNAME=DB_Name
DBUSER=DB_User
DBPWD=DB_Password
BUCKET=Bucket_Name/MongoDB
USER=ubuntu
TIME=$(/bin/date \+\%Y\%m\%d_\%s)
DEST=/tmp/
BKPFILE=$DBNAME$TIME.gz

#Execute Backup
echo "Backing up $DBNAME to s3://$BUCKET/";
/usr/bin/mongodump -h $HOST -d $DBNAME -u $DBUSER -p $DBPWD --gzip --archive=$DEST
/bin/mv $DEST/archive.gz $DEST/$BKPFILE
/usr/local/bin/s3cmd put $DEST$BKPFILE s3://$BUCKET/
/bin/rm -rf $DEST/$BKPFILE
echo "Backup available at https://s3.amazonaws.com/$BUCKET/$BKPFILE"
} 2>&1 | tee /tmp/backup-mongodb-script.log
