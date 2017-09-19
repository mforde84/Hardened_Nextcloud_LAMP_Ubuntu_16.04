#!/bin/bash

#create own partition
systemctl stop mysql
mkdir /mysql_data_dir
rsync -av /var/lib/mysql /mysql_data_dir

#harden configuration
echo "log-bin = /var/log/mysql/mariadb-bin
log-bin-index = /var/log/mysql/mariadb-bin.index
binlog_format = mixed
local-infile=0
skip-grant-tables=FALSE
skip_symbolic_links=YES
secure_file_priv=/etc/mysql
log-error=/var/log/mysql/log_error
log-warnings=2
log-raw=OFF
secure_auth=ON
general_log = 1
general_log_file = /var/log/mysql/mysql_query
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql_slow
long_query_time = 2
" | sudo tee -a  /etc/mysql/mariadb.conf.d/50-server.cnf
echo "[mysqld]
datadir=/mysql_data_dir
local-infile=0
skip-grant-tables=FALSE
skip_symbolic_links=YES
secure_file_priv=/etc/mysql
log-error=/var/log/mysql/log_error.log
log-warnings=2
log-raw=OFF
secure_auth=ON
general_log=1
general_log_file = /var/log/mysql/mysql_query.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql_slow.log
long_query_time = 2
" >> /etc/mysql/my.cnf
systemctl restart mysql
mysql << EOF 
SET sql_mode = 'STRICT_ALL_TABLES';
EOF

#alter filepermissions
chmod 700 /mysql_data_dir
chown mysql:mysql /mysql_data_dir
chmod 775 /usr/lib/mysql/plugin/
chown mysql:mysql /usr/lib/mysql/plugin/

#remove history files
rm -rf /root/.mysql_history;
rm -rf /home/blik/.mysql_history;
ln -s /dev/null /root/.mysql_history;
ln -s /dev/null /home/blik/.mysql_history;

exit



