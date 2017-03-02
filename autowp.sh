#!/usr/bin/env bash

#######
#Start functions declarations
########
uid_check(){
  if [ "$(id -u)" != "0" ]; then
     echo "This script must be run as root"
     exit 1
  fi
}

script_help(){
  echo "This script automaticly install and configure Wordpress."
  echo -e "\nUsage: autowp.sh -d DOMAIN_NAME -e EMAIL"
  echo "Example: autowp.sh -d example.com -e user@example.com"
  echo "or: autowp.sh -w -f -d example.com -e user@example.com"
  echo "    -d -- domain name"
  echo "    -e -- administrator email"
  echo "    -f -- ignore domain and email check"
  echo "    -w -- create www.domain.ltd alias"
}

options_parse(){
  if [[ -z $1 || $1 = "--help" ]]; then
    script_help
    exit
  fi

  while getopts d:e:fhw flag; do
    case $flag in
      d)
        DOMAINNAME=$(echo $OPTARG | tr '[:upper:]' '[:lower:]')
        ;;
      e)
        ADMINEMAIL=$(echo $OPTARG | tr '[:upper:]' '[:lower:]')
        ;;
      f)
        FORCE="Yes"
        ;;
      w)
        WWW_ALIAS="Yes"
        ;;
      h|?)
        script_help
        exit
        ;;
    esac
  done
}

domain_check(){
  #Is domain name correct?
  RE="^(([a-z0-9](-?[a-z0-9])*)\.)*[a-z](-?[a-z0-9])+\.[a-z]{2,}$"
  if [[ ! "$DOMAINNAME" =~ $RE ]]; then
    echo -e "Error! Domain name \033[0;31m$DOMAINNAME\033[0m not valid"; exit 1
  fi
}

email_check(){
  RE="^[a-z](-?[a-z0-9])@(([a-z0-9](-?[a-z0-9])*)\.)*[a-z](-?[a-z0-9])+\.[a-z]{2,}$"
  if [[ ! "$ADMINEMAIL" =~ $RE ]]; then
    echo -e "Error! Email \033[0;31m$ADMINEMAIL\033[0m not valid"; exit 1
  fi
}

accept_data(){
  echo "New Wordpress site will be created "$DOMAINNAME
  echo -n "Alias www."$DOMAINNAME
  if [[ -z $WWW_ALIAS ]]; then
    echo "will not be created"
  else
    echo "will be created"
  fi
  echo "New MySQL tabel" $(echo $DOMAINNAME | sed 's/\.//g') "will be created"
  echo "Administrator Email "$ADMINEMAIL
  echo -n "Do you want to continue? [Y/n]"
}

db_create(){
  DBNAME=$(echo $DOMAINNAME | sed 's/\.//g')

  #debian-sys-maint password
  DSM_PASSWD=$(awk '/^password/ {print $3; exit}' /etc/mysql/debian.cnf)

  #password generation for new MySQL user
  MYSQL_WORDPRESS_PASSWD=$(openssl rand 64 | od -DAn | md5sum | head -c 32)

  #creating db
  echo "CREATE DATABASE "$DBNAME"; GRANT ALL PRIVILEGES ON "$DBNAME".* TO \
  '"$DBNAME"'@'localhost' IDENTIFIED BY '"$MYSQL_WORDPRESS_PASSWD"'; \
  FLUSH PRIVILEGES;" # | mysql -u debian-sys-maint -p"$DSM_PASSWD"
}

wp_install(){
  curl https://wordpress.org/latest.tar.gz | tar -xzvf -C /tmp/ -
  mv /tmp/wordpress /var/www/$DOMAINNAME
  #wp configuration
  mv /var/www/$DOMAINNAME/wp-config{-sample.php,.php}
    sed -i 's/database_name_here/'$DBNAME'/' /var/www/$DOMAINNAME/wp-config.php
    sed -i 's/username_here/'$DBNAME'/' /var/www/$DOMAINNAME/wp-config.php
    sed -i 's/password_here/'$MYSQL_WORDPRESS_PASSWD'/' /var/www/$DOMAINNAME/wp-config.php
  #for security reasons
  rm readme.html license.txt
}

wp_move_login(){
  cd /var/www/$DOMAINNAME/
  mv wp-login.php dd-login.php
  grep -rl "wp-login.php" | xargs sed -i 's/wp-login.php/'$LOGINURL'.php/g'
  sed -i 's/'$LOGINURL'/wp-login.php/g' wp-signup.php wp-activate.php
  chown -R www-data:www-data /var/www/$DOMAINNAME
}

apache_config(){
  cp apache.conf /etc/apache2/sites-available/$DOMAINNAME.conf
  sed -i 's/DOMAINNAMEHERE/'$DOMAINNAME'/g' /etc/apache2/sites-available/$DOMAINNAME.conf
  a2ensite $DOMAINNAME
}

remove_www_alias(){
  sed -i 's/^.*ServerAlias www\.'$DOMAINNAME'.*$//g' /etc/apache2/sites-available/$DOMAINNAME.conf
}

######
#End of functions declarations
#######

######
#Main code
######

options_parse $*
if [[ -z $FORCE ]]; then
  uid_check
  if [[ -n $DOMAINNAME ]]; then
    domain_check
  else
    echo "Miss -d option"
    script_help
  fi

  if [[ -n $ADMINEMAIL ]]; then
    email_check
  else
    echo "Miss -e option"
    script_help
  fi
  accept_data
fi
db_create
wp_install
if [[ -z $WWW_ALIAS ]]; then
    remove_www_alias
fi
apache_config
service apache2 restart
exit 0
