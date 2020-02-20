#!/usr/bin/perl
#
# dabepg_bin2xml.pl
# =================
#
# Convert DAB Binary EPG (ETSI TS 102 371)
# to DAB XML EPG (ETSI TS 102 818)
#
# Version 0.3 - 17th June 2005
#
# By Nicholas Humfrey <njh@surgeradio.co.uk>
# Copyright (c) 2005 University of Southampton. All rights reserved.
# This program is free software.  You may modify and/or distribute it
# under the same terms as Perl itself.  This copyright notice
# must remain attached to the file.
#
#
# TODO:
#  - add support for bearer/trigger
#  - when parsing dabids, there isn't a way to express xpad type ?
#
# ChangeLog
#  20050604 - Added output file parameter
#  20050605 - Corrected unpack little endian error
#  20050617 - Added code to insert bearer tag for default DABID
#
# Homepage: http://www.ecs.soton.ac.uk/~njh/dabepg/
#

use strict;
use warnings;
use XML::Writer;
use IO::File;


## Globals ##
my $VERSION = '0.3';
my %token_table = ();
my $default_dabid = undef;


# Check the arguments
my $input_file = $ARGV[0];
my $output = undef;

if (@ARGV == 2) {
	my $output_file = $ARGV[1];
	$output = new IO::File($output_file, "w") or 
	die "Failed to open output file ($output_file): $!\n";
	
} elsif (@ARGV != 1) {
	print "usage: dabepg_bin2xml <inputfile> [<outputfile>]\n";
	exit(-1);
}


# Read in the whole input file
my $data = readfile( $input_file );


# Create XML Writer
my $writer = new XML::Writer( OUTPUT => $output );
$writer->xmlDecl("utf-8");
$writer->comment("Converted from '$input_file' by dabepg_bin2xml.pl $VERSION");

# Parse the first top-level element
my ($toptag, $toplen) = chomp_header( \$data );
my $element_data = substr($data, 0, $toplen);
if ($toptag != 0x02 and $toptag != 0x03) {
	die "Invalid top-level tag: ".sprintf("0x%2.2X", $toptag);
}

# Begin recursive parsing of tags
parse_element( $toptag, $element_data );

# End of the XML Document
$writer->end();


# Success
exit(0);




sub readfile {
	my ($filename) = @_;
	local $/;
	
	open(FILE, $filename) or 
	die "Failed to open file ($filename) : $!";
	my $data = <FILE>;
	close(FILE);
	
	return $data;
}


sub parse_element {
	my($tag, $data) = @_;
	
	my $name = element_tag2name( $tag );
	my %attributes = element_default_attr( $tag );
	my $tag_started = 0;
	my $saw_bearer = 0;


	# Process each of the sub-tags for this element
	while( length( $data ) ) {
		my ($subtag, $sublen) = chomp_header( \$data );
		my $subdata = chomp_bytes( \$data, $sublen );

		if ($subtag==0x01) {
			# CDATA Tag
			if (!$tag_started) {
				$writer->startTag($name, %attributes);
				$tag_started=1;
			}
			parse_cdata( $tag, $subdata );
		
		} elsif ($subtag==0x04) {
			# Token Table Tag
			parse_token_table( $tag, $subdata );
			
		} elsif ($subtag==0x05) {
			# Default DAB ID tag
			parse_default_dabid( $tag, $subdata );
			
		} elsif ($subtag>=0x10 and $subtag<=0x7E) {
			# Sub-element Tag
			if (!$tag_started) {
				$writer->startTag($name, %attributes);
				$tag_started=1;
			}
			parse_element( $subtag, $subdata );

			$saw_bearer=1 if ($subtag==0x2D);
			
		} elsif ($subtag>=0x80 and $subtag<=0xFF) {
			# Attribute Tag
			my ($name, $value) = parse_attribute( $tag, $subtag, $subdata );
			$attributes{$name} = $value;
			
		} else {
			die "Don't know how to handle tag: ".sprintf("0x%2.2X", $subtag);

		}
	}
	
	if ($tag_started) {
		# Add default bearer if not defined
		if ($tag==0x19 and $saw_bearer==0) {
			$writer->emptyTag('bearer', id=>$default_dabid);
		}
		$writer->endTag($name);
	} else {
		$writer->emptyTag($name, %attributes);
	}

}


