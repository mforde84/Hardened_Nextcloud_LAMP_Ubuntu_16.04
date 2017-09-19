#!/bin/bash

#set host / workstation passwords
mkdir .ssh
echo "-----BEGIN RSA PRIVATE KEY-----
-----END RSA PRIVATE KEY-----" > ~/.ssh/workstation.pem
echo "XXX" > ~/.ssh/host_password


#set host password for initial sudo
#update repositories for sshpass & expect install
cat ~/.ssh/host_password | sudo -S apt update -y
sudo apt install python-software-properties software-properties-common zfs sshpass expect -y
threads=6 #$(grep -c ^processor /proc/cpuinfo)

#find peer ip, generate ssh keys, launch install on peer 
export host_root="gluster"
export host_num=${HOSTNAME:(-1)}
export mask=192.168.56.20
if [ "$host_num" -eq "1" ]; then 

 #generate ipaddr strings for peer
 export ipad=$mask"2";
 export host_name=$host_root"2";
	
 #generate rsa for key ssh login
 expect -c "set timeout 10
 spawn ssh-keygen -t rsa
 expect \"Enter file in which to save the key (/home/b/.ssh/id_rsa):\"
  send \"\/home\/$USER\/.ssh\/host_key.rsa\r\"
 expect \"Enter passphrase (empty for no passphrase):\"
  send \"\r\"
 expect \"Enter same passphrase again:\"
  send \"\r\"
 expect eof";
 
 #authorized key on host and peer
 cat ~/.ssh/host_key.rsa.pub > ~/.ssh/authorized_keys;
 sshpass -f ~/.ssh/host_password scp -r -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ~/.ssh b@$ipad:~;
 
 #harden keys
 chmod 0600 ~/.ssh/*
 ssh -i ~/.ssh/host_key.rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $USER@$ipad 'echo "XXX" | sudo -S chmod 0600 ~/.ssh/*;';
 
 #backup key to workstation
 expect -c "set timeout 10
  spawn scp -r -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/workstation.pem /home/$USER/.ssh blik@blikworkstation.hopto.org:~/Desktop/fileserver_ssh_keys/
   expect \"Enter passphrase for key '/home/$USER/.ssh/workstation.pem': \"
    send \"XXX\r\"
   expect eof";
 
 #revoke password authentication
 sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config;
 sudo service ssh restart;
 ssh -i ~/.ssh/host_key.rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $USER@$ipad 'cat ~/.ssh/host_password | sudo -S sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config; sudo service ssh restart';
 
 #copy script to peer, launch install on peer
 scp -i ~/.ssh/host_key.rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no zfs.sh $USER@$ipad:~;
 nohup ssh -i ~/.ssh/host_key.rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $USER@$ipad 'nohup bash zfs.sh &;' &
 
else 
 
 #generate ipaddr strings for peer
 export ipad=$mask"1"; 
 export host_name=$host_root"1";
 
fi

#########################
#########################
#########################
#misc. networking
#########################
#########################
#edit hosts
#echo -ne "10.13.13.201\tgluster1
#10.13.13.202\tgluster2\n" | sudo tee -a /etc/hosts 

#edit interfaces
#echo -ne "
#auto enp0s8
#iface enp0s8 inet static
#address $ipad192
#netmask 255.255.255.0
#network 192.168.56.1
#broadcast 192.168.56.255

#auto enp0s9
#iface enp0s9 inet static
#address $ipad
#netmask 255.255.255.0
#network 10.13.13.1
#broadcast 10.13.13.255" | sudo tee -a /etc/network/interfaces

#bring up interfaces
#sudo ifup enp0s8
#sudo ifup enp0s9
#########################
#########################
#########################

#generate keys for luks
sudo mkdir /luks_head 
for f in $(lsblk | cut -d " " -f 1 | grep "sd[b-z]" | grep -o -w '\w\{1,3\}'); do
 psswd=$(date | md5sum)
 psswd=${psswd:0:24}
 location=/luks_head/"$f"~"$psswd"_key;
 sudo dd if=/dev/urandom of=$location bs=1 count=512
 sudo chmod 0400 $location
 sleep 1s;
done;

#format drives (if needed), encrypt, add key file, automount on boot, backupkey files
#lsblk | cut -d " " -f 1 | grep "sd[b-z]" | grep -o -w '\w\{1,3\}' | xargs -L 1 -n 1 -P "$threads" -iLISTER bash -c '

for listr in $(lsblk | cut -d " " -f 1 | grep "sd[b-z]" | grep -o -w '\w\{1,3\}'); do
 dev=/dev/$listr
 location=$(sudo ls /luks_head/"$listr"*)
 psswd=$(echo $location | sed "s/\/luks_head\///g" | sed "s/\_.*//g" | sed "s/^.*~//g")
 sudo dd if=/dev/zero of=$dev bs=4 count=1
 sudo parted -a optimal -- $dev mklabel gpt unit MB mkpart vpool 1 -1
 echo -n "$psswd" | sudo cryptsetup luksFormat -c aes-xts-plain64 -s 512 -h sha512 $dev"1" -
 echo -n "$psswd" | sudo cryptsetup luksOpen $dev"1" "$listr""1_crypt" -
 echo -n "$psswd" | sudo cryptsetup luksAddKey $dev"1" $location - 
 echo "$listr""1_crypt ""$dev""1"" ""$location"" ""luks" | sudo tee -a /etc/crypttab
 sudo cryptsetup luksHeaderBackup "$dev""1" --header-backup-file /luks_head/luks_"$listr"_header_backup
done

#backup luks keys
sudo expect -c "set timeout 10
  spawn scp -r -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/workstation.pem /luks_head blik@blikworkstation.hopto.org:~/Desktop
   expect \"Enter passphrase for key '/home/b/.ssh/workstation.pem': \"
    send \"XXX\r\"
   expect eof";

#generate zpools: raidz2 11,11
#	ashift 12 - larger
#	ashift 9 - smaller
sudo zpool create -O mountpoint=none -o ashift=12 vpool raidz2 /dev/mapper/sdc1_crypt /dev/mapper/sdd1_crypt /dev/mapper/sde1_crypt /dev/mapper/sdf1_crypt /dev/mapper/sdg1_crypt /dev/mapper/sdh1_crypt /dev/mapper/sdi1_crypt /dev/mapper/sdj1_crypt /dev/mapper/sdk1_crypt /dev/mapper/sdl1_crypt
sudo zpool add -f vpool raidz2 /dev/mapper/sdm1_crypt /dev/mapper/sdn1_crypt /dev/mapper/sdo1_crypt /dev/mapper/sdp1_crypt /dev/mapper/sdq1_crypt /dev/mapper/sdr1_crypt /dev/mapper/sds1_crypt /dev/mapper/sdt1_crypt /dev/mapper/sdu1_crypt /dev/mapper/sdv1_crypt /dev/mapper/sdw1_crypt /dev/mapper/sdx1_crypt

#optimazations for pool, make persistent mount
sudo zfs create -o compression=lz4 vpool/VAULT
sudo zfs set atime=off vpool/VAULT
sudo zfs set mountpoint=/vault vpool/VAULT
sudo zfs mount -a
sudo modprobe zfs zfs_autoimport_disable=0
sudo reboot NOW

exit 0 
