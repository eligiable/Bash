#!/bin/bash

#Text Colors
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
YELLOW="\e[33m"
ENDC="\e[0m"

#Certificate Name
echo -e -n ${YELLOW}"Enter a name for your Certificate (without tailoring .crt .pem or .key): "${ENDC}
read certName

#in-case the Certificate Name needs to be static for all, change below
#certName=ciCA

#DNS Values
echo -e -n ${YELLOW}"Enter 1st DNS Name: "${ENDC}
read DNS1
echo -e -n ${YELLOW}"Enter 2nd DNS Name: "${ENDC}
read DNS2
echo -e -n ${YELLOW}"Enter 3rd DNS Name: "${ENDC}
read DNS3
echo -e -n ${YELLOW}"Enter 4th DNS Name: "${ENDC}
read DNS4
echo -e -n ${YELLOW}"Enter 5th DNS Name: "${ENDC}
read DNS5

#Changing DNS Values in mongo-cert-vars.sh
sed -i -e "s/DNS1/$DNS1/g" -e "s/DNS2/$DNS2/" -e "s/DNS3/$DNS3/" -e "s/DNS4/$DNS4/" -e "s/DNS5/$DNS5/" mongo-cert-vars.sh

#Certificate Generation
echo -e ${GREEN}Generating Certificate ...${ENDC}
openssl req -config mongo-cert-vars.sh -newkey rsa:2048 -new -x509 -days 365 -nodes -out $certName.crt -keyout $certName.key
echo

#Merging Certificate into .pem
echo -e ${GREEN}Creating .pem file from $certName.key and $certName.crt${ENDC}
cat $certName.key $certName.crt > $certName.pem
echo

#Moving file to /tmp
echo -e ${GREEN}Moving files to /tmp directory ...${ENDC}
mv $certName.* /tmp
echo

#Display .pem content
read -r -p 'Would you like to view the Certificate [y/N]' response
if [[ "$response" =~ ^([yY])$ ]]
then
   openssl x509 -in /tmp/$certName.pem -text -noout
fi
echo

#Copy Certificates to Remote Nodes
echo -e -n ${YELLOW}"Enter IP for Server 1: "${ENDC}
read IP1
echo -e -n ${YELLOW}"Enter IP for Server 2: "${ENDC}
read IP2
echo -e -n ${YELLOW}"Enter IP for Server 3: "${ENDC}
read IP3
echo -e ${GREEN}Copying Certificates to $IP1, $IP2, $IP3${ENDC}
scp /tmp/$certName.*  $IP1:/home/ec2-user/
scp /tmp/$certName.*  $IP2:/home/ec2-user/
scp /tmp/$certName.*  $IP3:/home/ec2-user/

#Unset DNS Values to Default
echo -e ${GREEN}Unset DNS Values to Default ...${ENDC}
sed -i -s "s/$DNS5/DNS5/" mongo-cert-vars.sh
sed -i -s "s/$DNS4/DNS4/" mongo-cert-vars.sh
sed -i -s "s/$DNS3/DNS3/" mongo-cert-vars.sh
sed -i -s "s/$DNS2/DNS2/" mongo-cert-vars.sh
sed -i -s "s/$DNS1/DNS1/" mongo-cert-vars.sh