sub parse_cdata {
	my ($parent, $data) = @_;
	$writer->characters( tt_substitute( $data ) );
}


sub parse_attribute {
	my ($parent, $attr, $data) = @_;
	my $enum = unpack('C', $data);
	my $name = undef;
	my $value = undef;
	
	if ($parent==0x02) {		# epg
		if ($attr==0x80) {
			$name='system';
			if ($enum==0x01) { $value='DAB' }
		}

	} elsif ($parent==0x03) {	# serviceInformation
		if ($attr==0x80) {
			$name='version';
			$value=unpack('n', $data);
		} elsif ($attr==0x81) {
			$name='creationTime';
			$value=parse_time( $data );
		} elsif ($attr==0x82) {
			$name='orginator';
			$value=tt_substitute( $data );
		} elsif ($attr==0x83) {
			$name='serviceProvider';
			$value=tt_substitute( $data );
		} elsif ($attr==0x84) {
			$name='system';
			if ($enum==0x01) { $value='DAB' }
		}

	} elsif ($parent==0x10 or 	# shortName
			 $parent==0x11 or 	# mediumName
			 $parent==0x12 or	# longName
			 $parent==0x16 or	# keywords
			 $parent==0x1A or	# shortDescription
			 $parent==0x1B or	# longDescription
			 $parent==0x2A)		# dabLanguage
	{	
		if ($attr==0x80) {
			$name='xml:lang';
			$value=tt_substitute( $data );
		}

	} elsif ($parent==0x14) {	# genre
		if ($attr==0x80) {
			$name='href';
			$value=parse_genre_href($data);
		} elsif ($attr==0x81) {
			$name='type';
			   if ($enum==0x01) { $value='main' }
			elsif ($enum==0x02) { $value='secondary' }
			elsif ($enum==0x03) { $value='other' }
		}

	} elsif ($parent==0x15) {	# CA
		if ($attr==0x80) {
			$name='type';
			   if ($enum==0x01) { $value='none' }
			elsif ($enum==0x02) { $value='unspecified' }
		}

	} elsif ($parent==0x17) {	# memberOf
		if ($attr==0x80) {
			$name='id';
			$value=tt_substitute( $data );
		} elsif ($attr==0x81) {
			$name='shortId';
			$value=unpack_24bit_int($data);
		} elsif ($attr==0x82) {
			$name='index';
			$value=unpack('n', $data);
		}

	} elsif ($parent==0x18) {	# link
		if ($attr==0x80) {
			$name='url';
			$value=tt_substitute( $data );
		} elsif ($attr==0x81) {
			$name='mimeValue';
			$value=tt_substitute( $data );
		} elsif ($attr==0x82) {
			$name='xml:lang';
			$value=tt_substitute( $data );
		} elsif ($attr==0x83) {
			$name='description';
			$value=tt_substitute( $data );
		} elsif ($attr==0x84) {
			$name='expiryTime';
			$value=parse_time( $data );
		}
		
	} elsif ($parent==0x1C) {	# programme
		if ($attr==0x80) {
			$name='id';
			$value=tt_substitute( $data );
		} elsif ($attr==0x81) {
			$name='shortId';
			$value=unpack_24bit_int($data);
		} elsif ($attr==0x82) {
			$name='version';
			$value=unpack('n', $data);
		} elsif ($attr==0x83) {
			$name='recommendation';
			   if ($enum==0x01) { $value='no' }
			elsif ($enum==0x02) { $value='yes' }
		} elsif ($attr==0x84) {
			$name='broadcast';
			   if ($enum==0x01) { $value='on-air' }
			elsif ($enum==0x02) { $value='off-air' }
		} elsif ($attr==0x85) {
			$name='bitrate';
			$value=unpack('n', $data);
		} elsif ($attr==0x86) {
			$name='xml:lang';
			$value=tt_substitute( $data );
		}
		
	} elsif ($parent==0x20) {	# programmeGroups
		if ($attr==0x80) {
			$name='version';
			$value=unpack('n', $data);
		} elsif ($attr==0x81) {
			$name='creationTime';
			$value=parse_time( $data );
		} elsif ($attr==0x82) {
			$name='originator';
			$value=tt_substitute( $data );
		}
		
	} elsif ($parent==0x21) {	# schedule
		if ($attr==0x80) {
			$name='version';
			$value=unpack('n', $data);
		} elsif ($attr==0x81) {
			$name='creationTime';
			$value=parse_time( $data );
		} elsif ($attr==0x82) {
			$name='originator';
			$value=tt_substitute( $data );
		}
		
	} elsif ($parent==0x22) {	# alternateSource
		if ($attr==0x80) {
			$name='protocol';
			   if ($enum==0x01) { $value='URL' }
			elsif ($enum==0x02) { $value='DAB' }
		} elsif ($attr==0x81) {
			$name='type';
			   if ($enum==0x01) { $value='identical' }
			elsif ($enum==0x02) { $value='more' }
			elsif ($enum==0x03) { $value='less' }
			elsif ($enum==0x04) { $value='similar' }
		} elsif ($attr==0x82) {
			$name='url';
			$value=tt_substitute( $data );
		}
		
	} elsif ($parent==0x23) {	# programmeGroup
		if ($attr==0x80) {
			$name='id';
			$value=tt_substitute( $data );
		} elsif ($attr==0x81) {
			$name='shortId';
			$value=unpack_24bit_int($data);
		} elsif ($attr==0x82) {
			$name='version';
			$value=unpack('n', $data);
		} elsif ($attr==0x83) {
			$name='type';
			   if ($enum==0x02) { $value='series' }
			elsif ($enum==0x03) { $value='show' }
			elsif ($enum==0x04) { $value='programConcept' }
			elsif ($enum==0x05) { $value='magazine' }
			elsif ($enum==0x06) { $value='programCompilation' }
			elsif ($enum==0x07) { $value='otherCollection' }
			elsif ($enum==0x08) { $value='otherChoice' }
			elsif ($enum==0x09) { $value='topic' }
		} elsif ($attr==0x84) {
			$name='numOfItems';
			$value=unpack('n', $data);
		}
		
	} elsif ($parent==0x24) {	# scope
		if ($attr==0x80) {
			$name='startTime';
			$value=parse_time( $data );
		} elsif ($attr==0x81) {
			$name='stopTime';
			$value=parse_time( $data );
		}
		
	} elsif ($parent==0x25) {	# serviceScope
		if ($attr==0x80) {
			$name='id';
			$value=parse_dabid($data);
		}
		
	} elsif ($parent==0x26) {	# ensemble
		if ($attr==0x80) {
			$name='id';
			my ($ecc, $eid) = unpack( "Cn", $data);
			$value=sprintf("%2.2x.%4.4x", $ecc, $eid);
		} elsif ($attr==0x81) {
			$name='version';
			$value=unpack('n', $data);
		}
		
	} elsif ($parent==0x27) {	# frequency
		if ($attr==0x80) {
			$name='type';
			if ($enum==0x01) { $value='primary' }
			elsif ($enum==0x02) { $value='secondary' }
		} elsif ($attr==0x81) {
			$name='kHz';
			$value=unpack_24bit_int($data);
		}
		
	} elsif ($parent==0x28) {	# service
		if ($attr==0x80) {
			$name='version';
			$value=unpack('n', $data);
		} elsif ($attr==0x81) {
			$name='format';
			if ($enum==0x01) { $value='Audio' }
			elsif ($enum==0x02) { $value='DLS' }
			elsif ($enum==0x03) { $value='MOTSlideshow' }
			elsif ($enum==0x04) { $value='MOTBWS' }
			elsif ($enum==0x05) { $value='TPEG' }
			elsif ($enum==0x06) { $value='DGPS' }
			elsif ($enum==0x07) { $value='proprietary' }
		}
		
	} elsif ($parent==0x29) {	# serviceID
		if ($attr==0x80) {
			$name='id';
			$value=parse_dabid($data);
		} elsif ($attr==0x81) {
			$name='type';
			if ($enum==0x01) { $value='primary' }
			elsif ($enum==0x02) { $value='secondary' }
		}
		
	} elsif ($parent==0x2B) {	# multimedia
		if ($attr==0x80) {
			$name='mimeValue';
			$value=tt_substitute( $data );
		} elsif ($attr==0x81) {
			$name='xml:lang';
			$value=tt_substitute( $data );
		} elsif ($attr==0x82) {
			$name = 'url';
			$value=tt_substitute( $data );
		} elsif ($attr==0x83) {
			$name = 'type';
			if ($enum==0x02) { $value='logo_unrestricted' }
			elsif ($enum==0x03) { $value='logo_mono_square' }
			elsif ($enum==0x04) { $value='logo_colour_square' }
			elsif ($enum==0x05) { $value='logo_mono_rectangle' }
			elsif ($enum==0x06) { $value='logo_colour_rectangle' }
		} elsif ($attr==0x84) {
			$name = 'width';
			$value=unpack('n', $data);
		} elsif ($attr==0x85) {
			$name = 'height';
			$value=unpack('n', $data);
		}

	} elsif ($parent==0x2C) {	# time
		if ($attr==0x80) {
			$name='time';
			$value=parse_time( $data );
		} elsif ($attr==0x81) {
			$name='duration';
			$value=parse_duration( $data );
		} elsif ($attr==0x82) {
			$name='actualTime';
			$value=parse_time( $data );
		} elsif ($attr==0x83) {
			$name='actualDuration';
			$value=parse_duration( $data );
		}

	} elsif ($parent==0x2D) {	# bearer
		if ($attr==0x80) {
			$name='id';
			$value=parse_dabid($data);
		} elsif ($attr==0x81) {
			$name='trigger';
			# See EN 300 401 for how to decode this
			warn "Don't know how to decode 4 byte tigger codes yet";
		}
		
	} elsif ($parent==0x2E) {	# programmeEvent
		if ($attr==0x80) {
			$name='id';
			$value=tt_substitute( $data );
		} elsif ($attr==0x81) {
			$name='shortId';
			$value=unpack_24bit_int($data);
		} elsif ($attr==0x82) {
			$name='version';
			$value=unpack('n', $data);
		} elsif ($attr==0x83) {
			$name='recommendation';
			   if ($enum==0x01) { $value='no' }
			elsif ($enum==0x02) { $value='yes' }
		} elsif ($attr==0x84) {
			$name='broadcast';
			   if ($enum==0x01) { $value='on-air' }
			elsif ($enum==0x02) { $value='off-air' }
		}
	}
	
	
	# Check we found a match
	if (!defined $name) {
		warn "Unhandled attribute tag ".sprintf("0x%2.2X",$attr).
			 " for element tag ".sprintf("0x%2.2X",$parent);
	}
	if (!defined $value and defined $name) {
		warn "Unhandled attribute value for attribute '$name'.";
	}
	
	# Return the attribute
	return ($name, $value);
}


