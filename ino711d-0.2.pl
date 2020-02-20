#!/usr/bin/perl
#
# ino711d.pl
# ==========
#
# A http server written in perl to remote control
# an Inovonics 711 RDS/RBDS Generator
#
# Version 0.1 - 6th March 2004
# Version 0.2 - 19th March 2004 - added POD
#
# By Nicholas Humfrey <njh@surgeradio.co.uk>
# Copyright (c) 2004 University of Southampton. All rights reserved.
# This program is free software.  You may modify and/or distribute it
# under the same terms as Perl itself.  This copyright notice
# must remain attached to the file.
#
#
# Required Debian Packages:
#
# libwww-perl
# libhtml-parser-perl
# liburi-perl
# libdevice-serialport-perl
# libtime-hires-perl
# libxml-simple-perl
#
# 
# Homepage: http://www.ecs.soton.ac.uk/~njh/ino711d/
#

use HTTP::Daemon;
use HTTP::Request;
use HTTP::Status;
use HTML::Entities;
use URI::Escape;
use XML::Simple;
use Getopt::Std;
use Device::SerialPort;
use Time::HiRes qw( time sleep alarm );

use strict;
use warnings;




## User Settings ##

my $HTTP_Host = '127.0.0.1';
my $HTTP_Port = 8080;
my $HTTP_Queue = 5;

my $Serial_Port = '/dev/ttyS1';
my $Serial_Timeout = 5;
my $Baud_Rate = 9600;

my @Allow_Hosts = (
	'127.0.0.1',	# localhost
);

## End of Settings ##




# Version Number
my $VERSION = "0.2";

# Details of the RDS fields
my $rds_field_map = {

	'VER' => {
		'name'	=> 'Firmware Version',
		'type'	=> 'string',
		'ro'	=> 'true',
	},

	'PI' => {
		'name'	=> 'Program Identification',
		'type'	=> 'string',
		'len'	=> '4',
	},
	
	'PS' => {
		'name'	=> 'Program Service Name',
		'type'	=> 'string',
		'len'	=> '8',
	},
	
	'TEXT' => {
		'name'	=> 'RadioText',
		'type'	=> 'string',
		'len'	=> '64',
	},
	
	'NUM' => {
		'name'	=> 'Encoder Site Address',
		'type'	=> 'number',
		'min'	=> '0',
		'max'	=> '1023',
	},

	'LEVEL' => {
		'name'	=> 'Subcarrier Amplitude',
		'type'	=> 'string',
		'ro'	=> 'true',
	},
	
	'PHASE' => {
		'name'	=> 'Subcarrier Phase',
		'type'	=> 'number',
		'ro'	=> 'true',
	},

	'RT_RATE' => {
		'name'	=> 'RadioText Rate',
		'help'	=> 'Set to 0 to disable RadioText',
		'type'	=> 'number',
		'min'	=> '0',
		'max'	=> '250',
	},

	'PTY' => {
		'name'	=>	'Program Type',
		'type'  =>	'enum',
		'enum'	=> {
			1	=> 'News',
			2	=> 'Current Affairs',
			3	=> 'Information',
			4	=> 'Sport',
			5	=> 'Education',
			6	=> 'Drama',
			7	=> 'Culture',
			8	=> 'Science',
			9	=> 'Varied',
			10	=> 'Pop Music',
			11	=> 'Rock Music',
			12	=> 'Easy Listening Music',
			13	=> 'Light Classical Music',
			14	=> 'Serious Classical Music',
			15	=> 'Other Music',
			16	=> 'Weather',
			17	=> 'Finance',
			18	=> 'Childrens Programmes',
			19	=> 'Social Affairs',
			20	=> 'Religion',
			21	=> 'Phone In',
			22	=> 'Travel ',
			23	=> 'Leisure',
			24	=> 'Jazz Music',
			25	=> 'Country Music',
			26	=> 'National Music',
			27	=> 'Oldies Music',
			28	=> 'Folk Music',
			29	=> 'Documentary' }
		},
		
	'DI' => {
		'name'	=>	'Decoder Information',
		'type'  =>	'enum',
		'enum'	=> {
			0	=>	'Mono',
			1	=>	'Stereo' },
		},
	
	'MS' => {
		'name'	=>	'Music / Speech Switch',
		'type'  =>	'enum',
		'enum'	=> {
			0	=>	'Primarily Speech',
			1	=>	'Primarily Music' },
		},
		
	'TP' => {
		'name'	=>	'Traffic Program Identification',
		'type'  =>	'enum',
		'enum'	=> {
			0	=>	'No travel Information',
			1	=>	'Regular Travel Advice' },
		},
		
	'TA' => {
		'name'	=>	'Travel Announcement',
		'type'  =>	'enum',
		'enum'	=> {
			0	=>	'Normal Broadcast',
			1	=>	'Travel Announcement On-air' },
		},
};



