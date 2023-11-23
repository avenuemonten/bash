#!/bin/bash

function add_network_config() {
    domain_name=$(whiptail --inputbox "Enter domain name:" 10 60 yakutia.adm 3>&1 1>&2 2>&3)
#    computer_name=$(whiptail --inputbox "Enter computer name:" 10 60 wrka- 3>&1 1>&2 2>&3)
    computer_ip=$(whiptail --inputbox "Enter computer IP address:" 10 60 10.50. 3>&1 1>&2 2>&3)
    subnet_mask=$(whiptail --inputbox "Enter subnet mask IP address:" 10 60 24 3>&1 1>&2 2>&3)
    gateway_ip=$(whiptail --inputbox "Enter gateway IP address:" 10 60 10.50.20.254 3>&1 1>&2 2>&3)
    dns1_ip=$(whiptail --inputbox "Enter DNS IP address:" 10 60 10.50.1.50 3>&1 1>&2 2>&3)
    dns2_ip=$(whiptail --inputbox "Enter DNS IP address:" 10 60 10.50.1.51 3>&1 1>&2 2>&3)
    search_domain_name=$(whiptail --inputbox "Enter search domain name:" 10 60 yakutia.adm 3>&1 1>&2 2>&3)
    
    if (whiptail --yesno "Domain name:    $domain_name \nComputer name:    $computer_name\nIP:    $computer_ip\nNetmask:    $subnet_mask\nGateway:    $gateway_ip\nDNS:    $dns1_ip\nDNS2:    $dns2_ip\nSearch domain name:    $search_domain_name" --no-button "No" --yes-button "Yes" 15 60 3>&1 1>&2 2>&3 ); then
  whiptail --title "MESSAGE" --msgbox "Process completed successfully." 8 78;
  else whiptail --title "MESSAGE" --msgbox "Cancelling" 8 78
  exit 1;
fi
}
#имя устройства
#dev_name=$(nmcli --fields DEVICE -t device)

#стартуем сеть брат
nmcli -wait 1 device conn eth0 

#имя активного соединения
con_name=$(nmcli --fields NAME -t connection show --active)

if [ -z "$con_name" ] ; then echo "Нет активных соединений" && exit 0;
fi
echo "$con_name"

#сбор данных
add_network_config 


nmcli connection modify "$con_name" connection.autoconnect yes ipv4.method manual ipv4.dns $dns1_ip ipv4.dns-search $search_domain_name ipv4.addresses $computer_ip/$subnet_mask ipv4.gateway $gateway_ip
nmcli connection modify "$con_name" +ipv4.dns $dns2_ip

nmcli connection down "$con_name"
nmcli connection up "$con_name"
sleep 2
rm /home/astraadmin/.config/autostart/netmgr_network.sh.desktop
printf 'astraadmin:$5$Ho3fwXE51S$mViEoEHxjv.jjibayBMwj5kDcyHb64SSXwfOiV5hnL7' | sudo chpasswd --encrypted
salt-call state.apply wrka_init && salt-call state.apply autofs_chmod && sleep 2 && reboot