sub parse_token_table {
	my ($parent, $tokens) = @_;

	while(length($tokens)) {
		my $token = chomp_bytes( \$tokens, 1 );
		my $token_len = chomp_8bit_int( \$tokens );
		my $token_data = chomp_bytes( \$tokens, $token_len );
		$token_table{$token} = $token_data;
		
		#my $token_id = unpack('C', $token);
		#$writer->comment(sprintf("Token table entry: 0x%2.2x => '%s'", $token_id, $token_data));
	}
}


sub parse_default_dabid {
	my ($parent, $dabid) = @_;
	$default_dabid = parse_dabid($dabid);
	$writer->comment("Default DAB ID is '$default_dabid'");
}


sub parse_dabid {
	my ($dabid) = @_;

	my ($flags) = chomp_8bit_int( \$dabid );
	#my $rfa = ($flags >> 7) & 0x01;
	my $ens_flag = ($flags >> 6) & 0x01;
	my $xpad_flag = ($flags >> 5) & 0x01;
	my $sid_flag = ($flags >> 4) & 0x01;
	my $scids = sprintf("%x", $flags & 0x0F);
	
	my $ensemble='';
	if ($ens_flag) {
		my $ecc = chomp_8bit_int( \$dabid );
		my $eid = chomp_16bit_int( \$dabid );
		$ensemble=sprintf("%2.2x.%4.4x.", $ecc, $eid);
	}
	
	my $sid='';
	if ($sid_flag) {
		$sid=sprintf("%8.8x.", chomp_32bit_int( \$dabid ));
	} else {
		$sid=sprintf("%4.4x.", chomp_16bit_int( \$dabid ));
	}

	return $ensemble.$sid.$scids;
}


