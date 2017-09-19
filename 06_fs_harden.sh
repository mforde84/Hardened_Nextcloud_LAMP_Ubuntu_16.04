#!/bin/bash

# disable unused filesystems
echo "install cramfs /bin/true" | tee -a /etc/modprobe.d/CIS.conf
echo "install freevxfs /bin/true" | tee -a /etc/modprobe.d/CIS.conf
echo "install jffs2 /bin/true" | tee -a /etc/modprobe.d/CIS.conf
echo "install hfs /bin/true" | tee -a /etc/modprobe.d/CIS.conf
echo "install hfsplus /bin/true" | tee -a /etc/modprobe.d/CIS.conf
echo "install squashfs /bin/true" | tee -a /etc/modprobe.d/CIS.conf
echo "install udf /bin/true" | tee -a /etc/modprobe.d/CIS.conf
echo "install vfat /bin/true" | tee -a /etc/modprobe.d/CIS.conf
echo "install dccp /bin/true" | tee -a /etc/modprobe.d/CIS.conf
echo "install sctp /bin/true" | tee -a /etc/modprobe.d/CIS.conf
echo "install rds /bin/true" | tee -a /etc/modprobe.d/CIS.conf
echo "install tipc /bin/true" | tee -a /etc/modprobe.d/CIS.conf
echo "install bluetooth /bin/true" | tee -a /etc/modprobe.d/CIS.conf
echo "install firewire-core /bin/true" | tee -a /etc/modprobe.d/CIS.conf 
echo "install n_hdlc /bin/true" | tee -a /etc/modprobe.d/CIS.conf 
echo "install net-pf-31 /bin/true" | tee -a /etc/modprobe.d/CIS.conf 
echo "install soundcore /bin/true" | tee -a /etc/modprobe.d/CIS.conf 
echo "install thunderbolt /bin/true" | tee -a /etc/modprobe.d/CIS.conf
echo "install usb-midi /bin/true" | tee -a /etc/modprobe.d/CIS.conf 
echo "install usb-storage /bin/true" | tee -a /etc/modprobe.d/CIS.conf

# modify mount flags
mount -o remount,rw,nosuid,nodev,noexec,relatime /tmp
mount -o remount,rw,relatime,data=ordered /var
mount -o remount,rw,nosuid,nodev,noexec,relatime /var/tmp
mount -o remount,rw,relatime,data=ordered /var/log
mount -o remount,rw,relatime,data=ordered /var/log/audit
mount -o remount,rw,nodev,relatime,data=ordered /home
mount -o remount,rw,nosuid,nodev,noexec,relatime /dev/shm

# tmp.mount - remove from fstab
echo -ne "# /etc/systemd/system/default.target.wants/tmp.mount -> ../tmp.mount\n\n[Unit]\nDescription=Temporary Directory\nDocumentation=man:hier(7)\nBefore=local-fs.target\n\n[Mount]\nWhat=tmpfs\nWhere=/tmp\nType=tmpfs\nOptions=mode=1777,strictatime,nosuid,nodev\n" > /etc/systemd/system/tmp.mount
sed -i '/floppy/d' /etc/fstab
if ! grep -i '/proc' /etc/fstab 2>/dev/null 1>&2; then
 echo 'none /proc proc rw,nosuid,nodev,noexec,relatime,hidepid=2 0 0' >> /etc/fstab
fi
if [ -e /etc/systemd/system/tmp.mount ]; then
 sed -i '/^\/tmp/d' /etc/fstab
 for t in $(mount | grep -e "[[:space:]]/tmp[[:space:]]" -e "[[:space:]]/var/tmp[[:space:]]" | awk '{print $3}'); do
   umount "$t"
 done
 sed -i '/[[:space:]]\/tmp[[:space:]]/d' /etc/fstab
 ln -s /etc/systemd/system/tmp.mount /etc/systemd/system/default.target.wants/tmp.mount
 sed -i 's/Options=.*/Options=mode=1777,strictatime,nodev,nosuid/' /etc/systemd/system/tmp.mount
 cp /etc/systemd/system/tmp.mount /etc/systemd/system/var-tmp.mount
 sed -i 's/\/tmp/\/var\/tmp/g' /etc/systemd/system/var-tmp.mount
 ln -s /etc/systemd/system/var-tmp.mount /etc/systemd/system/default.target.wants/var-tmp.mount
 chmod 0644 /etc/systemd/system/tmp.mount
 chmod 0644 /etc/systemd/system/var-tmp.mount
 systemctl daemon-reload
else
 echo '/etc/systemd/system/tmp.mount was not found.'
fi

#world wide sticky bit
df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -type d -perm -0002 2>/dev/null | chmod a+t

#disable automount
systemctl disable autofs

# update apt
apt update 
apt upgrade -y
apt full-upgrade -y

# secure grub
chown root:root /boot/grub/grub.cfg
chmod og-rwx /boot/grub/grub.cfg
apt install expect -y
expect -c "set timeout 1
 spawn grub-mkpasswd-pbkdf2
 expect \"Enter password:\"
  send \"XXX\r\"
 expect \"Reenter password:\"
  send \"XXX\r\"
 expect eof" | tee grubpasswd;
gpasswd=$(tail -n 1 grubpasswd | sed "s/^.*is.grub/grub/g")
rm -rf grubpasswd
echo -ne "cat <<EOF\nset superusers=\"blik\"\npassword_pbkdf2 blik $gpasswd\nEOF\n" >> /etc/grub.d/00_header
update-grub

# psswd protect root
expect -c "set timeout 1
 spawn passwd root
 expect \"Enter new UNIX password:\"
  send \"XXX\"
 expect \"Retype new UNIX password:\"
  send \"XXX\"
 expect eof"
 
# restrict core dumps
echo "* hard core 0" >> /etc/security/limits.conf
echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
sysctl -w fs.suid_dumpable=0

# aslr
echo "kernel.randomize_va_space = 2" >> /etc/sysctl.conf
sysctl -w kernel.randomize_va_space=2

#any unconfined daemons
ps -eZ | egrep "initrc" | egrep -vw "tr|ps|egrep|bash|awk" | tr ':' ' ' | awk '{print $NF }'

#banners
echo "Authorized uses only. All activity may be monitored and reported." > /etc/issue
echo "Authorized uses only. All activity may be monitored and reported." > /etc/issue.net
chown root:root /etc/issue
chown root:root /etc/issue.net
chmod 644 /etc/issue
chmod 644 /etc/issue.net

#systemd
SYSTEMCONF='/etc/systemd/system.conf'
USERCONF='/etc/systemd/user.conf'
sed -i 's/^#DumpCore=.*/DumpCore=no/' "$SYSTEMCONF"
sed -i 's/^#CrashShell=.*/CrashShell=no/' "$SYSTEMCONF"
sed -i 's/^#DefaultLimitCORE=.*/DefaultLimitCORE=0/' "$SYSTEMCONF"
sed -i 's/^#DefaultLimitNOFILE=.*/DefaultLimitNOFILE=100/' "$SYSTEMCONF"
sed -i 's/^#DefaultLimitNPROC=.*/DefaultLimitNPROC=100/' "$SYSTEMCONF"
sed -i 's/^#DefaultLimitCORE=.*/DefaultLimitCORE=0/' "$USERCONF"
sed -i 's/^#DefaultLimitNOFILE=.*/DefaultLimitNOFILE=100/' "$USERCONF"
sed -i 's/^#DefaultLimitNPROC=.*/DefaultLimitNPROC=100/' "$USERCONF"
systemctl daemon-reload

exit 0 
