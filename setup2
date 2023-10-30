#!/bin/bash

echo "Before continuing with this script, three things are necessary:"
echo -e "First make sure that the certificate zip file is in the /home/cpt directory."'\n'
read -p 'It is there? Yn :  ' cert

if [[ $cert == 'n' ]]; then
	echo "Put the zip file in /home/cpt and restart this script."
	exit
fi

echo -e "Second, run apt update and apt install golang-go"
read -p 'Did you do this? Yn :  ' golang

if [[ $golang == 'n' ]]; then
	echo "Update your system and install golang."
	exit
fi

echo -e '\n'"Third, what is the domain you are using for this engagement?"
read -p 'The format should be "domain.com":  ' domain

echo -e 'Pulling the gophish repo'\n''
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
sed -i 's/const RecipientParameter = "rid"/const RecipientParameter = "request"/g' models/campaign.go
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
echo "Insert the value below as your DKIM record:"
echo -e $dkim '\n'

echo -e '\n'"Everything should be set up. Navigate to Gophish using your bookmark and make sure everything works!"'\n'

echo "If your server doesn't start or something doesn't work, double check the names"
echo "and locations of the certificates, as well as the respective config files. To check"
echo "this manually, consult the gitlab gophish guide. Revert to the gold snapshot if this server is FUBAR."
echo -e "If there is an error with this script, please reach out to OS1 Miller and tell him his script sucks (and the error you had). Thanks!"
