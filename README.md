# Universial AP status for Icinga2

Newest version uses historcal files to track Cisco AP's that dissasociate when they lose their heartbeat to the controller.

About: Check plugin for Nagios/Icinga2 to check the status of AP's by using SNMP OID's.
       This script doesn't have any OID's inorder to make it universal. 

Notes: Change line 26 to change where the AP-status tracker files are stored. 
	   These files keep track of Cisco AP's that may dissassociate for 20 days. 
	   Default is '/usr/share/ap-status/'.
	   Currently it's /usr/share/ap-status/ .

Usage:
check_ap_status.pl -H [host] -C [community] -c [critical threshold] -w [warning threshold] -O [ap ip oid] -o [ap name oid]

Outputs 'Up', 'Down', and 'Total' perfdata.

Cisco 5508 example:
check_ap_status.pl -H 192.168.0.2 -C public -O .1.3.6.1.4.1.14179.2.2.1.1.28 -c 25 -o .1.3.6.1.4.1.14179.2.2.1.1.3 -w 10



The output:
![icingaweb2](http://i.imgur.com/geG1WLg.png)