sub parse_time {
	my ($time) = @_;

	# Grab the first four bytes
	my ($long) = chomp_32bit_int( \$time );
	
	my $min = $long & 0x3F;
	my $hour = ($long >> 6) & 0x1F;
	my $utc_flag = ($long >> 11) & 0x01;
	my $lto_flag = ($long >> 12) & 0x01;
	my $mjd = ($long >> 14) & 0x1FFFF;
	
	my ($day, $mon, $year) = gregorian_date( $mjd );
	my $date = sprintf("%4.4d-%2.2d-%2.2d", $year, $mon, $day);
	
	# get the seconds/milliseconds if present
	my $sec=0;
	if ($utc_flag) {
		my $ms = chomp_16bit_int( \$time );
		#$msec = $ms & 0x3FF;
		$sec = ($ms >> 10) & 0x3F
	}
	
	# Get timezone info if present
	my $zone = 'Z';
	if ($lto_flag) {
		my $lto = chomp_8bit_int( \$time );
		
		my $sign = '';
		if (($lto >> 5) & 0x01) { $sign = '-'; }
		else { $sign = '+'; }
		
		my $offset = ($lto & 0x1F) * 30;
		if ($offset) {
			$zone = sprintf("%s%2.2d:%2.2d", $sign, int($offset/60), $offset%60);
		}
	}

	return $date.'T'.sprintf("%2.2d:%2.2d:%2.2d", $hour, $min, $sec).$zone;
}

