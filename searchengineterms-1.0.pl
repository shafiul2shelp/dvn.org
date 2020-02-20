#!/usr/bin/perl
# searchengineterms-1.0.pl - display search terms that users used to find your website

use warnings;
use strict;
use URI::Escape;

my %unique;

# read entries from STDIN - cat/bzcat/etc your access log to this script
while (<>)
{
	if ( m#\Wq(?:ry|kw|uery\?p)?=([^&\s?]+)# ) 
	{ 
		my $string = uri_unescape($1);
		$string =~ tr/\+/ /;

		# if there's an odd number of quotes and one of them is at the end,
		# chop off that last one
		chop($string) if ( 
			(scalar($string=~tr/"//) % 2 != 0) && 
			(rindex($string,'"') == (length($string)-1)) 
		);

		# only keep unique entries
		$unique{$string}++;
	}
}

print "$_\n" foreach (keys %unique); 

=head1 NAME

searchengineterms-1.0.pl - display search terms that users used to find your website

=head1 DESCRIPTION

Pipe your httpd access logs to this script to see a list of search terms that
caused a search engine to send them to your website.

=head1 README

Given entries from your httpd access logs, this script will return a list of 
search terms that users used to find your site.  The script doesn't attempt to 
parse the log entries at all, it just looks for something in the string that
resembles a referer URL from a search engine.  Obviously, your web server must
be configured to log the referer URL in your access logs or this script wont' work.

Here are a couple examples of how you'd call this script:

# cat /var/log/httpd/access-20020701.log | searchengineterms-1.0.pl
# bzcat /var/log/httpd/access*.bz2 | searchengineterms-1.0.pl

=head1 PREREQUISITES

This script uses the C<strict> and C<warnings> modules, which shouldn't
be a problem for anyone.  It also requires that C<URI::Escape> is installed.  

=head1 AUTHOR

Rob Duarte <perl@rahji.com>

=head1 COPYRIGHT

Copyright (c) 2002 Rob Duarte. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms
as Perl itself.

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

Web
UNIX/System_administration

=cut
