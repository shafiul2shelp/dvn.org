#!/usr/bin/perl

use strict;
use WebService::30Boxes::API;
use DateTime;
use DateTime::Duration;
use Term::ANSIColor;

my $VERSION = "1.0";

my $usage = "Usage: -[w|d] n -t n\n";

die $usage if scalar(@ARGV) != 4;

my $date_string;
my $date_length;
my $todo_count;

if ($ARGV[0] eq "-w"){
	$date_string = "week";
	$date_length = $ARGV[1];
}
elsif ($ARGV[0] eq "-d"){
	$date_string = "day";
	$date_length = $ARGV[1];
}
else{
	die $usage;
}

if ($ARGV[2] eq "-t"){
	$todo_count = $ARGV[3];
}
else{
	die $usage;
}

#not the only way to get these
chomp (my $auth_token = <STDIN>);
chomp (my $api_key = <STDIN>);

my $from_date = DateTime->now;
my $to_date = DateTime->now;
#create end date
$to_date->add($date_string . "s" => $date_length);

my $boxes = WebService::30Boxes::API->new(api_key => $api_key);

&print_events;
&print_todos;

sub print_events {
	my $events = $boxes->call('events.Get', {authorizedUserToken => $auth_token, start => $from_date->ymd, end => $to_date->ymd});
	if($events->{'success'}){
		print color 'red';
		print "The events for the next $date_length $date_string";
		if ($date_length > 1){
			print "s";
		}
		print ":\n";
		print color 'reset';
        
		my %all_events;
		my $found = 0;
        
		while ($events->nextEventId){
			my $startTime = $events->get_startTime;
			my $endTime = $events->get_endTime;
			my $endDate = $events->get_endDate;
			my $startDate = $events->get_startDate;
			#the data before ### is just for sorting purposes
			my $event = $startTime . " " . $endTime . "###" . "*\t" . $events->get_title;
        
			if ($events->isAllDayEvent){
				$event .= " all day until " . $endDate;
			}
			else{
				$event .= " from " . $startTime;
				$event .= " to " . $endTime;
			}
        
			#if the event spans over multiple days
			if ($startDate ne $endDate &&
				not $events->isAllDayEvent){
				$event .= " on " . $endDate;
			}
        
			my @notes = $events->get_notes;
			my $note = "";
			foreach(@notes){
				$note .= "$_" if $_ ne "";
			}
        
			if ($note ne ""){
				$event .= "\nNotes: $note";
			}
        
			my %repeats = (
				daily => 'days',
				weekly => 'weeks',
				monthly => 'months',
				yearly => 'years'
			);
        
			if ($events->get_repeatType eq 'no'){
				$all_events{$startDate} = [] if not defined $all_events{$startDate};
				push @{$all_events{$startDate}}, $event;
			}
			else{
				#if repeats
				$startDate =~ /(\d{4})-(\d{2})-(\d{2})/;
        
				my $increment_date = DateTime->new(
					year => $1,
					month => $2,
					day => $3
				);
        
				#while not at end date
				while (DateTime->compare($increment_date, $to_date) < 1){
					push @{$all_events{$increment_date->ymd}}, $event;
					$increment_date->add($repeats{$events->get_repeatType} => $events->get_repeatInterval);
				}
			}

			$found = 1;
		}

		print "None!\n" if (0 == $found);

		my @dates = sort keys %all_events;
        
		#print them
		foreach (@dates){
			print color 'green';
			print "$_:\n";
			print color 'reset';
			
			foreach (sort @{$all_events{$_}}){
				s/.+###(.+)/$1/;
				if (/birthday/i){
					print color 'blue';
				}
        
				s/\n/\n\t/g;
				print "$_\n\n";
				print color 'reset';
			}
		}
	}
	else{
		print "An error occured (" . $events->{'error_code'} . ": " .
			$events->{'error_msg'} . ")\n";
	}
}

sub print_todos {
	my $todos = $boxes->call('todos.Get', {authorizedUserToken => $auth_token});

	my $count = 0;
	my %tags;
	print color 'red';
	print "The next " . $todo_count . " todos:\n";
	print color 'reset';
	
	#while there are todos left and while we have displayed under the specified amount
	while ($todos->nextTodoId && $count++ <= $todo_count){
		my @temp = $todos->get_tags;
		foreach (@temp){
			$_ = "none" if $_ eq "";
			$tags{$_} = [] if not defined $tags{$_} and not $todos->isDone;
			#the following will produce duplicate events if a todo has more than one tag
			push @{$tags{$_}}, $todos->get_title unless $todos->isDone;
		}
	}

	#print them
	my $found = 0;
	while (my ($tag, $todo) = each %tags){
		print "\u$tag:\n";
		foreach (@{$todo}){
			print "\t$_\n";
		}
		print "\n";

		$found = 1;
	}

	if (not $found){
		print "None!\n";
	}
}

=head1 NAME

Terminal 30 Boxes

=head1 DESCRIPTION

Uses WebService::30Boxes::API to nicely display events and data on the terminal.

You can use this to display your agenda every time you open the terminal.
Usage: cat /path/to/auth_token /path/to/api_key | perl /path/to/30boxes.pl -w 2 -t 10
This displays the events for the next 2 weeks and the first 10 tasks.
auth_token and api_key both contain only one line with the respective information.

=head1 README

THIS SOFTWARE DOES NOT COME WITH ANY WARRANTY WHATSOEVER. USE AT YOUR OWN RISK.

I wrote this script so that every time I opened a terminal window the 30 Boxes agenda 
and the a number of tasks would be displayed. Please email me at chitoiup@umich.edu with
feature requests and bugs. 
Enjoy!

=head1 PREREQUISITES

This script requires the C<strict> module.  It also requires
C<WebService::30Boxes::API>

=head1 COREQUISITES

CGI
DateTime
DateTime::Duration
Term::ANSIColor

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

Web

=cut

