#!/bin/bash

#automount glusterfs
mkdir /nextcloud_data /webroot
apt install attr -y
mount -t glusterfs 10.13.13.201:/gvol0 /nextcloud_data
echo "10.13.13.201:/gvol0 /nextcloud_data glusterfs defaults,_netdev 0 0" |  tee -a /etc/fstab

#install apache and set webroot dir
apt install curl apache2 apache2-utils -y
systemctl enable apache2
sed 's/Directory \/var\/www/Directory \/webroot\/nextcloud/g' /etc/apache2/apache2.conf
systemctl restart apache2

#install mysql and additional mods for apache
apt install mariadb-server mariadb-client -y
systemctl enable mysql
mysql_secure_installation
apt  install php7.0-fpm php7.0-mysql php7.0-common php7.0-gd php7.0-json php7.0-cli php7.0-curl libapache2-mod-php7.0 php7.0-gd php7.0-zip php7.0-xml php7.0-mbstring -y 
a2enmod rewrite headers env dir mime setenvif ssl default-ssl php7.0
systemctl restart apache2

#download nexcloud
wget https://download.nextcloud.com/server/releases/nextcloud-11.0.3.zip
apt install unzip -y
unzip nextcloud-11.0.3.zip

#harden permissions for nextcloud installation
ocpath='/webroot/nextcloud'
htuser='www-data'
htgroup='root'
rootuser='root'
mkdir -p $ocpath/data
mkdir -p $ocpath/assets
mkdir -p $ocpath/updater
find ${ocpath}/ -type f -print0 | xargs -0 chmod 0640
find ${ocpath}/ -type d -print0 | xargs -0 chmod 0750
chmod 755 ${ocpath}
chown -R ${rootuser}:${htgroup} ${ocpath}/
chown -R ${htuser}:${htgroup} ${ocpath}/apps/
chown -R ${htuser}:${htgroup} ${ocpath}/assets/
chown -R ${htuser}:${htgroup} ${ocpath}/config/
chown -R ${htuser}:${htgroup} ${ocpath}/data/
chown -R ${htuser}:${htgroup} ${ocpath}/themes/
chown -R ${htuser}:${htgroup} ${ocpath}/updater/
chmod +x ${ocpath}/occ
if [ -f ${ocpath}/.htaccess ]
 then
  chmod 0644 ${ocpath}/.htaccess
  chown ${rootuser}:${htgroup} ${ocpath}/.htaccess
fi
if [ -f ${ocpath}/data/.htaccess ]
 then
  chmod 0644 ${ocpath}/data/.htaccess
  chown ${rootuser}:${htgroup} ${ocpath}/data/.htaccess
fi

#generate nextcloud db
mysql -u root -p1 <<EOF
create database nextcloud;
create user nextclouduser@localhost identified by 'XXX';
grant all privileges on nextcloud.* to nextclouduser@localhost identified by 'XXX';
flush privileges;
EOF

sudo systemctl restart mysql
sudo systemctl restart apache2

#now log into webserver and complete next cloud install
