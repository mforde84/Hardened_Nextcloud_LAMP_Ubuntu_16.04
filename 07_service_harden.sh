#!/bin/bash

# enable time sync
apt install ntp -y
grep "^restrict" /etc/ntp.conf | xargs -n 1 -P 8 -L 1 -iFILES sh -c '
 hits=$(echo FILES | grep -v "default kod nomodify notrap nopeer noquery") 
 sed -i "s/$hits//g" /etc/ntp.conf;
'
LATENCY="50"
SERVERS="4"
APPLY="YES"
CONF="/etc/systemd/timesyncd.conf"
NTPSERVERPOOL="0.ubuntu.pool.ntp.org 1.ubuntu.pool.ntp.org 2.ubuntu.pool.ntp.org 3.ubuntu.pool.ntp.org pool.ntp.org"
SERVERARRAY=()
FALLBACKARRAY=()
TMPCONF=$(mktemp --tmpdir ntpconf.XXXXX)
PONG="ping -c2"
for s in $(dig +noall +answer +nocomments $NTPSERVERPOOL | awk '{print $5}'); do
 if [[ $NUMSERV -ge $SERVERS ]]; then
  break
 fi
 PINGSERV=$($PONG "$s" | grep 'rtt min/avg/max/mdev' | awk -F "/" '{printf "%.0f\n",$6}')
 if [[ $PINGSERV -gt "1" && $PINGSERV -lt "$LATENCY" ]]; then
  OKSERV=$(nslookup "$s"|grep "name = " | awk '{print $4}'|sed 's/.$//')
  if [[ $OKSERV && $NUMSERV -lt $SERVERS && ! (( $(grep "$OKSERV" "$TMPCONF") )) ]]; then
   echo "$OKSERV has latency < $LATENCY"
   SERVERARRAY+=("$OKSERV")
   ((NUMSERV++))
  fi
 fi
done
for l in $NTPSERVERPOOL; do
 if [[ $FALLBACKSERV -le "2" ]]; then
  FALLBACKARRAY+=("$l")
  ((FALLBACKSERV++))
 else
  break
 fi
done
if [[ ${#SERVERARRAY[@]} -le "2" ]]; then
 for s in $(echo "$NTPSERVERPOOL" | awk '{print $(NF-1),$NF}'); do
  SERVERARRAY+=("$s")
 done
fi
if [[ $APPLY = "YES" ]]; then
 cat "$TMPCONF" > "$CONF"
 systemctl restart systemd-timesyncd
 rm "$TMPCONF"
fi

# remove / disable unneeded services
apt remove xserver-xorg* -y
apt purge xserver-xorg* -y
systemctl disable avahi-daemon
systemctl disable cups
systemctl disable isc-dhcp-server
systemctl disable isc-dhcp-server6
systemctl disable slapd
systemctl disable nfs-kernel-server
systemctl disable rpcbind
systemctl disable bind9
systemctl disable vsftpd
systemctl disable dovecot
systemctl disable smbd
systemctl disable squid
systemctl disable snmpd
systemctl disable rsync
systemctl disable nis
apt remove nis -y
apt purge nis -y
apt remove rsh-client rsh-redone-client -y
apt purge rsh-client rsh-redone-client -y
apt remove talk -y
apt purge talk -y
apt remove telnet -y
apt purge telnet -y
apt remove ldap-utils -y
apt purge ldap-utils -y

#mail loopback to local
sed -i 's/inet_interfaces = loopback-only/inet_interfaces = localhost/g' /etc/postfix/main.cf
systemctl restart postfix

#disable apport
sed -i 's/enabled=.*/enabled=0/' /etc/default/apport
systemctl mask apport.service

exit 0
