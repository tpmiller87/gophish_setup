#!/bin/bash

#TODO:
#Remove sudo (needed for testing on local machine but not necessary for kit)
#change the hostname and containers in the yaml file instead of after to completely strip infra leakage


echo "Before continuing with this script, two things are necessary:"
echo -e "First make sure that the certificate zip file is in the /home/cpt directory."'\n'
read -p 'It is there? Yn :  ' cert

if [[ $cert == 'n' ]]; then
	echo "Put the zip file in /home/cpt and restart this script."
	exit
fi

echo -e '\n'"Second, what is the domain you are using for this engagement?"
read -p 'The format should be "domain.com":  ' domain

echo -e '\n'

sleep 2
echo "********************************************************************************************"
echo -e "This script renames the folder from which the containers are spawned, as it leaves a fingerprint"
echo -e "in the sent emails. It also changes the container image for Gophish and renames the containers."
echo -e "To view log files, 'gophish' and 'postfix' still work."
echo -e "********************************************************************************************"'\n'
sleep 2

mv ~/pca-gophish-composition ~/sendMail

#unzipping the zip with the certs in it
unzip *.zip

#copying the keys to the appropriate secrets folders
cp *fullchain* ~/sendMail/secrets/gophish/admin_fullchain.pem
cp *fullchain* ~/sendMail/secrets/postfix/fullchain.pem
cp *privkey* ~/sendMail/secrets/gophish/admin_privkey.pem
cp *privkey* ~/sendMail/secrets/postfix/privkey.pem

#blasting full perms as this perms has caused issues in the past
chmod 777 ~/sendMail/secrets/postfix/*
chmod 777 ~/sendMail/secrets/gophish/*

echo -e '\n'
#cleaning up the unzipped files (the zip containing the certs remains)
rm *.pem

#changing the config.json
sed -i 's/"listen_url": "0.0.0.0:8080",/"listen_url": "0.0.0.0:8443",/g' ~/sendMail/secrets/gophish/config.json

sed -i 's/"use_tls": false/"use_tls": true/g' ~/sendMail/secrets/gophish/config.json

#changing the docker-compose.yml file (ports and customized gophish binary)

#sed -i '/gophish:/a\ \ \container_name: MX' ~/sendMail/docker-compose.yml
sed -i 's\image: cisagov/gophish:0.11.0-cisa.1\image: tmil87/cptphish:latest\g' ~/sendMail/docker-compose.yml
#sed -i "28i\  \hostname: MXServ" ~/sendMail/docker-compose.yml
sed -i 's/target: 8080/target: 8443/g' ~/sendMail/docker-compose.yml
sed -i 's/published: 3380/published: 8443/g' ~/sendMail/docker-compose.yml
#sed -i "66i\  \container_name: Postfix" ~/sendMail/docker-compose.yml
#sed -i "67i\  \hostname: Postfix" ~/sendMail/docker-compose.yml


#changing the docker-compose.yml file to add the domain

sed -i "s/PRIMARY_DOMAIN=example.com/PRIMARY_DOMAIN=$domain/g" ~/sendMail/docker-compose.yml


#running the docker containers

echo "All config values have been changed, pulling and then starting the containers."
sudo docker-compose -f ~/sendMail/docker-compose.yml pull
sleep 1
sudo docker-compose -f ~/sendMail/docker-compose.yml up -d

#sleeping for two seconds to let containers start (to be safe)

sleep 2

#pushing admin password to file:

admin_pass=$(cd ~/sendMail; sudo docker-compose logs gophish | grep "username admin and the password" | awk -F 'and the password ' '{print $2}' |cut -d '"' -f 1 | tail -n1)

echo $admin_pass > admin_pass.txt
echo -e '\n'"The username:password to login to gophish is: admin : $admin_pass"
echo -e "Change this to something for your team when you login for the first time"'\n'

dkim=$(cd ~/sendMail; sudo docker-compose logs postfix | grep -A1 "DKIM1" | awk -F 'p=' '{print $2}' | cut -d '"' -f 1 | awk NF | tail -n1)

echo $dkim > dkim.txt
echo "Insert the value below as your DKIM record:"
echo -e $dkim '\n'

echo "Changing the container names to strip any leakage of infrastructure"

gophish_container=$(sudo docker ps | grep tmil87/cptphish | cut -d ' ' -f 1 | awk NF)
postfix_container=$(sudo docker ps | grep cisagov/postfix | cut -d ' ' -f 1 | awk NF)

sudo docker rename  $gophish_container OutlookSendMail
sudo docker rename  $postfix_container Postfix

echo -e '\n'"Everything should be set up. Navigate to Gophish using your bookmark and make sure everything works!"'\n'

echo "If your server doesn't start or something doesn't work, double check the names"
echo "and locations of the certificates, as well as the respective config files. To check"
echo "this manually, consult the gitlab gophish guide. Revert to the gold snapshot if this server is FUBAR."
echo -e "If there is an error with this script, please reach out to OS1 Miller and tell him his script sucks (and the error you had). Thanks!"
