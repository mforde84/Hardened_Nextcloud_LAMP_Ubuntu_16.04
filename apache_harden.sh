#!/bin/bash

#mods
a2dismod dav -f
a2dismod dav_fs -f 
a2dismod status -f
a2dismod autoindex -f 
a2dismod userdir -f 
a2dismod info -f 
apt install libapache2-mod-security2 libapache2-mod-apparmor -y
a2enmod rewrite
a2enmod security2
a2enmod reqtimeout
a2enmod apparmor

#lock www-data
passwd -l www-data

#permissions
chown root:root /etc/apache2
chown www-data:root /webroot
chown www-data:root /nextcloud_data
chmod 750 /webroot
chmod 750 /nextcloud_data

#disable cgi content
rm -rf /etc/apache2/conf-*/serve-cgi-bin.conf
rm -rf /cgi-bin/* /usr/lib/cgi-bin/*

############
#write rule for host, edit port configuration
############
#server level apache2.conf
echo -ne "
<IfModule mod_headers.c>
  <IfModule mod_setenvif.c>
    <IfModule mod_fcgid.c>
       SetEnvIfNoCase ^Authorization$ \"(.+)\" XAUTHORIZATION=$1
       RequestHeader set XAuthorization %{XAUTHORIZATION}e env=XAUTHORIZATION
    </IfModule>
    <IfModule mod_proxy_fcgi.c>
       SetEnvIfNoCase Authorization \"(.+)\" HTTP_AUTHORIZATION=$1
    </IfModule>
  </IfModule>

  <IfModule mod_env.c>
    # Add security and privacy related headers
    Header set X-Content-Type-Options \"nosniff\"
    Header set X-XSS-Protection \"1; mode=block\"
    Header set X-Robots-Tag \"none\"
    Header set X-Frame-Options \"SAMEORIGIN\"
    Header set X-Download-Options \"noopen\"
    Header set X-Permitted-Cross-Domain-Policies \"none\"
    SetEnv modHeadersAvailable true
  </IfModule>

  # Add cache control for static resources
  <FilesMatch \"\.(css|js|svg|gif)$\">
    Header set Cache-Control \"max-age=15778463\"
  </FilesMatch>
  
  # Let browsers cache WOFF files for a week
  <FilesMatch \"\.woff$\">
    Header set Cache-Control \"max-age=604800\"
  </FilesMatch>
</IfModule>
<IfModule mod_php5.c>
  php_value upload_max_filesize 511M
  php_value post_max_size 511M
  php_value memory_limit 512M
  php_value mbstring.func_overload 0
  php_value always_populate_raw_post_data -1
  php_value default_charset 'UTF-8'
  php_value output_buffering 0
  <IfModule mod_env.c>
    SetEnv htaccessWorking true
  </IfModule>
</IfModule>
<IfModule mod_php7.c>
  php_value upload_max_filesize 511M
  php_value post_max_size 511M
  php_value memory_limit 512M
  php_value mbstring.func_overload 0
  php_value default_charset 'UTF-8'
  php_value output_buffering 0
  <IfModule mod_env.c>
    SetEnv htaccessWorking false
  </IfModule>
</IfModule>
<IfModule mod_rewrite.c>
  RewriteEngine on
  RewriteRule .* - [env=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
  RewriteRule ^\.well-known/host-meta /public.php?service=host-meta [QSA,L]
  RewriteRule ^\.well-known/host-meta\.json /public.php?service=host-meta-json [QSA,L]
  RewriteRule ^\.well-known/carddav /remote.php/dav/ [R=301,L]
  RewriteRule ^\.well-known/caldav /remote.php/dav/ [R=301,L]
  RewriteRule ^remote/(.*) remote.php [QSA,L]
  RewriteRule ^(?:build|tests|config|lib|3rdparty|templates)/.* - [R=404,L]
  RewriteCond %{REQUEST_URI} !^/.well-known/acme-challenge/.*
  RewriteRule ^(?:\.|autotest|occ|issue|indie|db_|console).* - [R=404,L]
</IfModule>
<IfModule mod_mime.c>
  AddType image/svg+xml svg svgz
  AddEncoding gzip svgz
</IfModule>
<IfModule mod_dir.c>
  DirectoryIndex index.php index.html
</IfModule>
AddDefaultCharset utf-8\n
Options -Indexes\n
<IfModule pagespeed_module>
  ModPagespeed Off
</IfModule>
ErrorDocument 403 //core/templates/403.php
ErrorDocument 404 //core/templates/404.php
TraceEnable off\nRewriteEngine On\nRewriteCond %{THE_REQUEST} \!HTTP/1\.1$\nRewriteRule .* - [F]\n#RewriteCond %{HTTP_HOST} \!^.*\.bounceme\.net [NC]\n#RewriteCond %{REQUEST_URI} \!^/error [NC]\n#RewriteRule ^.(.*) - [L,F]\nServerTokens Prod\nServerSignature Off\nFileETag None\nHeader edit Set-Cookie ^(.*)\$ \$1;HttpOnly;Secure\nHeader set X-XSS-Protection \"1; mode=block\"\nSSLUseStapling On\nSSLStaplingCache \"shmcb:logs/ssl_staple_cache(512000)\nHeader always set Strict-Transport-Security \"max-age=600\"\nLimitRequestline 512\nLimitRequestFields 100\nLimitRequestFieldsize 1024\n$(cat /etc/apache2/apache2.conf)" > /etc/apache2/apache2.conf
sed -i 's/\\!/!/g' /etc/apache2/apache2.conf
sed -i '/#.*Require all granted/d' /etc/apache2/apache2.conf
sed -i 's/Timeout.*/Timeout 10/g' /etc/apache2/apache2.conf
sed -i 's/\\!/!/g' /etc/apache2/apache2.conf
sed -i 's/Listen.*80/Listen 192.168.1.100:80/g' /etc/apache2/ports.conf
sed -i 's/Listen.*443/Listen 192.168.1.100:443/g' /etc/apache2/ports.conf
sed -i 's/KeepAliveTimeout.*/KeepAliveTimeout 15/g' /etc/apache2/apache2.conf
sed -i "s/RequestReadTimeout body=10/RequestReadTimeout body=20/g" /etc/apache2/mods-*/reqtimeout.conf

