# Universial AP status for Icinga2

check_ap_status.pl - A plugin for Icinga2 that uses multiple SNMP OIDs to get the status of a controller's AP's.

Usage: 
check_ap_status.pl -H [controller ip|hostname] -C [community] -c [critical threshold] -w [warning threshold] -O [ap ip oid] -o [ap name oid]

Cisco 5508 example:
check_ap_status.pl -H 192.168.0.2 -C public -O .1.3.6.1.4.1.14179.2.2.1.1.28 -c 25 -o .1.3.6.1.4.1.14179.2.2.1.1.3 -w 10

The output:
![icingaweb2](http://i.imgur.com/geG1WLg.png)
