#!/bin/bash

# remove prelink
prelink -ua
apt remove prelink
apt purge prelink

#antivirus
sudo apt install rkhunter clamav -y
sudo rkhunter --update
sudo rkhunter --propupd
sed -i 's/APT_AUTOGEN=\"false\"/APT_AUTOGEN=\"yes\"/g' /etc/default/rkhunter
sed -i 's/^CRON_DAILY_RUN=.*/CRON_DAILY_RUN=\"yes\"/g' /etc/default/rkhunter

# install aide
apt install aide -y
sed -i 's/^Checksums =.*/Checksums = sha512/' /etc/aide/aide.conf
aideinit --yes
cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
echo -ne "[Unit]\nDescription=Aide Check\n\n[Service]\nType=simple\nExecStart=/usr/bin/aide.wrapper --check\n\n[Install]\nWantedBy=multi-user.target\n" > /etc/systemd/system/aidecheck.service
echo -ne "[Unit]\nDescription=Aide check every day at midnight\n\n[Timer]\nOnCalendar=*-*-* 00:00:00\nUnit=aidecheck.service\n\n[Install]\nWantedBy=multi-user.target\n" > /etc/systemd/system/aidecheck.timer
chmod 0644 /etc/systemd/system/aidecheck.*
systemctl reenable aidecheck.timer
systemctl start aidecheck.timer
systemctl daemon-reload
systemctl status aidecheck.timer --no-pager

#final check for auditd rules
find / -xdev \( -perm -4000 -o -perm -2000 \) -type f | awk '{print "-a always,exit -F path=" $1 " -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged" }' >> /etc/audit/audit.rules
echo "-e 2" >> /etc/audit/audit.rules
systemctl reload auditd

#apparmor
apt install apparmor apparmor-utils -y
sed -i 's/selinux=0//g' /etc/default/grub
sed -i 's/apparmor=0/apparmor=1/g' /etc/default/grub
sed -i 's/enforcing=0/enforcing=1/g' /etc/default/grub
update-grub
find /etc/apparmor.d/ -maxdepth 1 -type f -exec aa-enforce {} \;

exit 0
