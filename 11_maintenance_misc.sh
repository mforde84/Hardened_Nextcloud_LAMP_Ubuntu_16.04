#!/bin/bash

#passwd permissions
chown root:root /etc/passwd
chmod 644 /etc/passwd
chown root:shadow /etc/shadow
chmod o-rwx,g-wx /etc/shadow
chown root:root /etc/group
chmod 644 /etc/group
chown root:shadow /etc/gshadow
chmod o-rwx,g-rw /etc/gshadow
chown root:root /etc/passwd-
chmod 600 /etc/passwd-
chown root:root /etc/shadow-
chmod 600 /etc/shadow-
chown root:root /etc/group-
chmod 600 /etc/group-
chown root:root /etc/gshadow-
chmod 600 /etc/gshadow-

#no world writable
for f in $(df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -type f -perm -0002); do
 chmod o-w $f
done

for f in $(df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -nouser); do
 rm -rf $f
done

cat /etc/passwd | awk -F: '{ print $1 " " $3 " " $6 }' | while read user uid dir; do
if [ $uid -ge 1000 -a ! -d "$dir" -a $user != "nfsnobody" ]; then
 echo "The home directory ($dir) of user $user does not exist."
 mkdir $dir
 chown -r $user:user $dir
 chmod 750 $dir
fi
done

for dir in `cat /etc/passwd | egrep -v '(root|halt|sync|shutdown)' | awk -F: '($7 != "/usr/sbin/nologin") { print $6 }'`; do
 dirperm=`ls -ld $dir | cut -f1 -d" "`
 if [ `echo $dirperm | cut -c6 ` != "-" ]; then
  chmod 750 $dir
 fi
 if [ `echo $dirperm | cut -c8 ` != "-" ]; then
  chmod 750 $dir
 fi
 if [ `echo $dirperm | cut -c9 ` != "-" ]; then
  chmod 750 $dir
 fi
 if [ `echo $dirperm | cut -c10 ` != "-" ]; then
  chmod 750 $dir
 fi
done

cat /etc/passwd | awk -F: '{ print $1 " " $3 " " $6 }' | while read user uid dir; do
 if [ $uid -ge 1000 -a -d "$dir" -a $user != "nfsnobody" ]; then
  owner=$(stat -L -c "%U" "$dir")
  if [ "$owner" != "$user" ]; then
   chown $user $dir
  fi
 fi
done

for dir in `cat /etc/passwd | egrep -v '(root|sync|halt|shutdown)' | awk -F: '($7 != "/usr/sbin/nologin") { print $6 }'`; do
 for file in $dir/.[A-Za-z0-9]*; do
  if [ ! -h "$file" -a -f "$file" ]; then
   fileperm=`ls -ld $file | cut -f1 -d" "`
   if [ `echo $fileperm | cut -c6 ` != "-" ]; then
    echo "Group Write permission set on file $file"
    chmod 700 $file
   fi
   if [ `echo $fileperm | cut -c9 ` != "-" ]; then
    echo "Other Write permission set on file $file"
    chmod 700 $file
   fi
  fi
 done
done

for dir in `cat /etc/passwd | awk -F: '{ print $6 }'`; do
 if [ ! -h "$dir/.forward" -a -f "$dir/.forward" ]; then
  rm -rf "$dir"/.forward
  echo ".forward file $dir/.forward exists"
 fi
done

for dir in `cat /etc/passwd | awk -F: '{ print $6 }'`; do
 if [ ! -h "$dir/.netrc" -a -f "$dir/.netrc" ]; then
  rm -rf "$dir"/.netrc
  echo ".netrc file $dir/.netrc exists"
 fi
done

for dir in `cat /etc/passwd | egrep -v '(root|sync|halt|shutdown)' | awk -F: '($7 != "/usr/sbin/nologin") { print $6 }'`; do
 for file in $dir/.netrc; do
  if [ ! -h "$file" -a -f "$file" ]; then
   fileperm=`ls -ld $file | cut -f1 -d" "`
   if [ `echo $fileperm | cut -c5 ` != "-" ]; then
    echo "Group Read set on $file"
    chmod 700 $file
   fi
   if [ `echo $fileperm | cut -c6 ` != "-" ]; then
    echo "Group Write set on $file"
    chmod 700 $file
   fi
   if [ `echo $fileperm | cut -c7 ` != "-" ]; then
    echo "Group Execute set on $file"
    chmod 700 $file
   fi
   if [ `echo $fileperm | cut -c8 ` != "-" ]; then
    echo "Other Read set on $file"
    chmod 700 $file
   fi
   if [ `echo $fileperm | cut -c9 ` != "-" ]; then
    echo "Other Write set on $file"
    chmod 700 $file
   fi
   if [ `echo $fileperm | cut -c10 ` != "-" ]; then
    echo "Other Execute set on $file"
    chmod 700 $file
   fi
  fi
 done
done

for dir in `cat /etc/passwd | egrep -v '(root|halt|sync|shutdown)' | awk -F: '($7 != "/usr/sbin/nologin") { print $6 }'`; do
 for file in $dir/.rhosts; do
  if [ ! -h "$file" -a -f "$file" ]; then
   rm -rf "$dir"/.rhost
   echo ".rhosts file in $dir"
  fi
 done
done

for i in $(cut -s -d: -f4 /etc/passwd | sort -u ); do
 grep -q -P "^.*?:[^:]*:$i:" /etc/group
 if [ $? -ne 0 ]; then
  echo "Group $i is referenced by /etc/passwd but does not exist in /etc/group"
 fi
done

cat /etc/passwd | cut -f3 -d":" | sort -n | uniq -c | while read x ; do
 [ -z "${x}" ] && break
 set - $x
 if [ $1 -gt 1 ]; then
  users=`awk -F: '($3 == n) { print $1 }' n=$2 /etc/passwd | xargs`
  echo "Duplicate UID ($2): ${users}"
 fi
done

cat /etc/group | cut -f3 -d":" | sort -n | uniq -c | while read x ; do
 [ -z "${x}" ] && break
 set - $x
 if [ $1 -gt 1 ]; then
  groups=`awk -F: '($3 == n) { print $1 }' n=$2 /etc/group | xargs`
  echo "Duplicate GID ($2): ${groups}"
 fi
done

cat /etc/passwd | cut -f1 -d":" | sort -n | uniq -c | while read x ; do
 [ -z "${x}" ] && break
 set - $x
 if [ $1 -gt 1 ]; then
  uids=`awk -F: '($1 == n) { print $3 }' n=$2 /etc/passwd | xargs`
  echo "Duplicate User Name ($2): ${uids}"
 fi
done

cat /etc/group | cut -f1 -d":" | sort -n | uniq -c | while read x ; do
 [ -z "${x}" ] && break
 set - $x
 if [ $1 -gt 1 ]; then
  gids=`gawk -F: '($1 == n) { print $3 }' n=$2 /etc/group | xargs`
  echo "Duplicate Group Name ($2): ${gids}"
 fi
done

exit 0
