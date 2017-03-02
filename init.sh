#!/usr/bin/env bash
#Do we have enough privileges?
if [ "$(id -u)" != "0" ]; then
   echo "THIS SCRIPT MUST BE RUN AS ROOT"
   exit 1
fi

#seting locales.
locale-gen en_US en_US.UTF-8 ru_RU ru_RU.UTF-8
dpkg-reconfigure locales
#Genereating mysql root password.
MYSQL_ROOT_PASSWD=$(echo $RANDOM$RANDOM | sha256sum | base64 | head -c 32)
#This password don't work anyway.
#We will use debian-sys-maint user instead MySQL root password
debconf-set-selections <<< 'mysql-server mysql-server/root_password password '$MYSQL_ROOT_PASSWD
debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password '$MYSQL_ROOT_PASSWD
apt-get update && apt-get upgrade -y
apt-get -y install apache2 libapache2-mod-php5 php5-ldap php5-mysql mysql-client mysql-server sendmail libapache2-modsecurity
#Setting up Appche2 modules.
a2enmod rewrite expires

#Security
#Unnesesary system info
sed -i 's/^ServerTokens.*$/ServerTokens Full/' /etc/apache2/conf-enabled/security.conf
mv /etc/modsecurity/modsecurity.conf{-recommended,}
echo 'SecServerSignature ""' >> /etc/modsecurity/modsecurity.conf
sed -i 's/^ServerSignature.*$/ServerSignature Off/' /etc/apache2/conf-enabled/security.conf
sed -i 's/^expose_php = On/expose_php = Off/' /etc/php5/apache2/php.ini
#Stop the POODLE
#https://www.openssl.org/~bodo/ssl-poodle.pdf
sed -i 's/^SSLProtocol all$/SSLProtocol all -SSLv3 -SSLv2/' /etc/apache2/mods-available/ssl.conf

service apache2 restart
