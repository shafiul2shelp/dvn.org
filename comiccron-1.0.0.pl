#!/usr/bin/perl
#Copyright (c) 2007, Zane C. Bowers
#All rights reserved.
#
#Redistribution and use in source and binary forms, with or without modification,
#are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
#ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
#WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
#INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
#BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
#DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
#LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
#THE POSSIBILITY OF SUCH DAMAGE.

use DateTime::Event::Cron;
use DateTime::Duration;
use DateTime::Format::Strptime;
use strict;
use warnings;
use Getopt::Std;

$Getopt::Std::STANDARD_HELP_VERSION = 1;

# within_interval is copied from http://datetime.perl.org/index.cgi?FAQSampleCalculations
sub within_interval {
    my ($dt1, $dt2, $interval) = @_;

    # Make sure $dt1 is less than $dt2
    ($dt1, $dt2) = ($dt2, $dt1) if $dt1 > $dt2;

    # If the older date is more recent than the newer date once we
    # subtract the interval then the dates are closer than the
    # interval
    if ($dt2 - $interval < $dt1) {
        return 1;
    } else {
        return 0;
    };
};

sub main::VERSION_MESSAGE{
	print "comiccron v. 1.0.0\n";
};

sub main::HELP_MESSAGE{
	
	print "\n-f <file>	Runs the specified file. This is a required option.\n";

	exit 1;
};

#takes a cronline and runs it if it is with within a minute and 15 seconds of last and next
sub run_cron_line{
	my $cronline = $_[0];
	my $now=DateTime->now;#get the time

	my $dtc = DateTime::Event::Cron->new_from_cron($cronline);
	my $next_datetime_string = $dtc->next;
	my $last_datetime_string = $dtc->previous;

	#takes the strings and make DateTime objects out of them.
	my $time_string_parse= new DateTime::Format::Strptime(pattern=>'%FT%T');
	my $dt_last=$time_string_parse->parse_datetime($last_datetime_string);
	my $dt_next=$time_string_parse->parse_datetime($next_datetime_string);

	#check to make sure last or next is within a minute and 15 seconds of now.
	my $interval = DateTime::Duration->new(minutes => 1, seconds => 15);

	#if it falls within 1 minute and 15 secons of now, it runs it
	if (within_interval($dt_last, $now, $interval) || within_interval($dt_next, $now, $interval)){		
		system($dtc->command());
	};
};

#get options it was started with
my %opts=();
getopts('f:', \%opts);

#exits if no file is specified
if (!defined($opts{f})){
	print "No file specified.\n";
	exit 1;
};

#read the cron file
open("cron_file", $opts{f})||die("Could not open ".$opts{f}."!"."\n");
my @cron_lines=<cron_file>;
close("cron_file");

#remove comments
@cron_lines = grep(!/^#/, @cron_lines);

my $cron_int=0; #used for intering through @cron_lines
while($cron_lines[$cron_int]){
	chomp($cron_lines[$cron_int]);
	run_cron_line($cron_lines[$cron_int]);
	
	$cron_int++;
};

#-----------------------------------------------------------
# POD documentation section
#-----------------------------------------------------------

=head1 NAME

comiccron - A cron like tool largely aimed at bringing up my web comics in the morning with a single command.

=head1 SYNOPSIS

comiccron -f cronfile

=head1 USAGE

This will act on any cronfile it is pointed at. For it to run the command, the last or next time it will be
will have to be within a minute and 15 seconds. For most usages, you will want to have the hour and minute
set to *. This allows a user to do something how ever many times they want any time during the period it is
active.

After running through every entry in the crontab, it then exits.

You need to use the full path for specifying the command.

=head1 WHY NOT CRON

You can have cron open opera or the like on a specific display by either switch or enviromental options, but it
will always open it. This allows you to open it any time along the point it is active.

=head1 EXAMPLES

Opens up http://somethingpositive.net in opera in a newtab on display localhost:0.1 any day of the week.
	
	* * * * * /usr/local/bin/opera -display localhost:0.1 -newpage http://somethingpositive.net

Open up http://freefall.purrsia.com in opera in a newtab on display :0.1 on Mon, Tue, and Fri.
	
	* * * * 1,3,5 /usr/local/bin/opera -display :0.1 -newpage http://freefall.purrsia.com

=head1 AUTHOR

Copyright (c) 2006, Zame C. Bowers <vvelox@vvelox.net>

All rights reserved.

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
    * Neither the name of the Midwest Connections Inc. nor the names of its
     contributors may be used to endorse or promote products derived from
     this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS` OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=head1 SCRIPT CATEGORIES

Web
	
=head1 OSNAMES
	
any
	
=head1 README
	
comiccron - A cron like tool largely aimed at bringing up my web comics in the morning with a single command.
	
=cut

#-----------------------------------------------------------
# End of POD documentation
#-----------------------------------------------------------
