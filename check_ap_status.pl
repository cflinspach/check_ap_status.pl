#!/usr/bin/perl
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
        "host|H=s" => \$hostaddr,
        "community|C=s" => \$community,
        "crit|c:s" => \$crit,
        "warn|w:s" => \$warn,
        "ap_ip_oid|O=s" => \$ap_ip_oid,
        "ap_name_oid|o=s" => \$ap_name_oid);

my ($session, $error) = Net::SNMP->session(
                        -hostname => "$hostaddr",
                        -community => "$community",
                        -timeout => "30",
                        -version => "2c",
                        -port => "161");

if (!defined($session)) {
        printf("ERROR: %s.\n", $error);
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
        print "OK - $percent_up% UP | Down=$percent_down\n";
        exit 0;
        } elsif ($percent_down >= $warn && $percent_down < $crit ) {
        print "WARNING - $percent_down% DOWN | Down=$percent_down\n";
        exit 1;
        } elsif ($percent_down >= $crit) {
        print "CRITICAL - $percent_down% DOWN | Down=$percent_down\n";
        exit 2;
        } else {
        print "UNKNOWN - $err \n";
        exit 3;
        }

