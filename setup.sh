#!/bin/bash

#TODO:
#Change container names to partially hide "pca-gophish" signature in email
#Remove sudo (needed for testing on local machine but not necessary for kit)
#Maybe get rid of unnecessary sleeps?


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

#unzipping the zip with the certs in it
unzip *.zip

#copying the keys to the appropriate secrets folders
cp *fullchain* ~/pca-gophish-composition/secrets/gophish/admin_fullchain.pem
cp *fullchain* ~/pca-gophish-composition/secrets/postfix/fullchain.pem
cp *privkey* ~/pca-gophish-composition/secrets/gophish/admin_privkey.pem
cp *privkey* ~/pca-gophish-composition/secrets/postfix/privkey.pem

#blasting full perms as this perms has caused issues in the past
chmod 777 ~/pca-gophish-composition/secrets/postfix/*
chmod 777 ~/pca-gophish-composition/secrets/gophish/*

echo -e '\n'
#cleaning up the unzipped files (the zip containing the certs remains)
rm *.pem

#changing the config.json
sed -i 's/"listen_url": "0.0.0.0:8080",/"listen_url": "0.0.0.0:8443",/g' ~/pca-gophish-composition/secrets/gophish/config.json

sed -i 's/"use_tls": false/"use_tls": true/g' ~/pca-gophish-composition/secrets/gophish/config.json

#changing the docker-compose.yml file

sed -i 's/target: 8080/target: 8443/g' ~/pca-gophish-composition/docker-compose.yml
sed -i 's/published: 3380/published: 8443/g' ~/pca-gophish-composition/docker-compose.yml

#changing the docker-compose.yml file to add the domain

sed -i "s/PRIMARY_DOMAIN=example.com/PRIMARY_DOMAIN=$domain/g" ~/pca-gophish-composition/docker-compose.yml


#running the docker containers

echo "All config values have been changed, starting the containers."
sudo docker-compose -f ~/pca-gophish-composition/docker-compose.yml up -d

#sleeping for two seconds to let containers start (to be safe)

sleep 2

#pushing admin password to file:

admin_pass=$(cd ~/pca-gophish-composition; sudo docker-compose logs gophish | grep "username admin and the password" | awk -F 'and the password ' '{print $2}' |cut -d '"' -f 1 | tail -n1)

echo $admin_pass > admin_pass.txt
echo -e '\n'"The username:password to login to gophish is: admin : $admin_pass"
echo -e "Change this to something for your team when you login for the first time"'\n'

dkim=$(cd ~/pca-gophish-composition; sudo docker-compose logs postfix | grep -A1 "DKIM1" | awk -F 'p=' '{print $2}' | cut -d '"' -f 1 | awk NF | tail -n1)

echo $dkim > dkim.txt
echo "Insert the value below as your DKIM record:"
echo -e $dkim '\n'

echo -e "Everything should be set up. Navigate to Gophish using your bookmark and make sure everything works!"'\n'

echo "If your server doesn't start or something doesn't work, double check the names"
echo "and locations of the certificates, as well as the respective config files. To check"
echo "this manually, consult the gitlab gophish guide. Revert to the gold snapshot if this server is FUBAR."
echo -e "If there is an error with this script, please reach out to OS1 Miller and tell him his script sucks (and the error you had). Thanks!"
