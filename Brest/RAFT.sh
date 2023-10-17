#!/bin/bash

echo "Выберите вариант исполнения скрипта:"
echo "1 - настройка главного фронтального сервера";
echo "2 - добавление ведомых узлов в зону, загрузка базы данных на ведомые узлы, настройка oned.conf ведомых узлов";
echo "Выберите вариант (1 или 2):";
read option;

if [ $option -eq 1 ]; then

    echo "Введите IP адрес настраиваемого сервера:";
    read IP;
    echo "Введите имя хоста настраиваемого сервера:";
    read hostname;
    echo "Введите доменное имя настраиваемого сервера:";
    read domain;

    # создание зоны

    onezone server-add 0 --name $hostname.$domain --rpc http://$IP:2633/RPC2;
    echo "Сервер добавлен в зону:"
    onezone show 0;
    sleep 5;

    # включение RAFT

    echo "Введите имя интерфейса, на котором будет активироваться плавающий адрес:";
    read interface;
    echo "Введите плавающий IP адрес:";
    read IPfloat;
    echo "Введите маску сети:";
    read netmask;

    sudo systemctl stop opennebula;
    sudo systemctl stop unicorn-opennebula;

    echo "Сервисы opennebula и unicorn-opennebula остановлены";

    # замена ID на 0 

    echo "Конфигурация файла oned.conf";

    sudo sed -i 's/SERVER_ID     = -1/SERVER_ID     = 0/g' /etc/one/oned.conf;

    # поиск первой строки, которую нужно заменить; замена блока в том же месте

    position=$( sudo sed -n '/^..Executed when a server transits from follower->leader/=' /etc/one/oned.conf | sort -nr | head -1 ); 

    sudo sed -i '/^..Executed when a server transits from follower->leader/,+10d' /etc/one/oned.conf;

    sudo sed -i "$position a # Executed when a server transits from follower->leader\nRAFT_LEADER_HOOK = [\nCOMMAND = \"raft/vip.sh\",\nARGUMENTS = \"leader $interface $IPfloat/$netmask\"\n]\n# Executed when a server transits from leader->follower\nRAFT_FOLLOWER_HOOK = [\nCOMMAND = \"raft/vip.sh\",\nARGUMENTS = \"follower $interface $IPfloat/$netmask\"\n]\n" /etc/one/oned.conf;
    
    echo "Файл oned.conf сконфигурирован";
    sleep 5;

    echo "Сервисы opennebula и unicorn-opennebula запущены";

    sudo systemctl start opennebula &&
    sudo systemctl start unicorn-opennebula &&

    echo "Информация о зоне:";
    sudo onezone show 0;
    sleep 5;

    # сохранение бд

    /usr/bin/pg_dump --host=127.0.0.1 --port=5432 --username="onedbuser" --password --format=custom --blobs --verbose --file="/opt/leader_db.backup" --dbname="onedb";
    
    echo "База данных сохранена";

    echo "Настройка завершена, можно перейти ко второму этапу";
fi

if [ $option -eq 2 ]; then

    echo "Введите количество добавляемых узлов:";
    read value;
    echo "Введите доменное имя настраиваемого сервера:";
    read domain;

    for (( i = 1; i <= $value; i++ )); 
    do
        echo "Введите имя хоста добавляемого сервера:";
        read hostnameNext;

        recExists=$( sudo onezone show 0 | grep -c $hostnameNext ); # проверка 

        if [ $recExists -eq 0 ]; then

            echo "Введите IP адрес добавляемого сервера:";
            read IP;
            onezone server-add 0 --name $hostnameNext.$domain --rpc http://$IP:2633/RPC2;

            echo "Настройка и копирование базы данных";

            sudo scp /opt/leader_db.backup $hostnameNext.$domain:/var/lib/one/ &&
            sudo ssh $hostnameNext.$domain systemctl stop opennebula;
            sudo ssh $hostnameNext.$domain systemctl stop unicorn-opennebula;
            sudo ssh $hostnameNext.$domain rm -rf /var/lib/one/.one;
            sudo ssh $hostnameNext.$domain rm -rf /var/lib/one/.one;
            sudo scp -r /var/lib/one/.one/ $hostnameNext.$domain:/var/lib/one/ &&
            sudo ssh $hostnameNext.$domain /usr/bin/pg_restore --host 127.0.0.1 --port 5432 --username "onedbuser" --dbname="onedb" --password --verbose --clean "/var/lib/one/leader_db.backup";
            
            echo "База данных перенесена";
            sleep 5;

            echo "Конфигурация файла oned.conf";
            echo "Информация о зоне:";
            onezone show 0;

            echo "Введите ID настраиваемого сервера в зоне:";
            read ID;

            sudo scp /etc/one/oned.conf $hostnameNext.$domain:/etc/one/ &&
            sudo ssh $hostnameNext.$domain sed -i "s/SERVER_ID.....=.0\/SERVER_ID\ \ \ \ \ =\ $ID\/g" /etc/one/oned.conf;

            echo "Файл oned.conf сконфигурирован";
            sleep 5;

            sudo ssh $hostnameNext.$domain systemctl start opennebula;
            sudo ssh $hostnameNext.$domain systemctl start unicorn-opennebula;
            sudo ssh $hostnameNext.$domain systemctl status opennebula;
            sleep 5;
            sudo ssh $hostnameNext.$domain systemctl status unicorn-opennebula;
            sleep 5;

            echo "Сервисы запущены";
            
            echo "Узел добавлен в зону";
            onezone show 0;
        else    
            echo "Узел уже добавлен в зону";
            onezone show 0;
        fi
    done
    echo "Настройка завершена";
    echo "CODED BY DUOLAN VIINTEG CORP.";
fi