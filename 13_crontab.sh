#!/bin/bash

crontab -l > mycron
#ensure proper mount point flags
echo "@reboot mount -o remount,rw,nosuid,nodev,noexec,relatime /tmp" >> mycron
echo "@reboot mount -o remount,rw,relatime,data=ordered /var" >> mycron
echo "@reboot mount -o remount,rw,nosuid,nodev,noexec,relatime /var/tmp" >> mycron
echo "@reboot mount -o remount,rw,relatime,data=ordered /var/log" >> mycron
echo "@reboot mount -o remount,rw,relatime,data=ordered /var/log/audit" >> mycron
echo "@reboot mount -o remount,rw,nodev,relatime,data=ordered /home" >> mycron
echo "@reboot mount -o remount,rw,nosuid,nodev,noexec,relatime /dev/shm" >> mycron
echo "@reboot sysctl -w net.ipv4.ip_forward=0" >> mycron
echo "@reboot sysctl -w net.ipv4.conf.all.send_redirects=0" >> mycron
echo "@reboot sysctl -w net.ipv4.conf.default.send_redirects=0" >> mycron
echo "@reboot sysctl -w net.ipv4.conf.all.accept_source_route=0" >> mycron
echo "@reboot sysctl -w net.ipv4.conf.default.accept_source_route=0" >> mycron
echo "@reboot sysctl -w net.ipv4.conf.all.accept_redirects=0" >> mycron
echo "@reboot sysctl -w net.ipv4.conf.default.accept_redirects=0" >> mycron
echo "@reboot sysctl -w net.ipv4.conf.all.secure_redirects=0" >> mycron
echo "@reboot sysctl -w net.ipv4.conf.default.secure_redirects=0" >> mycron
echo "@reboot sysctl -w net.ipv4.conf.all.log_martians=1" >> mycron
echo "@reboot sysctl -w net.ipv4.conf.default.log_martians=1" >> mycron
echo "@reboot sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1" >> mycron
echo "@reboot sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1" >> mycron
echo "@reboot sysctl -w net.ipv4.conf.all.rp_filter=1" >> mycron
echo "@reboot sysctl -w net.ipv4.conf.default.rp_filter=1" >> mycron
echo "@reboot sysctl -w net.ipv4.tcp_syncookies=1" >> mycron
echo "@reboot sysctl -w net.ipv4.route.flush=1" >> mycron
echo "@reboot sysctl -w net.ipv6.conf.all.accept_ra=0" >> mycron
echo "@reboot sysctl -w net.ipv6.conf.default.accept_ra=0" >> mycron
echo "@reboot sysctl -w net.ipv6.conf.all.accept_redirects=0" >> mycron
echo "@reboot sysctl -w net.ipv6.conf.default.accept_redirects=0" >> mycron
echo "@reboot sysctl -w net.ipv6.route.flush=1" >> mycron

#update apt on reboot and at 5am everyday
echo "@reboot apt autoremove -y; /usr/bin/apt update; /usr/bin/apt upgrade -o \"Dpkg::Options::=--force-confdef\" -o \"Dpkg::Options::=--force-confold\" -y;" >> mycron
echo "00 5 * * * apt autoremove -y; /usr/bin/apt update; /usr/bin/apt upgrade -o \"Dpkg::Options::=--force-confdef\" -o \"Dpkg::Options::=--force-confold\" -y;" >> mycron

#filesystem check with aide everyday at 12am
echo "00 12 * * * /usr/bin/aide --check" >> mycron

#daily rkhunt and clamav virus check at 2am
echo "00 2 * * * rkhunter --update && rkhunter --propupd && rkhunter -c --enable all --disable none --rwo >> /virus_scans/\"$(date +%Y_%m_%d)\".rkhunt.scan.results.csv" >> mycron
echo "00 2 * * * clamscan -r / | grep FOUND >> /virus_scans/\"\$(date +\%Y_\%m_\%d)\".clam.scan.results.csv" >> mycron

crontab mycron
rm mycron

exit 0