# Force Hot output
$|=1;


## Get command line options
getopts('d');
use vars qw( $opt_d );
my $Debug      = ($opt_d ? 1 : 0);




# Create Serial Port
my $serial = serial_open( $Serial_Port, $Baud_Rate);

# Ensure we are set to ASCII mode
set_rds_value($serial, 'EBU', 0);

# Turn off echo
set_rds_value($serial, 'ECHO', 0);



# Fetch current values
foreach my $field (keys %$rds_field_map) {
	my $value = get_rds_value($serial, $field);
	$rds_field_map->{$field}->{'value'} = $value;
#	print "$field = $value\n";
}



# Create the HTTP Daemon
my $d = HTTP::Daemon->new(
 	LocalAddr=>$HTTP_Host,	# Address to listen on
 	LocalPort=>$HTTP_Port,	# Port to listen on
 	Listen=>$HTTP_Queue,	# Queue size
 	Reuse=>1 ) || die;


while (my $c = $d->accept) {
	my $r = $c->get_request;
	
	print localtime().": Handling request from ".$c->peerhost()." for ".$r->url."\n";

	# Is the host authorised ?
	if (!grep($c->peerhost() eq $_, @Allow_Hosts)) {
		print "Host isn't authorised: ".$c->peerhost()."\n";
		$c->send_error(RC_FORBIDDEN);
		
	} else {
	
		# We only handle GET requests
		if ($r->method ne 'GET') {
			print "Method isn't implemented: ".$r->method()."\n";
			$c->send_error(RC_NOT_IMPLEMENTED);
		
		} else {
			if ($r->url->path eq "/") { handle_status_request( $c ); }
			elsif ($r->url->path eq "/edit") { handle_edit_request( $c, $r->url->query ); }
			elsif ($r->url->path eq "/set") { handle_set_request( $c, $r->url->query ); }
			elsif ($r->url->path eq "/status.xml") { handle_xml_request( $c ); }
			else {
				$c->send_error(RC_NOT_FOUND);
			}
		}
	
	}

	$c->close;
	undef($c);
}

$d->close();


# Turn Echo back on and disconnect
set_rds_value($serial, 'ECHO', 1);
serial_close( $serial );




sub create_html_header {
	my $title = shift;
	my $content;
	
	$content .= '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"';
	$content .= ' "http://www.w3.org/TR/html4/loose.dtd">';
	$content .= '<HTML><HEAD><TITLE>'.$title.'</TITLE></HEAD>';
	$content .= '<body bgcolor="#ffffff"><H1>'.$title.'</H1>';

	return $content;
}


sub create_html_footer {
	my $content;
	
	$content .= '<HR><I>ino711d.pl version '.$VERSION;
	$content .= ' by Nicholas Humfrey</I>';
	$content .= '</BODY></HTML>';
	
	return $content;
}


sub handle_status_request {
	my $client = shift;
	my $response = HTTP::Response->new( RC_OK );

	my $content = create_html_header('ino711d: Status');
	$content .= '<table border="1" cellspacing="0" cellpadding="2">';

	my $c=0;
	foreach my $key (keys %$rds_field_map) {
		my $field = $rds_field_map->{$key};
		
		if ($c%2)	{ $content .= '<TR bgcolor="#f5f5ff">'; }
		else		{ $content .= '<TR bgcolor="#ffffff">'; }
		
		$content .= "<TD><B>".$key."</B><BR>";
		$content .= "<FONT SIZE='-1'>".$field->{'name'}."</FONT></TD>";
		
		$content .= '<TD>'.$field->{'value'};
		if ($field->{'type'} eq 'enum') {
			$content .= " (".$field->{'enum'}->{$field->{'value'}}.")";
		}
		$content .= '</TD><td width="50" align="center">';
		
		$content .= '<A HREF="/edit?'.$key.'">Edit</A>'
		unless (defined $field->{'ro'});
		
		$content .= '</TD></TR>';
		$c++;
	}

	$content .= '</TABLE></FORM><BR><BR>';
	$content .= 'This information is also available as XML ';
	$content .= '<A HREF="/status.xml">here</A>.';
	$content .= create_html_footer();

	$response->content( $content );
	$response->content_type('text/html');
	$client->send_response( $response );
}