#directory level apache2.conf
sed -i "s/Require all granted/Require all granted\n\t<LimitExcept GET POST OPTIONS>\n\t\tRequire all denied\n\t<\/LimitExcept>\n\t<FilesMatch \"^\\\.ht\">\n\t\tRequire all denied\n\t<\/FilesMatch>\n/g" /etc/apache2/apache2.conf
sed -i 's/Options.*/Options None/g' /etc/apache2/apache2.conf 

#remove .htaccess
for f in $(find /nextcloud_data -name "*.htaccess"); do
 rm -rf $f
done
for f in $(find /webroot -name "*.htaccess"); do
 rm -rf $f
done

#ssl mod 
sed -i 's/SSLProtocol all -SSLv3/SSLProtocol -ALL +TLSv1.2/g' /etc/apache2/*/*
sed -i 's/#SSLHonorCipherOrder on/SSLHonorCipherOrder on/g' /etc/apache2/*/*
sed -i 's/SSLCipherSuite HIGH:!aNULL/SSLCipherSuite ALL:!EXP:!NULL:!ADH:!LOW:!SSLv2:!SSLv3:!MD5:!RC4/g' /etc/apache2/*/*
sed -i 's/#SSLInsecureRenegotiation on/SSLInsecureRenegotiation off/g' /etc/apache2/*/*
sed -i 's/#SSLCompression on/SSLCompression off/g' /etc/apache2/*/*
sed -i "s/<\/IfModule>/SSLCompression off\nSSLSessionTickets off\n<\/IfModule>\n/g" /etc/apache2/mods-available/ssl.conf
sed -i "s/<\/IfModule>/SSLCompression off\nSSLSessionTickets off\n<\/IfModule>\n/g" /etc/apache2/mods-enabled/ssl.conf

#icons leak
sed -i "/Alias \/icons.*/d" /etc/apache2/mods-*/alias.conf
sed -i "/Alias \/icons.*/d" /etc/apache2/mods-*/alias.conf
sed -i "/<Directory.*/d" /etc/apache2/mods-*/alias.conf
sed -i "/Options Indexes MultiViews FollowSymLinks.*/d" /etc/apache2/mods-*/alias.conf
sed -i "/AllowOverride None.*/d" /etc/apache2/mods-*/alias.conf
sed -i "/Order allow,deny.*/d" /etc/apache2/mods-*/alias.conf
sed -i "/Allow from all.*/d" /etc/apache2/mods-*/alias.conf
sed -i "/<\/Directory>.*/d" /etc/apache2/mods-*/alias.conf
sed -i "/Options FollowSymlinks.*/d" /etc/apache2/mods-*/alias.conf
sed -i "/Require all granted.*/d" /etc/apache2/mods-*/alias.conf

#enforce rules on virtualhost 
sed -i "s/<\/VirtualHost>/RewriteEngine On\nRewriteOptions Inherit\nSSLUseStapling On\nHeader always set Strict-Transport-Security \"max-age=600\"\n<\/VirtualHost>/g" /etc/apache2/sites-*/*.conf

#logging
sed -i 's/LogLevel warn/LogLevel notice core:info/g' /etc/apache2/apache2.conf
sed -i 's/^ErrorLog.*/ErrorLog "syslog:local1"/g' /etc/apache2/apache2.conf
sed -i 's/ %>s %O/ %>s %b/g' /etc/apache2/apache2.conf
echo "CustomLog syslog:local1 combined" >> /etc/apache2/apache2.conf
sed -i 's/daily/weekly/g' /etc/logrotate.d/apache2
sed -i 's/rotate 14/rotate 13/g' /etc/logrotate.d/apache2
sed -i "s/postrotate/postrotate\n\t\t\/bin\/kill -HUP 'cat \/var\/run\/httpd.pid 2>\/dev\/null' 2> \/dev\/null || true/g" /etc/logrotate.d/apache2

#modsecurity2 - owasp crs
cd /etc/apache2
git clone https://github.com/SpiderLabs/owasp-modsecurity-crs/
mv owasp-modsecurity-crs/crs-setup.conf.example owasp-modsecurity-crs/crs-setup.conf
mv owasp-modsecurity-crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf.example owasp-modsecurity-crs/rules/REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf
mv owasp-modsecurity-crs/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf.example owasp-modsecurity-crs/rules/RESPONSE-999-EXCLUSION-RULES-AFTER-CRS.conf
echo -ne "<IfModule security2_module>\n\tInclude /etc/apache2/owasp-modsecurity-crs/crs-setup.conf\n\tInclude /etc/apache2/owasp-modsecurity-crs/rules/*.conf\n</IfModule>\n" >> /etc/apache2/apache2.conf

systemctl restart apache2

#apparmor - is already installed but just in sake
systemctl stop apache2
aa-autodep apache2
aa-complain apache2
systemctl start apache2
########this will take a while
#aa-genprof apache2

#expect -c "set timeout 1
# spawn aa-logprof
# expect \"(A)llow*\"
#  send \"A\""
########
#aa-enforce apache2
#aa-enforce /etc/apparmor.d/usr.sbin.apache2
#systemctl reload apparmor

exit 0
