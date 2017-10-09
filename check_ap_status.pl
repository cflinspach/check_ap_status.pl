#!/usr/bin/perl
# About: Check plugin for icinga2 to check the status of AP's by using SNMP OID's.
#        This script doesn't have any OID's inorder to make it universal. 
#
# Notes: Change line 26 to change where the AP-status tracker file is stored. 
#		 This file keeps track of Cisco AP's that may dissassociate. 
#
#        Tested with Meru and Cisco Controllers.
# Version 1.2
# Author: Casey Flinspach
#         cflinspach@protonmail.com
#
##########################################################################
use strict;
use warnings;
use Net::SNMP;
use Getopt::Long qw(:config no_ignore_case);
# use List::Util qw(first);
use List::MoreUtils qw(pairwise);
use Net::Ping;
use DateTime;

my $ap_tracker_file_dir = '/usr/share/ap-status/';
my $days_to_keep_aps = '20';
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


sub help { print "
About: Check plugin for icinga2 to check the status of AP's by using SNMP OID's.
       This script doesn't have any OID's inorder to make it universal. 

Notes: Change line 26 to change where the AP-status tracker files are stored. 
	   These files keep track of Cisco AP's that may dissassociate for 20 days. 
	   Default is '/usr/share/ap-status/'.
	   Currently it's $ap_tracker_file_dir .

Usage:
check_ap_status.pl -H [host] -C [community] -c [critical threshold] -w [warning threshold] -O [ap ip oid] -o [ap name oid]

";
}


my $host_file = $ap_tracker_file_dir . $hostaddr;

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
my $date = DateTime->today->strftime('%Y-%m-%d');
my $date_to_delete_aps = DateTime->today->subtract(days => $days_to_keep_aps)->strftime('%Y-%m-%d');
my $ping = Net::Ping->new('icmp');
my @ap_stat_array;
foreach(@ap_ip_array) {
        if ($ping->ping($_, 1)) {
                push(@ap_stat_array, "UP");
        } else {
                push(@ap_stat_array, "Down on $date");
        }
}

my $current_ap_total = grep (//, @ap_name_array);
my %current_ap_status;
for (my $i=0; $i<=$current_ap_total-1; $i++) {
	$current_ap_status{$ap_name_array[$i]}=$ap_stat_array[$i];	
}

# If the tracker file doesn't exsist, create it.
unless(-e $host_file) {
    open my $file_create, '>', $host_file;
    close $file_create;
}

open my $tracker_file, '<', $host_file or die "Could not open $host_file: $!";
chomp(my @tracker_file_lines = <$tracker_file>);
close $tracker_file;

# Check the file against results.
my @updated_tracker_file;
foreach (@tracker_file_lines) {
	my @split_tracker_file_lines = split /,/, $_;

	# If a UP result is already in the file, move on.
	if (exists $current_ap_status{$split_tracker_file_lines[0]} && $current_ap_status{$split_tracker_file_lines[0]} =~ 'UP' && $split_tracker_file_lines[1] =~ 'UP') {
		next;	
	}

	# If a the check result has the AP as up, but it's down in the file, it will get added below.
	elsif (exists $current_ap_status{$split_tracker_file_lines[0]} && $current_ap_status{$split_tracker_file_lines[0]} =~ 'UP' && $split_tracker_file_lines[1] =~ 'Down') {
		next;
	}

	# If it's in the file as UP, and not the results, Keep it. 
	elsif (exists $split_tracker_file_lines[0] && $split_tracker_file_lines[1] =~ 'UP') {
		push (@updated_tracker_file, "$split_tracker_file_lines[0],Down on $date");
		next;
	}
	# If it's down in the file and not in the results, delete it if it's older or keep it. 
	elsif ($split_tracker_file_lines[1] =~ 'Down') {
		my @status_date = split / on /, $split_tracker_file_lines[1];
		if ($status_date[1] le $date_to_delete_aps) {
			next;
		}
		else {
			push (@updated_tracker_file, "$split_tracker_file_lines[0],$split_tracker_file_lines[1]");
			next;
			}
	}
}

# Check the results against the file.
foreach my $key (keys %current_ap_status) {
	my $value = $current_ap_status{$key};
	my $ap_file_check = grep (/$key/, @tracker_file_lines);
	# Check if AP hostname is in tracker file. 
	if ($ap_file_check == 1 && $value =~ 'UP') {
	 	# If the result is in the file and still up, keep it in the file.
		push(@updated_tracker_file, "$key,$value");
	}
	# If it's not in the tracker file, add it.
	elsif ($ap_file_check == 0) {
		push(@updated_tracker_file, "$key,UP");
	}
}

open my $updated_tracker_file, '>', $host_file or die "Could not open $host_file: $!";
foreach (@updated_tracker_file) {
	print $updated_tracker_file "$_\n";
	}
close $updated_tracker_file;

my $total_ap_count = grep (//, @updated_tracker_file);
my $up_count = grep (/UP/, @updated_tracker_file);
my $down_count = grep (/Down/, @updated_tracker_file);
my $percent_down = ($down_count/$total_ap_count)*100;
my $percent_up = ($up_count/$total_ap_count)*100;

print "Total AP's: $total_ap_count Total UP: $up_count Total Down: $down_count \n";
foreach (@updated_tracker_file) {
my @results = split /,/, $_;
print "$results[0] = $results[1]\n";
}
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

