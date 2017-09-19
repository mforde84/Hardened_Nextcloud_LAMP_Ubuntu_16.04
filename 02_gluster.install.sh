#!/bin/bash

#generate ssl keys for glusterfs
mkdir ~/temp_ssl
cd ~/temp_ssl
openssl genrsa -out glusterfs.key 4096
openssl req -new -x509 -days 15000 -key glusterfs.key -subj "/CN=gluster1" -out glusterfs_1.pem
openssl req -new -x509 -days 15000 -key glusterfs.key -subj "/CN=gluster2" -out glusterfs_2.pem
openssl req -new -x509 -days 15000 -key glusterfs.key -subj "/CN=controller" -out controller.pem
cat glusterfs_1.pem >> glusterfs.ca
cat glusterfs_2.pem >> glusterfs.ca
cat controller.pem >> glusterfs.ca
cat glusterfs_1.pem >> controller.ca
cat glusterfs_2.pem >> controller.ca
cp controller.pem /etc/ssl/glusterfs.pem
cp controller.ca /etc/ssl/glusterfs.ca
chmod 0600 /etc/ssl/gluster*

#install gluster, secure management path
apt update
apt install sshpass glusterfs-client glusterfs-server attr -y
touch /var/lib/glusterd/secure-access 

#install on peer block1
sshpass -p XXX ssh b@10.13.13.201 '
	cd /etc/ssl
	echo "1" | sudo ls
	sudo su
	apt update
	apt install sshpass glusterfs-server attr -y
	sshpass -p XXX scp blik@10.13.13.100:~/temp_ssl/glusterfs.ca .
	sshpass -p XXX scp blik@10.13.13.100:~/temp_ssl/glusterfs_1.pem glusterfs.pem
	sshpass -p XXX scp blik@10.13.13.100:~/temp_ssl/glusterfs.key .
	chmod 0600 glusterfs.*
	systemctl start glusterfs-server.service
	systemctl enable glusterfs-server.service
	touch /var/lib/glusterd/secure-access
	systemctl restart glusterfs-server.service
	mkdir -p /vault/gvol0
'

#install on peer block2
sshpass -p XXX ssh b@10.13.13.202 '
	cd /etc/ssl
	echo "1" | sudo -S ls
	sudo su
	apt update
	apt install sshpass glusterfs-server attr -y
	sshpass -p XXX scp blik@10.13.13.100:~/temp_ssl/glusterfs.ca .
	sshpass -p XXX scp blik@10.13.13.100:~/temp_ssl/glusterfs_2.pem glusterfs.pem
	sshpass -p XXX scp blik@10.13.13.100:~/temp_ssl/glusterfs.key .
	chmod 0600 glusterfs.*
	systemctl start glusterfs-server.service
	systemctl enable glusterfs-server.service
	touch /var/lib/glusterd/secure-access
	systemctl restart glusterfs-server.service
	gluster peer probe 10.13.13.201
	mkdir -p /vault/gvol0
'

rm -rf ~/temp_ssl

#start volume
gluster volume create gvol0 10.13.13.201:/vault/gvol0 10.13.13.202:/vault/gvol0
gluster volume set gvol0 auth.ssl-allow '*'
gluster volume set gvol0 ssl.cipher-list 'HIGH:!SSLv2'
gluster volume set gvol0 client.ssl on
gluster volume set gvol0 server.ssl on
gluster volume start gvol0

exit