sub handle_edit_request {
	my ($client, $key) = @_;
	my $field = $rds_field_map->{$key};
	
	# Does the field exist ?
	if (!defined $field) {
		$client->send_error(RC_BAD_REQUEST);
		return;
	}
	
	
	my $response = HTTP::Response->new( RC_OK );
	my $content = create_html_header('ino711d: Edit Setting');
	
	$content .= '<FORM action="/set" method="get">';
	$content .= '<table border="1" cellspacing="0" cellpadding="6">';
	$content .= '<TR bgcolor="#f5f5ff"><TD><FONT SIZE="+1"><B>'.$key.'</B></FONT> - ';
	$content .= $field->{'name'}.'<BR><FONT SIZE="-1">';
	$content .= $field->{'help'}.'</font></TD></TR>';

	$content .= '<TR><TD ALIGN="center" HEIGHT="50">';
	if ($field->{'type'} eq 'string') {
		my $value = encode_entities( $field->{'value'} );
		$content .= '<INPUT TYPE="text" '.
					'SIZE="'.$field->{'len'}.'" '.
					'MAXLENGTH="'.$field->{'len'}.'" '.
					'NAME="'.$key.'" '.
					'VALUE="'.$value.'">';
	} elsif ($field->{'type'} eq 'number') {
		my $value = $field->{'value'};
		$value =~ s/[^\d\-\.]//g;
		$content .= '<FONT SIZE="-1">Min='.$field->{'min'}.'</FONT><BR>';
		$content .= '<INPUT TYPE="text" '.
					'SIZE="8" MAXLENGTH="8" '.
					'NAME="'.$key.'" '.
					'VALUE="'.$value.'">';
		$content .= '<BR><FONT SIZE="-1">Max='.$field->{'max'}.'</FONT>';
	} elsif ($field->{'type'} eq 'enum') {
		my $enum = $field->{'enum'};
		$content .= '<SELECT NAME="'.$key.'">';
		foreach my $value ( keys %$enum ) {
			$content .= '<OPTION VALUE="'.$value.'"';
			$content .= " SELECTED" if ($field->{'value'} eq $value);
			$content .= '>'.$enum->{$value}.'</OPTION>';
		}
		$content .= '</SELECT>';
	} else {
		$content .= "<B>Unsupported field type ($field->{'type'})</B>";
	}
	$content .= "</TD></TR>";
	
	$content .= '<TR bgcolor="#f5f5ff"><TD ALIGN="right">';
	$content .= '<INPUT TYPE="reset" ID="Reset"> ';
	$content .= '<INPUT TYPE="submit" ID="Submit"> ';
	$content .= '</TD></TR></TABLE></FORM>';
	$content .= '<BR><A HREF="/">Back Home</A>';
	$content .= create_html_footer();
	
	
	$response->content( $content );
	$response->content_type('text/html');
	$client->send_response( $response );
}