#
# Return the day, month, and year given the day number
#
sub gregorian_date {
    my ($mjd) = @_;

    # Inverse MJD formula from chapter 7 of "Astronomical Agorithms" 
    # by Jean Meeus. Formula adjusted from JD to MJD. Variable names 
    # follow those in book.

    $mjd = int ($mjd);
    my $alpha = int (($mjd + 532784.75) / 36524.25);

    my $a = $mjd + 2400002.0 + $alpha - int ($alpha / 4.0);
    my $b = $a + 1524.0;
    my $c = int (($b - 122.1) / 365.25);
    my $d = int (365.25 * $c);
    my $e = int (($b - $d) / 30.6001);

    my $day = $b - $d - int (30.6001 * $e);
    my $month = $e - 1.0;
    my $year = $c - 4716.0;

    if ($month > 12) {
	$month = $month - 12;
	$year = $year + 1;
    }

    return ($day, $month, $year);
}


sub parse_duration {
	my ($data) = @_;
	
	my $dur = unpack('n', $data);
	my $hour = int($dur/3600); $dur%=3600;
	my $min = int($dur/60); $dur%=60;
	my $sec = int($dur/60); $dur%=60;
	
	my $iso = 'PT';
	if ($hour) { $iso .= $hour."H"; }
	if ($min) { $iso .= $min."M"; }
	if ($sec) { $iso .= $sec."S"; }
	
	return $iso;
}


