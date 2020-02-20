#!/usr/bin/perl

#
# Enjoy this program.  Feel free to distribute it as you feel with my name still in it.
#   Robert R. Dell
#

$version = "getcount 3.0.0";

# tell the web browser we're going to send it HTML text it needs to process
# instead of plain text which it can display without processing
print "Content-type: text/html\n\n";

# get the query string
if ($ENV{'REQUEST_METHOD'} eq 'GET') {
   # Split the name-value pairs
   @pairs = split(/&/, $ENV{'QUERY_STRING'});
}
elsif ($ENV{'REQUEST_METHOD'} eq 'POST') {
   # Get the input
   read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});

   # Split the name-value pairs
   @pairs = split(/&/, $buffer);
}
else {
   print "Unable to process your request $version\n";
   exit 0;
};

# absolute path to the counter file on the website.
$logpath = "/Library/Webserver/Documents/count.shtml";
$theurl = "";

# we SHOULD unload $buffer at this stage to reduce memory requirements but
# in these days of massive megs of RAM, nobody worries about regaining 80
# or so bytes right?

foreach $pair (@pairs) {

   # Split the pair up into individual variables.                       #
   local($name, $value) = split(/=/, $pair);

   # Decode the form encoding on the name and value variables.          #
   # v1.92: remove null bytes                                           #
   $name =~ tr/+/ /;
   $name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
   $name =~ tr/\0//d;

   $value =~ tr/+/ /;
   $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
   $value =~ tr/\0//d;
   $item = 0;

   if ($name eq 'url') {
     $theurl = $value;
     }
   }

if ($theurl eq "") {
  print "Unable to process your request $version\n";
  exit 0;
  };

$theurl =~ s/\n//;

open (LOG, "$logpath");
@data = <LOG>;
close(LOG);

if ($#data == -1) {
  print "Unable to open the counter file $version\n";
  print "fixlog.pl must be executed at least once\n";
  exit 0;
  };

$found = 0;

foreach $myarray_line(@data) {
  $oldmyarrayline = join("",$myarray_line);
  $url = join("","<tr><td><a href=\"",$theurl,"\">",$theurl,"</a>:</td>");
  if ($myarray_line =~ m/$url/) {
    $oldmyarrayline =~ s/^.*<\/td><td>//;
    $oldmyarrayline =~ s/\n//;
    $oldmyarrayline =~ s/\r//;
    $oldmyarrayline =~ s/<.*$//;
    $count = $oldmyarrayline;
    print $count;
    $found = 1;
    }
  };

if ($found == 0) {
  print "0";
  };


exit 0;

=head1 getcount

This script gets the counter information from a counter file which happens to be a
web page.

=head1 DESCRIPTION

This script scans through the site's counter file looking for the url you requested.
If it doesn't find the url, it returns 0.

=head1 AUTHOR

Robert R. Dell xyzzy@cpan.org

=head1 README

This script scans through the site's counter file looking for the url you requested.
If it doesn't find the url, it returns 0.

=head1 PREREQUISITES

fixlog.pl

=head1 COREQUISITES

CGI

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

Web

=cut