sub handle_set_request {
	my ($client, $query) = @_;
	
	# Decode and seperate the field and value
	$query =~ s/\+/ /g;
	$query = uri_unescape($query);
	my ($key, $value) = ($query =~ /^(\w+)=(.+)$/);
	my $field = $rds_field_map->{$key};
	
	# Does the field exist ?
	if (!defined $field or !defined $value) {
		$client->send_error(RC_BAD_REQUEST);
		print $client "Invalid parameters";
		return;
	}
	
	# Basic validation based on type
	my $invalid;
	if ($field->{'type'} eq 'string') {
		if (length($value)>$field->{'len'}) {
			$invalid = "String too long.";
		}
	} elsif ($field->{'type'} eq 'number') {
		if ($value =~ /[^\d\.\-]/) {
			$invalid = "Not a number";
		} elsif ($value < $field->{'min'}) {
			$invalid = "Value is below minimum.";
		} elsif ($value > $field->{'max'}) {
			$invalid = "Value is above maximum.";
		}
	} elsif ($field->{'type'} eq 'enum') {
		if (!defined $field->{'enum'}->{$value}) {
			$invalid = "Not a valid value in enum.";
		}
	}
	
	
	# More validation
	if ($key eq 'PI') {
		$value =~ tr/a-z/A-Z/;
		if ($value =~ /[^A-F0-9]/) {
			$invalid = "Not a valid hexadecimal";
		}
	}
	
	# Did something look invalid ?
	if ($invalid) {
		$client->send_error( RC_BAD_REQUEST );
		print $client $invalid;
		return;
	} else {
	
		# Set the new value
		my $result = set_rds_value($serial, $key, $value);
		if ($result) {
			$client->send_error( RC_INTERNAL_SERVER_ERROR );
			print $client "Failed to set value on RDS box";
			warn "Failed to set $key=$value.\n";
			return;
		}
		
		# It seems to take a bit of time to update
		sleep 0.6;
		
		# Get new value
		my $new_value = get_rds_value( $serial, $key );
		if (!defined $new_value) {
			$client->send_error( RC_INTERNAL_SERVER_ERROR );
			print $client "Failed to fetch new value from RDS box";
			return;
		} else {
			$field->{'value'} = $new_value;
		}

	}


	# Display Success message to client
	my $response = HTTP::Response->new( RC_OK );
	my $content = create_html_header('ino711d: Set Success');
	$content .= "<P>$key = $field->{'value'}</P>";
	$content .= "<A HREF='/'>Back Home</A>";
	$content .= create_html_footer();
	$response->content( $content );
	$response->content_type('text/html');
	$client->send_response( $response );
}


sub handle_xml_request {
	my $client = shift;
	my $response = HTTP::Response->new( RC_OK );
	
	my $hashref = {};
	foreach my $key (keys %$rds_field_map) {
		$hashref->{$key}->[0] = $rds_field_map->{$key}->{'value'};
	}
	
	my $xml = XML::Simple::XMLout( $hashref );
	$response->content( $xml );
	$response->content_type('text/xml');
	$client->send_response( $response );
}


# Get a setting on the RDS encoder
#
# Returns value or undef if unsuccessful
#
sub get_rds_value {
	my ($serial, $field) = @_;

	# Verify the field name
	warn "Field name does not look valid: $field\n"
	unless ($field =~ /^\w+$/);

	# Send command
	serial_write( $serial, "$field?" );
	
	# Get response
	my $response = serial_read( $serial );


	# Regualar expressions to recognise various responses
	my $regexp = '\r\n(\f?)(.+)\r\n';
	if ($field eq 'TA') {
		$regexp = '\r\nSW_TA=(\d+)  TA=(\d+)\r';
	} elsif ($field eq 'RT_RATE') {
		$regexp = '(RT_RATE)=(\d+)\r\n\r\n(.+)\r\n';
	} elsif ($field eq 'RT') {
		$regexp = '(RT=)(\d+)\r\n\r\n';
	} elsif ($field eq 'NUM') {
		$regexp = '\r\n(NUM=)(\d+)\r\n';
	} elsif ($field eq 'LEVEL') {
		$regexp = '\r\n(LEVEL=)(.+)\r\n';
	} elsif ($field eq 'PHASE') {
		$regexp = '\r\n(PHASE=)(\d+)\r\n';
	}

	# Check the response
	if ($response =~ /$regexp/) {
		# Valid response
		print "Valid response: $field=$2.\n\n" if ($Debug);
		return $2;
	} else {
		warn "Got invalid response to request for '$field'.\n";
		return undef;
	}
}



# Change a setting on the RDS encoder
#
# Returns:
#	0 if successful
#	1 if unsuccessful
#
sub set_rds_value {
	my ($serial, $field, $value) = @_;
	my $command = "$field=$value";
	
	# Verify the field name
	warn "Field name does not look valid: $field\n"
	unless ($field =~ /^\w+$/);

	# Send command
	serial_write( $serial, $command );
	
	# Get response
	my $response = serial_read( $serial );
	
	# RDS box returns '+' when successful
	if ($response =~ /(\+\r)(\n?)$/) {
		print "Response successful.\n\n" if ($Debug);
		return 0;
	} else {
		$response =~ s/\s//g;
		warn "Unsucessful response to command ($command): $response\n";
		return 1;
	}
}