sub parse_genre_href {
	my ($genre) = @_;
	
	my $cs = chomp_8bit_int( \$genre ) & 0x0F;
	my $href = 'urn:tva:metadata:cs';
	if ($cs==1)		{ $href .= ':IntentionCS:2002' }
	elsif ($cs==2)	{ $href .= ':FormatCS:2002' }
	elsif ($cs==3)	{ $href .= ':ContentCS:2002' }
	elsif ($cs==4)	{ $href .= ':IntendedAudienceCS:2002' }
	elsif ($cs==5)	{ $href .= ':OriginationCS:2002' }
	elsif ($cs==6)	{ $href .= ':ContentAlertCS:2002' }
	elsif ($cs==7)	{ $href .= ':MediaTypeCS:2002' }
	elsif ($cs==8)	{ $href .= ':AtmosphereCS:2002' }
	else {
		# Invalid CS
		return undef;
	}
	
	# Level 1
	if (length($genre)) {
		$href .= sprintf(":%d", chomp_8bit_int( \$genre ));
	}

	# Level 2
	if (length($genre)) {
		$href .= sprintf(".%d", chomp_8bit_int( \$genre ));
	}

	# Level 3
	if (length($genre)) {
		$href .= sprintf(".%d", chomp_8bit_int( \$genre ));
	}
	
	return $href;
}


sub unpack_24bit_int {
	my ($packed) = @_;
	
	# Just prefix it with a null byte to make it 32bit
	my ($value) = unpack("N", "\0".$packed);
	return $value;
}


#
# Lookup the XML element name
# for a tag id
#
sub element_tag2name {
	my ($tag) = @_;
	
	if ($tag==0x02)		{ return "epg" }
	elsif ($tag==0x03)	{ return "serviceInformation" }
	elsif ($tag==0x10)	{ return "shortName" }
	elsif ($tag==0x11)	{ return "mediumName" }
	elsif ($tag==0x12)	{ return "longName" }
	elsif ($tag==0x13)	{ return "mediaDescription" }
	elsif ($tag==0x14)	{ return "genre" }
	elsif ($tag==0x15)	{ return "CA" }
	elsif ($tag==0x16)	{ return "keywords" }
	elsif ($tag==0x17)	{ return "memberOf" }
	elsif ($tag==0x18)	{ return "link" }
	elsif ($tag==0x19)	{ return "location" }
	elsif ($tag==0x1A)	{ return "shortDescription" }
	elsif ($tag==0x1B)	{ return "longDescription" }
	elsif ($tag==0x1C)	{ return "programme" }
	elsif ($tag==0x20)	{ return "programmeGroups" }
	elsif ($tag==0x21)	{ return "schedule" }
	elsif ($tag==0x22)	{ return "alternateSource" }
	elsif ($tag==0x23)	{ return "programmeGroup" }
	elsif ($tag==0x24)	{ return "scope" }
	elsif ($tag==0x25)	{ return "serviceScope" }
	elsif ($tag==0x26)	{ return "ensemble" }
	elsif ($tag==0x27)	{ return "frequency" }
	elsif ($tag==0x28)	{ return "service" }
	elsif ($tag==0x29)	{ return "serviceID" }
	elsif ($tag==0x2A)	{ return "dabLanguage" }
	elsif ($tag==0x2B)	{ return "multimedia" }
	elsif ($tag==0x2C)	{ return "time" }
	elsif ($tag==0x2D)	{ return "bearer" }
	elsif ($tag==0x2E)	{ return "programmeEvent" }
	else {
		die "Unsupported Element tag: $tag";
	}
}



#
# Lookup default attributes for an element
# for a tag id
#
sub element_default_attr {
	my ($tag) = @_;
	
	if ($tag==0x02) {		# epg
		return (
			'xmlns:epg' => 'http://www.worlddab.org/schemas/epg',
			'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
			'xsi:schemaLocation' => 'http://www.worlddab.org/schemas/epg '.
									'epgSchedule_11.xsd',
			'system' => 'DAB' );
	} elsif ($tag==0x03) {	# serviceInformation
		return (
			'xmlns:epg' => 'http://www.worlddab.org/schemas/epg',
			'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
			'xsi:schemaLocation' => 'http://www.worlddab.org/schemas/epg '.
									'epgSI_11.xsd',
			'system' => 'DAB' );
	} elsif ($tag==0x14) {	# genre
		return ( 'type' => 'main' );
	} elsif ($tag==0x15) {	# CA
		return ( 'type' => 'none' );
	} elsif ($tag==0x1C) {	# programme
		return ( 'type' => 'on-air',
		         'recommendation' => 'no');
	} elsif ($tag==0x22) {	# alternateSource
		return ( 'protocol' => 'URL',
				 'type' => 'identical' );
	} elsif ($tag==0x25) {	# serviceScope
		return ( 'id' => $default_dabid );
	} elsif ($tag==0x27) {	# frequency
		return ( 'type' => 'primary' );
	} elsif ($tag==0x28) {	# service
		return ( 'format' => 'Audio' );
	} elsif ($tag==0x29) {	# serviceID
		return ( 'id' => $default_dabid,
		         'type' => 'primary' );
	} elsif ($tag==0x2D) {	# bearer
		return ( 'id' => $default_dabid );
	} elsif ($tag==0x2E) {	# programmeEvent
		return ( 'type' => 'on-air',
		         'recommendation' => 'no');
	} else {
		# No default attributes for all others
		return ();
	}
}



