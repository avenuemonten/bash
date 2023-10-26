#!/bin/bash

# функция перезагрузки

function reload {
    echo "Необходимо перезагрузить сервер для применения настроек, нажмите y для продолжения:";
    read confirmation;
    if [ $confirmation == "y" ]
    then
        sudo reboot;	
    else
        reload;
    fi
}

# функция монтирования ISO

function mountISO {
    sudo mount /home/astra/Загрузки//brest*.iso /mnt/repo;
    echo "Произведено монтирование:"; 
    mount | grep /iso*;
    sleep 5;
}

    1  # первый этап

    # создание репозитория

    sudo mkdir /mnt/repo;

    echo "Созданы папки репозоториев:";
    ls /mnt/repo;
    sleep 5;

    mountISO;

    # обновление

cat << EOF > /etc/apt/sources.list # внимательно, очищается файл 
deb https://dl.astralinux.ru/astra/frozen/1.7_x86-64/1.7.2/uu/1/repository-base/1.7_x86-64 main contrib non-free
deb file:/mnt/repo/brest contrib main non-free
EOF

    3 ) # третий этап

    mountISO;

     # установка базового СЕРВИСА БРЕСТ
    sudo apt install brestcloud-base

    sudo passwd brestadmin
    

cat << EOF | sudo tee /etc/apache2/sites-enabled/000-default.conf 
<VirtualHost *:80>
        ServerName $floatName.$domain
        Redirect permanent / https://$floatName.$domain/
</VirtualHost>

<VirtualHost *:443>
    ServerName $floatName.$domain
    ServerAdmin webmaster@localhost
    <Directory />
        Options FollowSymLinks
        AllowOverride None
    </Directory>
 
    DocumentRoot /usr/lib/one/sunstone/public

	SSLEngine on
        SSLCertificateFile /etc/apache2/ssl/brest02.crt
        SSLCertificateKeyFile /etc/apache2/ssl/brest02.key
	
 
    <Proxy balancer://unicornservers>
        BalancerMember http://127.0.0.1:9869
    </Proxy>
 
    ProxyPass /brestcloud !
    ProxyPass / balancer://unicornservers/
    ProxyPassReverse / balancer://unicornservers/
    ProxyPreserveHost on
 
    <Proxy *>
        AuthType Kerberos
        KrbAuthRealms BREST.NET
        KrbServiceName HTTP/$floatName.$domain
        Krb5Keytab /etc/apache2/apache2.keytab
        KrbMethodNegotiate on
        KrbMethodK5Passwd on
        KrbSaveCredentials on
        require valid-user
        AllowOverride all
 
        RewriteEngine On
        RewriteCond %{DOCUMENT_ROOT}/%{REQUEST_FILENAME} !-f
        RewriteRule ^/(.*)$ balancer://unicornservers%{REQUEST_URI} [P,QSA,L]
        RewriteCond %{LA-U:REMOTE_USER} (.+)
        RewriteRule . - [E=RU:%1]
        RequestHeader add X-Forwarded_Remote-User %{RU}e
    </Proxy>
 
 
    ScriptAlias /brestcloud/ /usr/lib/one/brestcloud/
    <Directory /usr/lib/one/brestcloud/>
        Options +ExecCGI
        AddHandler cgi-script .cgi
        AuthType Kerberos
        KrbAuthRealms BREST.NET
        KrbServiceName HTTP/$floatName.$domain
        Krb5Keytab /etc/apache2/apache2.keytab
        KrbMethodNegotiate on
        KrbMethodK5Passwd on
        KrbSaveCredentials on
        require valid-user
        AllowOverride all
    </Directory>
 
    ErrorLog \${APACHE_LOG_DIR}/error.log
 
    # Possible values include: debug, info, notice, warn, error, crit,
    # alert, emerg.
    LogLevel warn 
 
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>


<VirtualHost *:80>
        ServerName $hostname.$domain
        Redirect permanent / https://$hostname.$domain/
</VirtualHost>
<VirtualHost _default_:443>


    ServerName $hostname.$domain
    ServerAdmin webmaster@localhost
    <Directory />
        Options FollowSymLinks
        AllowOverride None
    </Directory>
 
    DocumentRoot /usr/lib/one/sunstone/public

	SSLEngine on
        SSLCertificateFile /etc/apache2/ssl/brest.crt
        SSLCertificateKeyFile /etc/apache2/ssl/brest.key
	 
    <Proxy balancer://unicornservers>
        BalancerMember http://127.0.0.1:9869
    </Proxy>
 
    ProxyPass /brestcloud !
    ProxyPass / balancer://unicornservers/
    ProxyPassReverse / balancer://unicornservers/
    ProxyPreserveHost on
 
    <Proxy *>
        AuthType Kerberos
        KrbAuthRealms BREST.NET 
        KrbServiceName HTTP/$hostname.$domain
        Krb5Keytab /etc/apache2/apache2.keytab
        KrbMethodNegotiate on
        KrbMethodK5Passwd on
        KrbSaveCredentials on
        require valid-user
        AllowOverride all
 
        RewriteEngine On
        RewriteCond %{DOCUMENT_ROOT}/%{REQUEST_FILENAME} !-f
        RewriteRule ^/(.*)$ balancer://unicornservers%{REQUEST_URI} [P,QSA,L]
        RewriteCond %{LA-U:REMOTE_USER} (.+)
        RewriteRule . - [E=RU:%1]
        RequestHeader add X-Forwarded_Remote-User %{RU}e
    </Proxy>
 
 
    ScriptAlias /brestcloud/ /usr/lib/one/brestcloud/
    <Directory /usr/lib/one/brestcloud/>
        Options +ExecCGI
        AddHandler cgi-script .cgi
        AuthType Kerberos
        KrbAuthRealms BREST.NET
        KrbServiceName HTTP/$hostname.$domain
        Krb5Keytab /etc/apache2/apache2.keytab
        KrbMethodNegotiate on
        KrbMethodK5Passwd on
        KrbSaveCredentials on
        require valid-user
        AllowOverride all
    </Directory>
 
    ErrorLog \${APACHE_LOG_DIR}/error.log
 
    # Possible values include: debug, info, notice, warn, error, crit,
    # alert, emerg.
    LogLevel warn
 
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

EOF

    # завершение скрипта

    echo "Удалены файлы данных скрипта";
    echo "CODED BY DUOLAN VIINTEG CORP";
    echo "Настройка завершена";

    ;;
    
esac
