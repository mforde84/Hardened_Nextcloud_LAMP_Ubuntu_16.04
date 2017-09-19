#create mount points
sudo mkdir /mnt/home /mnt/var /mnt/log /mnt/audit /mnt/tmp /mnt/vartmp /mnt/mysql

#create filesystems
sudo mkfs.ext4 /dev/mapper/controller--vg-home 
sudo mkfs.ext4 /dev/mapper/controller--vg-var 
sudo mkfs.ext4 /dev/mapper/controller--vg-log
sudo mkfs.ext4 /dev/mapper/controller--vg-audit
sudo mkfs.ext4 /dev/mapper/controller--vg-tmp
sudo mkfs.ext4 /dev/mapper/controller--vg-vartmp
sudo mkfs.ext4 /dev/mapper/controller--vg-mysql

#mount filesystems
sudo mount /dev/mapper/controller--vg-home /mnt/home
sudo mount /dev/mapper/controller--vg-var /mnt/var
sudo mount /dev/mapper/controller--vg-log /mnt/log
sudo mount /dev/mapper/controller--vg-audit /mnt/audit
sudo mount /dev/mapper/controller--vg-tmp /mnt/tmp
sudo mount /dev/mapper/controller--vg-vartmp /mnt/vartmp
sudo mount /dev/mapper/controller--vg-mysql /mnt/mysql

#unencrypt home directory
#create tempuser
sudo su -
adduser tempuser
#set easy password
usermod -aG sudo tempuser
exit

###################
#DO THIS AS ROOT
#copy over associated files in / to new lv
sudo rsync -avh /home/ /mnt/home
sudo rsync -avh /var/ /mnt/var
sudo rsync -avh /var/log/ /mnt/log
sudo rsync -avh /var/log/audit/ /mnt/audit
sudo rsync -avh /tmp/ /mnt/tmp
sudo rsync -avh /var/tmp/ /mnt/vartmp
sudo rsync -avh /var/lib/mysql /mnt/mysql

#unencrypt back home directory
cd /mnt/home/
sudo rm -rf .ecryptfs
cd b
sudo rm -rf .ecryptfs
sudo rm -rf .Privatesudo

#login as tempuser
su tempuser
sudo umount /home/b
sudo rm -rf /home/b

#edit fstab
echo -ne "/dev/mapper/controller--vg-var""\t""/var""\t""ext4""\t""rw,relatime,data=ordered""\t""0""\t""0\n" >> /etc/fstab
echo -ne "/dev/mapper/controller--vg-log""\t""/var/log""\t""ext4""\t""rw,relatime,data=ordered""\t""0""\t""0\n" >> //etc/fstab
echo -ne "/dev/mapper/controller--vg-audit""\t""/var/log/audit""\t""ext4""\t""rw,nosuid,nodev,noexec""\t""0""\t""0\n" >> /etc/fstab
echo -ne "/dev/mapper/controller--vg-tmp""\t""/tmp""\t""ext4""\t""rw,nosuid,nodev,noexec,relatime""\t""0""\t""0\n" >> /etc/fstab
echo -ne "/dev/mapper/controller--vg-vartmp""\t""/var/tmp""\t""ext4""\t""rw,nosuid,nodev,noexec,relatime""\t""0""\t""0\n" >> /etc/fstab
echo -ne "/dev/mapper/controller--vg-home""\t""/home""\t""ext4""\t""rw,nodev,relatime,data=ordered""\t""0""\t""0\n" >> /etc/fstab
echo -ne "/dev/mapper/controller--vg-mysql""\t""/mysql_data_dir""\t""ext4""\t""rw,nodev,relatime,data=ordered""\t""0""\t""0\n" >> /etc/fstab

#remove tempuser and reboot
sudo su -
sudo userdel tempuser
sudo reboot NOW