# 
# Substitute entries in the token table
# for thier true values
#
sub tt_substitute {
	my ($text) = @_;
	
	foreach( keys %token_table ) {
		$text =~ s/$_/$token_table{$_}/g;
	}

	return $text;
}



# Chomp the 8bit tag and length
sub chomp_header {
	my ($data) = @_;
	
	my ($tag) = chomp_8bit_int( $data );
	my ($len) = chomp_8bit_int( $data );
	
	if ($len == 0xFE) {
		$len = chomp_16bit_int( $data );
	} elsif ($len == 0xFF) {
		$len = chomp_24bit_int( $data );
	}
	
	return ($tag, $len);
}


# Remove $count bytes from the start of $data
# and return them
sub chomp_bytes {
	my ($data, $count) = @_;
	
	$count = 1 unless ($count);
	
	my $bytes = substr( $$data, 0, $count );
	$$data = substr( $$data, $count );

	return $bytes;
}


# Remove one byte from the start of $data
# and return it as a 8bit unsigned int
sub chomp_8bit_int {
	my ($data) = @_;
	
	my $byte = chomp_bytes( $data, 1);
	my ($int) = unpack( "C", $byte );
	
	return $int;
}

# Remove two bytes from the start of $data
# and return it as a 16bit unsigned int
sub chomp_16bit_int {
	my ($data) = @_;
	
	my $bytes = chomp_bytes( $data, 2);
	my ($int) = unpack( "n", $bytes );
	
	return $int;
}

# Remove three bytes from the start of $data
# and return it as a 24bit unsigned int
sub chomp_24bit_int {
	my ($data) = @_;
	
	my $bytes = chomp_bytes( $data, 3);
	my ($int) = unpack( "N", "\0".$bytes );
	
	return $int;
}


# Remove four bytes from the start of $data
# and return it as a 32bit unsigned int
sub chomp_32bit_int {
	my ($data) = @_;
	
	my $bytes = chomp_bytes( $data, 4);
	my ($int) = unpack( "N", $bytes );
	
	return $int;
}


__END__


=head1 NAME

dabepg_bin2xml - Convert DAB Binary EPG (ETSI TS 102 371) to
 DAB XML EPG (ETSI TS 102 818)

=head1 VERSION

This document describes version 0.2 of dabepg_bin2xml, released 6th June 2005.

=head1 DESCRIPTION

The perl script will convert Binary EPG files (as broadcast over DAB) and 
coverted them to the (much larger) XML format.

For more information about DAB and the EPG standard visit World DAB Forum's homepage C<http://www.worlddab.org>.



=head1 README

Convert DAB Binary EPG (ETSI TS 102 371) to DAB XML EPG (ETSI TS 102 818)

=head1 PREREQUISITES

This script requires the C<XML::Writer> perl module.

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

Web
Misc

=head1 AUTHOR

Nicholas Humfrey E<lt>njh@ecs.soton.ac.ukE<gt>

=head1 COPYRIGHT

    Copyright (c) 2005, University of Southampton. All Rights Reserved.
    This module is free software. It may be used, redistributed
        and/or modified under the same terms as Perl itself.

=cut
