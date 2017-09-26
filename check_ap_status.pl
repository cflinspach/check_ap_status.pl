#!/usr/bin/perl
# About: Check plugin for icinga2 to check the status of AP's by using SNMP OID's.
#        This script doesn't have any OID's inorder to make it universal 
#        Tested with Meru and Cisco Controllers.
# Version 1.1
# Author: Casey Flinspach
#         cflinspach@protonmail.com
#
##########################################################################
use strict;
use warnings;
use Net::SNMP;
use Getopt::Long qw(:config no_ignore_case);
use List::MoreUtils qw(pairwise);
use Net::Ping;

my $hostaddr = '';
my $community = '';
my $crit = '';
my $warn = '';
my $ap_ip_oid = '';
my $ap_name_oid = '';

GetOptions(
        "help|h-" => \my $help,
        "host|H=s" => \$hostaddr,
        "community|C=s" => \$community,
        "crit|c:s" => \$crit,
        "warn|w:s" => \$warn,
        "ap_ip_oid|O=s" => \$ap_ip_oid,
        "ap_name_oid|o=s" => \$ap_name_oid);
        
if($help) {
        help();
        exit;
}


sub help { print "Usage:\n
check_ap_status.pl -H [host] -C [community] -c [critical threshold] -w [warning threshold] -O [ap ip oid] -o [ap name oid]\n";
}

my ($session, $error) = Net::SNMP->session(
                        -hostname => "$hostaddr",
                        -community => "$community",
                        -timeout => "30",
                        -version => "2c",
                        -port => "161");

if (!defined($session)) {
        printf("ERROR: %s.\n", $error);
        help();
        exit 1;
}

my $ap_ip = $session->get_table( -baseoid => $ap_ip_oid );
my $ap_name = $session->get_table( -baseoid => $ap_name_oid);

if (! defined $ap_ip || ! defined $ap_name) {
    die "Failed to get OID '$ap_ip_oid': " . $session->error;
    $session->close();
}

my @ap_name_array;
foreach my $ap_name_key (sort(keys %$ap_name)) {
        push(@ap_name_array,$ap_name->{$ap_name_key});
}

my @ap_ip_array;
foreach my $ap_ip_key (sort(keys %$ap_ip)) {
        push(@ap_ip_array,$ap_ip->{$ap_ip_key});
}

my $err = $session->error;
if ($err){
        print $err;
        return 1;
}

my $p = Net::Ping->new('icmp');
my @ap_stat_array;
foreach(@ap_ip_array) {
        if ($p->ping($_, 1)) {
                push(@ap_stat_array, "UP");
        } else {
                push(@ap_stat_array, "DOWN");
        }
}
my $total_ap_count = grep (//, @ap_name_array);
my $up_count = grep (/UP/, @ap_stat_array);
my $down_count = grep (/DOWN/, @ap_stat_array);
my $percent_down = ($down_count/$total_ap_count)*100;
my $percent_up = ($up_count/$total_ap_count)*100;

print "Total AP's: $total_ap_count Total UP: $up_count Total Down: $down_count \n";
print pairwise { "$a = $b\n" } @ap_name_array, @ap_stat_array;

if ($percent_down < $warn) {
        print "OK - $percent_up% UP |'Up'=$up_count 'Down'=$down_count 'Total'=$total_ap_count\n";
        exit 0;
        } elsif ($percent_down >= $warn && $percent_down < $crit ) {
        print "WARNING - $percent_down% DOWN |'Up'=$up_count 'Down'=$down_count 'Total'=$total_ap_count\n";
        exit 1;
        } elsif ($percent_down >= $crit) {
        print "CRITICAL - $percent_down% DOWN |'Up'=$up_count 'Down'=$down_count 'Total'=$total_ap_count\n";
        exit 2;
        } else {
        print "UNKNOWN - $err \n";
        exit 3;
        }

