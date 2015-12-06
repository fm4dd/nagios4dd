#!/usr/bin/perl
###################################################################
#	check_nagiostats.pl - check nagios performance data
#
#	License Information:
#	This program is free software; you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation; either version 2 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	To get a copy of the GNU General Public License, write to the Free
#	Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
####################################################################

use strict;
use lib "/srv/app/nagios/libexec";
use utils qw(%ERRORS);
use Getopt::Long;
use File::Basename;

####################################################################
# var declaration

my $version="20150709";
my $file="/srv/app/nagios/var/status.dat";
my $help;
my $verbose=0;
my $value;
my $warning;
my $critical;
my $service_latency;
my $host_latency;
my $max_host_latency;
my $min_host_latency;
my $avg_host_latency;
my $hostcount;
my $servicecount;
my $text;
my $perfdat;
my $unit="sec";

###################################################################
# functions
#

sub check_s_latency(){
  my ($min_service_name, $max_service_name, $line, $value1, $sum,
      $max_service_latency, $min_service_latency, $avg_service_latency,
      @values, $long_service_output);
  my $i=0;

  open (FILE, $file) or die $!; $/ = "";

  foreach $line (<FILE>){
    if ($line =~ /servicestatus/){
      @values=split(/=/, $line);
      foreach $value(@values){
        if($value=~/check_latency/){
          ($value,$value1)=split(/\n/, @values[13]);

          if(!$max_service_latency){ $max_service_latency=$value; }
          if(!$min_service_latency){ $min_service_latency=$value; }
          if(!$avg_service_latency){ $avg_service_latency=$value; }
          # catch max time of latency:
          if($max_service_latency<$value){
            $max_service_latency=$value;
           ($max_service_name, $value1)=split(/\n/, @values[2]);

            if($verbose){
              print "max_service_latency: $max_service_latency\n";
              print "max_service_name: $max_service_name\n";
            }
          }
          # catch min time of latency:
          if($min_service_latency>$value){
            $min_service_latency=$value;
            ($min_service_name, $value1)=split(/\n/, @values[2]);

            if($verbose){
              print "min_service_latency: $min_service_latency\n";
              print "min_service_name: $min_service_name\n";
            }
          }
          # calculate avg time of latency:
          $sum+=$value;
          $i++;
        }
      }
    }
  }

  close (FILE);
  $avg_service_latency=($sum/$i);

  # filling vars for print
  $avg_service_latency=sprintf"%.3f", $avg_service_latency;
  $text=("max latency: $max_service_name=$max_service_latency\navg latency: $avg_service_latency\nmin latency: $min_service_name=$min_service_latency");
  $perfdat=("max=${max_service_latency}s;$warning;$critical avg=${avg_service_latency}s;$warning;$critical; min=${min_service_latency}s;$warning;$critical");
  $value=$max_service_latency;
}

sub check_h_latency(){
  my ($line, $value1, $sum, $max_host_name, $min_host_name,
      $max_host_latency, $min_host_latency, $avg_host_latency, @values);
  my $i=1;

  open (FILE, $file) or die $!;
  $/ = "";

  foreach $line(<FILE>){
    if($line=~/hoststatus/){
      @values=split(/=/, $line);
      foreach $value(@values){
        if($value=~/check_latency/){
          ($value,$value1)=split(/\n/, @values[12]);
          if(!$max_host_latency){ $max_host_latency=$value; }
          if(!$min_host_latency){ $min_host_latency=$value; }
          if(!$avg_host_latency){ $avg_host_latency=$value; }
          # catch max time of latency:
          if($max_host_latency<$value){
            $max_host_latency=$value;
           ($max_host_name, $value1)=split(/\n/, @values[1]);

            if($verbose){
              print "max_host_latency: $max_host_latency\n";
            }
          }
          # catch min time of latency:
          if($min_host_latency>$value){
            $min_host_latency=$value;
           ($min_host_name, $value1)=split(/\n/, @values[1]);

            if($verbose){
              print "min_host_latency: $min_host_latency\n";
            }
          }
          # calculate avg time of latency:
	  $sum+=$value;
          $i++;
        }
      }
    }
  }

  close (FILE);
  $avg_host_latency=($sum/$i);

  # filling vars for print
  $avg_host_latency=sprintf"%.3f", $avg_host_latency;
  $text=("max latency: $max_host_name=$max_host_latency\navg latency: $avg_host_latency\nmin latency: $min_host_name=$min_host_latency");
  $perfdat=("max=${max_host_latency}s;$warning;$critical avg=${avg_host_latency}s;$warning;$critical min=${min_host_latency}s;$warning;$critical");
  $value=$max_host_latency;
}

