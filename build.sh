#!/bin/bash

Blue=$(tput setaf 27)
Green=$(tput setaf 10)
Red=$(tput setaf 1)

echo "${Red}Before continuing with this script, three things are necessary:"
echo -e "${Red}First make sure that the certificate zip file is in the /home/cpt directory."'\n'
read -p "${Red}It is there? Yn :  " cert

if [[ $cert == 'n' ]]; then
	echo "Put the zip file in /home/cpt and restart this script."
	exit
fi

echo -e "${Red}Second, run apt update and apt install golang-go"
read -p "${Red}Did you do this? Yn :  " golang

if [[ $golang == 'n' ]]; then
	echo "Update your system and install golang."
	exit
fi

echo -e '\n'"${Red}Third, what is the domain you are using for this engagement?"
read -p "${Red}The format should be domain.com:  " domain

echo -e "${Green}Pulling the gophish repo'\n'"
git clone https://github.com/gophish/gophish.git

#unzipping the zip with the certs in it
unzip *.zip

#editing the gophish config.json file with the certs and proper settings
privkey=$(find / -name *privkey* -print -quit 2>/dev/null)
fullchain=$(find / -name *fullchain* -print -quit 2>/dev/null)

sed -i "s|gophish_admin.crt|$fullchain|g" ~/gophish/config.json
sed -i "s|gophish_admin.key|$privkey|g" ~/gophish/config.json
sed -i 's/127.0.0.1:/0.0.0.0:/g' ~/gophish/config.json
sed -i 's/0.0.0.0:80/0.0.0.0:8443/g' ~/gophish/config.json
sed -i "s|example.crt|$fullchain|g" ~/gophish/config.json
sed -i "s|example.key|$privkey|g" ~/gophish/config.json
sed -i 's/false/true/g' ~/gophish/config.json

#stripping out fingerprints and building the binary
cd ~/gophish
# Stripping X-Gophish 
sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request_test.go
sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog.go
sed -i 's/X-Gophish-Contact/X-Contact/g' models/maillog_test.go
sed -i 's/X-Gophish-Contact/X-Contact/g' models/email_request.go
# Stripping X-Gophish-Signature
sed -i 's/X-Gophish-Signature/X-Signature/g' webhook/webhook.go
# Changing server name
sed -i 's/const ServerName = "gophish"/const ServerName = "IGNORE"/' config/config.go
#Changing rid value
sed -i 's/const RecipientParameter = "rid"/const RecipientParameter = "userID"/g' models/campaign.go
go build
cd ~

#copying the keys to the appropriate secrets folders
cp *fullchain* ~/pca-gophish-composition/secrets/postfix/fullchain.pem
cp *privkey* ~/pca-gophish-composition/secrets/postfix/privkey.pem

#blasting full perms as this perms has caused issues in the past
chmod 777 ~/pca-gophish-composition/secrets/postfix/*

#changing the docker-compose.yml file to add the domain

sed -i "s/PRIMARY_DOMAIN=example.com/PRIMARY_DOMAIN=$domain/g" ~/pca-gophish-composition/docker-compose.yml

docker-compose -f ~/pca-gophish-composition/docker-compose.yml up -d postfix

#sleeping for two seconds to let containers start (to be safe)

sleep 2

dkim=$(docker-compose -f ~/pca-gophish-composition/docker-compose.yml logs postfix | grep -A1 "DKIM1" | awk -F 'p=' '{print $2}' | cut -d '"' -f 1 | awk NF | tail -n1)

echo $dkim > dkim.txt
echo -e '\n'"${Green}Insert the value below as your DKIM record:"
echo -e ${Green} $dkim '\n'

echo -e '\n'"${Blue}The postfix container is running and the gophish binary is built."'\n'
echo -e '\n'"${Blue}When making a sending profile, the SMTP server should be 172.16.202.2:587."'\n'
echo -e '\n'"${Blue}Run the gophish binary in a pseudo terminal and make note of the initial password."'\n'
echo -e '\n'"${Blue}If you want to COMPLETELY strip gophish IOCs from your email, rename this vm using \"sudo hostname <new hostname>\"."'\n'
