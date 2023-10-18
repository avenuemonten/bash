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
    sudo mount /home/astra/Загрузки/brest/brest.iso /iso/repo/brest;
    echo "Произведено монтирование:"; 
    mount | grep /iso*;
    sleep 5;
}

# создание файла этапов, ввод или импорт входных данных

if [ ! -e /opt/script_state  ]; then
	sudo touch /opt/script_state;
	echo 1 | sudo tee /opt/script_state;

	echo "Введите IP адрес:";
	read IP;
	echo "Введите имя хоста:";
	read hostname;
	echo "Введите доменное имя:";
	read domain;
    echo "Введите имя администратора сервера:";
    read admin;

	sudo touch /opt/script_data;

cat << EOF | sudo tee /opt/script_data
IP=$IP
hostname=$hostname
domain=$domain
admin=$admin
EOF
else
	source /opt/script_data;
fi

STATE=$( cat /opt/script_state );

case "$STATE" in

    1 ) # первый этап

    # создание репозитория

    sudo mkdir /iso/repo/brest-p;

    echo "Созданы папки репозоториев:";
    ls /iso/repo;
    sleep 5;

    mountISO;

    # обновление

cat << EOF > /etc/apt/sources.list # внимательно, очищается файл 
deb https://dl.astralinux.ru/astra/frozen/1.7_x86-64/1.7.2/uu/1/repository-base/1.7_x86-64 main contrib non-free
deb file:/iso/repo/brest/ brest contrib main non-free
EOF

    echo "Создан sources.list";

    sudo apt update -y &&
    sudo astra-update -A -r -T

    # установка пакетов
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -q -y aldpro-client

    # ввод в домен ALD PRO

    echo "$hostname.$domain" > /etc/hostname;
    echo "$IP     $hostname.$domain     $hostname" >> /etc/hosts;

    # правка resolv.conf

    echo "Введите количество серверов имен:";
    read value;

    echo "search $domain" >> /etc/resolv.conf;

    for (( i = 1; i <= $value; i++ )); 
    do
        echo "Введите IP-адрес $i сервера имен:";
        read IP;
        echo "nameserver $IP" >> /etc/resolv.conf;        
    done

    echo 2 | sudo tee /opt/script_state;
    reload;

    ;;

    2 ) # второй этап

    mountISO;

    # генерация ключей

    #sudo ssh-keygen;

    #sudo astra-freeipa-client;

    echo "Сервер введен в домен ALDPRO";
    sleep 5;

    # повышение уровня целостности администратора

    sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=*/GRUB_CMDLINE_LINUX_DEFAULT="parsec.max_ilev=127 parsec.ccnr_relax=1 quiet net.ifnames=0"/' /etc/default/grub;
    sudo pdpl-user -i 127 $admin;
    sudo update-grub;

    echo "Уровень целостности администратора сервера повышен";
    sleep 5;

    echo 3 | sudo tee /opt/script_state;
    reload;

    ;;

    3 ) # третий этап

    mountISO;

    # установка и настройка служб ПК СВ Брест

    #sudo brestcloud-configure;

    # установка базового СЕРВИСА БРЕСТ
    sudo apt install brestcloud-base

    sudo passwd brestadmin

    # обмен ssh ключами

    #echo "Необходимо обменяться ssh ключами с двумя другими серверами";
    #echo "Введите первое имя хоста:";
    #read hostname1;
    #echo "Введите второе имя хоста:";
    #read hostname2;


    #KEY=$(sudo cat /root/.ssh/id_rsa.pub);
    #sudo ssh $admin@$hostname1 "sudo bash -c \"echo $KEY >> /root/.ssh/authorized_keys\"";
    #sudo ssh $admin@$hostname2 "sudo bash -c \"echo $KEY >> /root/.ssh/authorized_keys\"";

    #echo "Произведен обмен ssh ключами";
    #sleep 5;

    #echo "Введите плавающее имя хоста:";
    #read floatName;
    

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

    rm /opt/script_state;
    rm /opt/script_data;
    echo "Удалены файлы данных скрипта";
    echo "CODED BY DUOLAN VIINTEG CORP";
    echo "Настройка завершена";

    ;;
    
esac