sub check_h_count(){
  my $line;
  my $counter_host_checks=0;

  open (FILE, $file) or die $!;
  $/ = "";

  foreach $line(<FILE>){
    if($line=~/hoststatus/){
      $counter_host_checks++;
    }
  }
  close (FILE);

  # filling vars for print
  $text=("$counter_host_checks Nagios host checks");
  $perfdat=("count=$counter_host_checks");
  $value=$counter_host_checks;
}

sub check_s_count(){
  my $line;
  my $counter_service_checks=0;

  open (FILE, $file) or die $!;
  $/ = "";

  foreach $line(<FILE>){
    if($line=~/servicestatus/){
      $counter_service_checks++;
    }
  }
  close (FILE);

  # filling vars for print
  $text=("$counter_service_checks Nagios service checks");
  $perfdat=("count=$counter_service_checks");
  $value=$counter_service_checks;
}

sub print_help(){
  print "\n\nVersion: $version\n";
  print "Autor: Daniel Bierstedt [daniel.bierstedt\@gmail.com]\n\n";
  print "Update: Frank Migge, [support\@frank4dd.com]\n\n";
  print "This plugin checks nagios performance data by parsing the nagios\n";
  print "status.dat file, e.g. in /usr/local/nagios/var/status.dat.\n";
  print "\n\n";
  print "Usage: check_nagiostats.pl [-f <path_to_status.dat>] -s|-o|-p|-r -w <warn> -c <crit>\n\n";
  print "options:\n";
  print "-s|--service_latency     check service with max latency\n";
  print "-o|--host_latency        check host with max latency\n";
  print "-w|--warning\n";
  print "-c|--critical\n";
  print "-f|--file                provide an alternate file path to status.dat\n";
  print "-p|--hostcount           check number of monitored hosts\n";
  print "-r|--servicecount        check number of monitored services\n";
  print "-h|--help:               print help\n";
  print "-v|--verbose:            print verbose (testing) output\n";
  print "Examples:\n";
  print "To check host latency: check_nagiostats.pl -o -w 200 -c 500\n";
  print "To check service latency: check_nagiostats.pl -s -w 200 -c 500\n";
  print "Attention: warning and critical always checks max_latency.\n";
  print "To count checked services: check_nagiostats.pl --servicecount -w 2000 -c 2500\n";
  print "To count checked hosts: check_nagiostats.pl --hostcount -w 900 -c 1000\n";
}

####################################################################
# main program
#

# get commandline options
GetOptions(
  "h"=>\$help,
  "help"=>\$help,
  "f:s"=>\$file,
  "file:s"=>\$file,
  "s"=>\$service_latency,
  "service_latency"=>\$service_latency,
  "o"=>\$host_latency,
  "host_latency"=>\$host_latency,
  "p"=>\$hostcount,
  "hostcount"=>\$hostcount,
  "r"=>\$servicecount,
  "servicecount"=>\$servicecount,
  "w:i"=>\$warning,
  "warning:i"=>\$warning,
  "c:i"=>\$critical,
  "critical:i"=>\$critical,
  "v"=>\$verbose,
  "verbose"=>\$verbose);

if($verbose > 0){
  print basename($0) ." using status.dat at location: $file\n";
}

if ($service_latency && $warning && $critical){ check_s_latency(); }
elsif ($host_latency && $warning && $critical){ check_h_latency(); }
elsif ($hostcount && $warning && $critical){ check_h_count(); }
elsif ($servicecount){ check_s_count(); }
else{ print_help(); }

####################################################################
# Final output

if($value){
  if($value>=$critical){
    print "CRITICAL: $text (>=$critical)|$perfdat\n";
    exit $ERRORS{'CRITICAL'};
  }
  elsif($value>=$warning){
    print "WARNING: $text (>=$warning)|$perfdat\n";
    exit $ERRORS{'WARNING'};
  }
  elsif($value<$warning){
    print "OK: $text|$perfdat\n";
    exit $ERRORS{'OK'};
  }
  else{
    print "UNKNOWN: Error in execution\n";
    exit $ERRORS{'UNKNOWN'};
  }
}