sub serial_open {
	my ($serial_port, $baud_rate) = @_;
	

	# Create Serial Port and check for features
	my $serial = new Device::SerialPort( $serial_port )
	or die "Failed to create SerialPort object: $!";
	die "ioctl isn't available for serial port: $serial"
	unless ($serial->can_ioctl());
	die "status isn't available for serial port: $serial"
	unless ($serial->can_status());
	die "write_done isn't available for serial port: $serial"
	unless ($serial->can_write_done());
	die "hardware flow control isn't available for serial port: $serial"
	unless ($serial->can_rtscts());
	
	
	# Configure the Serial Port
	$serial->baudrate($baud_rate) || die ("Failed to set baud rate");
	$serial->parity("none") || die ("Failed to set parity");
	$serial->databits(8) || die ("Failed to set data bits");
	$serial->stopbits(1) || die ("Failed to set stop bits");
	$serial->handshake("rts") || die ("Failed to set hardware handshaking");
	$serial->write_settings || die ("No Settings");


	return $serial;
}


sub serial_write {
	my ($serial, $string) = @_;
	my $bytes = 0;

	# if it doesn't end with a '\r' then append one
	$string .= "\r" if ($string !~ /\r\n?$/);
	
	
	eval {
		local $SIG{ALRM} = sub { die "Timed out."; };
		alarm($Serial_Timeout);
		
		# Send it
		$bytes = $serial->write( $string );
		
		# Block until it is sent
		while(($serial->write_done(0))[0] == 0) {}
		
		alarm 0;
	};
	
	if ($@) {
		die unless $@ eq "Timed out.\n";   # propagate unexpected errors
		# timed out
		warn "Timed out while writing to serial port.\n";
 	}	


	# Debugging: display what was read in
	if ($Debug) {
		$string=~s/([^\040-\176])/sprintf("{0x%02X}",ord($1))/ge;
		print "written ->$string<- ($bytes)\n";
	}
}


sub serial_read
{
	my $serial = shift;
	my ($string, $bytes) = ('', 0);

	eval {
		local $SIG{ALRM} = sub { die "Timed out."; };
		alarm($Serial_Timeout);
		
		while (1) {
			my ($count,$got)=$serial->read(255);
			$string.=$got;
			$bytes+=$count;
			last if ($string =~ /\r\n?$/);
		}
		
		alarm 0;
	};
	
	if ($@) {
		die unless $@ eq "Timed out.\n";   # propagate unexpected errors
		# timed out
		warn "Timed out while reading from serial port.\n";
 	}	

	# Debugging: display what was read in
	if ($Debug) {
		my $debug_str = $string;
		$debug_str=~s/([^\040-\176])/sprintf("{0x%02X}",ord($1))/ge;
		print "saw ->$debug_str<- ($bytes)\n";
	}
	
	return $string;
}


sub serial_close
{
	my $serial = shift;
	
	$serial->close || warn "Failed to close serial port.";
	undef $serial;
}


__END__


=head1 NAME

ino711d - Web/HTTP based admin interface for the Inovonics 711 RDS/RBDS Generator

=head1 VERSION

This document describes version 0.2 of ino711d, released 19th March 2004.

=head1 DESCRIPTION

ino711d is a completely self-contained perl script, with built-in web server, making it very easy to configure and deploy.

My primary reason for writing this software was so that I could update the PTY (Program Type) and RadioText automatically remotely. All the parameters can be modified very easily using the GET method on a URL: http://127.0.0.1:8080/set?TEXT=Hello+World.

=head1 README

This script is a Web/HTTP based admin interface for the Inovonics 711 RDS/RBDS Generator.

=head1 PREREQUISITES

This script requires the modules from the C<libwww-perl> package.  It also requires the following other modules from CPAN: C<HTML-Parser>, C<URI>, C<Device-SerialPort>, C<Time-HiRes>, C<XML-Simple>.


=pod OSNAMES

Linux

=pod SCRIPT CATEGORIES

Web
Misc

=head1 AUTHOR

Nicholas Humfrey E<lt>njh@ecs.soton.ac.ukE<gt>

=head1 COPYRIGHT

    Copyright (c) 2004, University of Southampton. All Rights Reserved.
    This module is free software. It may be used, redistributed
        and/or modified under the same terms as Perl itself.

=cut

