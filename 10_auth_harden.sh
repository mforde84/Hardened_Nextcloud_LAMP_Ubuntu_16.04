#!/bin/bash

#cron
systemctl enable crond
chown root:root /etc/crontab
chmod og-rwx /etc/crontab
chown root:root /etc/cron.hourly
chmod og-rwx /etc/cron.hourly
chown root:root /etc/cron.daily
chmod og-rwx /etc/cron.daily
chown root:root /etc/cron.weekly
chmod og-rwx /etc/cron.weekly
chown root:root /etc/cron.monthly
chmod og-rwx /etc/cron.monthly
chown root:root /etc/cron.d
chmod og-rwx /etc/cron.d
rm /etc/cron.deny
rm /etc/at.deny
touch /etc/cron.allow
touch /etc/at.allow
chmod og-rwx /etc/cron.allow
chmod og-rwx /etc/at.allow
chown root:root /etc/cron.allow
chown root:root /etc/at.allow

#sshd
chown root:root /etc/ssh/sshd_config
chmod og-rwx /etc/ssh/sshd_config
sed -i 's/X11Forwarding yes/X11Forwarding no/g' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config
sed -i 's/LoginGraceTime 120/LoginGraceTime 60/g' /etc/ssh/sshd_config
echo "MaxAuthTries 4" >> /etc/ssh/sshd_config
echo "PermitUserEnvironment no" >> /etc/ssh/sshd_config
echo "MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com"  >> /etc/ssh/sshd_config
echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config
echo "ClientAliveCountMax 0" >> /etc/ssh/sshd_config
echo "AllowUsers blik" >> /etc/ssh/sshd_config
echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config 
service sshd reload

#system accts are non-login
for user in `awk -F: '($3 < 1000) {print $1 }' /etc/passwd`; do
 if [ $user != "root" ]; then
  usermod -L $user
  if [ $user != "sync" ] && [ $user != "shutdown" ] && [ $user != "halt" ]; then
   usermod -s /usr/sbin/nologin $user
  fi
 fi
done

#root guid 0
usermod -g 0 root

#umask 027
umask 027

#wheel su
echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su
echo "wheel:x:999:root,blik" >>  /etc/group

exit 0
