#!/usr/bin/perl

# tell the web browser we're going to send it HTML text it needs to process
# instead of plain text which it can display without processing
print "Content-Type: text/html\n\n";

# variables
$debug = 0;
$linenumber = 0;
$error = 0;
$whois_server = 0;
$current_max_server = 6;
# whois server definitions
#  0 = arin.net
#  1 = dnsstuff.com
#  2 = zoneedit.com
#  3 = ripe.net
#  4 = apnic.net
#  5 = lacnic.net
#  6 = afrinic.net

# http://remote.12dt.com/rns/
# http://www.dnsstuff.com/
# http://www.dnsstuff.com/tools/ptr.ch?ip=+209.16.217.15+
# http://www.zoneedit.com/lookup.html?ipaddress=209.16.217.15&server=&reverse=Look+it+up
# http://www.ripe.net/fcgi-bin/whois?form_type=simple&full_query_string=&searchtext=194.140.65.241&submit.x=9&submit.y=9&submit=Search
# http://apnic.net/apnic-bin/whois.pl?searchtext=211.0.0.0&whois=Go
# http://lacnic.net/cgi-bin/lacnic/whois?lg=EN&query=24.99.119.99
# http://www.afrinic.net/cgi-bin/whois?form_type=simple&full_query_string=&searchtext=82.201.209.19

@servers = ("arin.net", "dnsstuff.com", "zoneedit.com", "ripe.net", "apnic.net", "lacnic.net", "afrinic.net");
$my_server = "http://robertdell.dyndns.org/";
$my_cgi_name = "cgi-bin/getaccesslog.cgi";

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
  };

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

  if ($name eq "method") {
    $whois_server = $value;
    if ($whois_server < 0) {
      $whois_server = 0;
      }
    elsif ($whois_server > $current_max_server) {
      $whois_server = 0;
      };
    };
  };

# refresh how often?
$refresh_hours   = 0;
$refresh_minutes = 6;
$refresh_seconds = 0;

$refreshtime = ((($refresh_hours*60)+$refresh_minutes)*60)+$refresh_seconds;

# Version history
# 1.0.0  Original program written
# 1.1.0  Changed the output to HTML 4.01 compliant
# 2.0.0  Changed the IP addresses to 4 sets of 3 numbers for ease of readability
# 2.1.0  Added the ability of checking whois to the IP addresses with a single click
# 2.1.1  Added comments and version number for addition to the CPAN archives
# 2.1.2  Added better error handling
# 2.2.0  changed the local net address selection and added both local net selections.
# 3.0.0  Added a new feature to the get log program to allow it to work with logcleaner (strips out the overloads, updated the counter files)
#        skips 0.0.0.0 IP address.
#        Also fixed a minor bug in the local IP address filters.
# 3.1.0  added a refresh to ensure acurateness of an access log if it's kept on.
# 3.2.0  added multiple reverse dns query addresses but it's still secure and hard coded.
# 3.3.0  added javascript engine and code to switch between multiple whois servers
# 3.4.0  added <hr /> when it gets to the line where we last counted
# 3.4.1  added coloring to certain aspects of the log
# 3.5.0  added new reverse dns servers
# 3.5.1  changed download location
# 3.6.0  added one more reverse dns server
# 3.6.1  fixed bug in displaying afrinic.net name
#
$version = "GetLog version 3.6.1";

# The location of an apache log file in the following format
#
# 10.0.1.1 - - [15/Jan/2005:01:09:18 -0500] "GET /cgi-bin/getagentlog.cgi HTTP/1.1" 200 59734
#
$mylogfilename = "/private/var/log/httpd/access_log";
# $mylogfilename = "/access.log";

$mytitle = "Access log";

# Create an error message
if ($debug == 1) {
  $errormessage = join( "", "<h3>Cannot open the access logs.<br />\n", $mylogfilename, "</h3>\n\n");
  }
else {
  $errormessage = "</small>\n\n<h3>Cannot open the log file.</h3>\n\n<small>\n";
  }

# print a HTML header for the display
print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">\n";
print "<html>\n";
print "<head>\n";
print "  <title> ",$mytitle," </title>\n";
print "  <meta http-equiv=\"Content-Type\" content=\"text/html; charset=ISO-8859-1\">\n";
print "  <meta http-equiv=\"refresh\" content=\"",$refreshtime,"\">\n";
print "  <link type=\"text/css\" rel=\"stylesheet\" href=\"/css/chapterstyle.css\">\n";
print "  <script language=\"JavaScript\" type=\"text/javascript\">\n";
print "    function refreshme(how) {\n";
print "    if (how=='0') {\n";
print "      window.location=\"$my_server$my_cgi_name\";\n";
print "      };\n";
print "    if (how=='1') {\n";
print "      window.location=\"$my_server$my_cgi_name?method=1\";\n";
print "      };\n";
print "    if (how=='2') {\n";
print "      window.location=\"$my_server$my_cgi_name?method=2\";\n";
print "      };\n";
print "    if (how=='3') {\n";
print "      window.location=\"$my_server$my_cgi_name?method=3\";\n";
print "      };\n";
print "    if (how=='4') {\n";
print "      window.location=\"$my_server$my_cgi_name?method=4\";\n";
print "      };\n";
print "    if (how=='5') {\n";
print "      window.location=\"$my_server$my_cgi_name?method=5\";\n";
print "      };\n";
print "    if (how=='6') {\n";
print "      window.location=\"$my_server$my_cgi_name?method=6\";\n";
print "      };\n";
print "    }\n";
print "  </script>\n";
print "</head>\n";
print "<body>\n";
print "<table class=\"noframes\">\n<tr>\n<td>\n";
print "<h1>",$mytitle,"</h1>\n";
print "<h4>",$version,"</h4>\n";
print "<hr />\n";
print "<p class=\"noindent\">get <a href=\"http://cpan.org/authors/id/X/XY/XYZZY/\" target=\"_blank\">$version</a> script.</p>\n";
print "<p class=\"noindent\">line number - IP address - date/time - method - file - protocol - result code - bytes served</p>\n";
print "<ul> Result codes\n";
print "  <li>200 - file found and served</li>\n";
print "  <li>302 - file moved</li>\n";
print "  <li>304 - file has not changed</li>\n";
print "  <li><b class=\"red\">401<\/b> - user not authorized</li>\n";
print "  <li><b class=\"red\">404<\/b> - file not found</li>\n";
print "  <li><b class=\"red\">414<\/b> - request too long</li>\n";
print "  <li>500 - file access error, somebody tried to access a file outside the web server folder.</li>\n";
print "  <li><b class=\"red\">501<\/b> - request method unknown, somebody tried to hack the site.</li>\n";
print "</ul>\n";
print "<p>You are now using server ",@servers[$whois_server],"</p>\n\n";
print "<ul>whois server\n";
if ($whois_server == 0) {
  print "  <li>arin.net</li>\n";
  }
else {
  print "  <li onclick=\"refreshme('0');\">arin.net</li>\n";
  };
if ($whois_server == 1) {
  print "  <li>dnsstuff.com</li>\n";
  }
else {
  print "  <li onclick=\"refreshme('1');\">dnsstuff.com</li>\n";
  };
if ($whois_server == 2) {
  print "  <li>zoneedit.com</li>\n";
  }
else {
  print "  <li onclick=\"refreshme('2');\">zoneedit.com</li>\n";
  };
if ($whois_server == 3) {
  print "  <li>ripe.net</li>\n";
  }
else {
  print "  <li onclick=\"refreshme('3');\">ripe.net</li>\n";
  };
if ($whois_server == 4) {
  print "  <li>apnic.net</li>\n";
  }
else {
  print "  <li onclick=\"refreshme('4');\">apnic.net</li>\n";
  };
if ($whois_server == 5) {
  print "  <li>lacnic.net</li>\n";
  }
else {
  print "  <li onclick=\"refreshme('5');\">lacnic.net</li>\n";
  };
if ($whois_server == 6) {
  print "  <li>afrinic.net</li>\n";
  }
else {
  print "  <li onclick=\"refreshme('6');\">afrinic.net</li>\n";
  };
print "</ul>\n";
print "<hr />\n\n<small>\n";

print "\n";

# Open up the log file
open(LOGFILE, $mylogfilename) or $error = 1;

if ($error == 1) {
  print $errormessage; }
else {

# get the data
  @data = <LOGFILE>;
  foreach $line(@data) {
# get rid of the overload logs that Apache cannot filter out
    if (($line =~ m/^.*\"SEARCH.*\"/) or ($line =~ m/^.*\"CONNECT.*\"/)) {
      
      }
    else {
# filter out the local net addresses (10.0.1.x and 192.168.1.x)
      if (($line =~ m/^10\D0\D1\D.*/) or ($line =~ m/^192\D168\D1\D.*/) or ($line =~ m/^0\D0\D0\D0\D.*/)) {
        if ($line =~ m/0\D0\D0\D0/) {
          print "<hr />\n";
          };
        }
      else {
# convert the numbers into 3 digits each for easier readability
        # match first number in ip address
        if ($line =~ m/^\d\D/) {
          $first = join("","00",substr($line,0,1));
          $line =~ s/^\d\D//;
          }
        elsif ($line =~ m/^\d\d\D/) {
          $first = join("","0",substr($line,0,2));
          $line =~ s/^\d\d\D//;
          }
        else {
          $first = substr ($line,0,3);
          $line =~ s/^\d\d\d\D//;
          };

        # match second number in ip address
        if ($line =~ m/^\d\D/) {
          $second = join("","00",substr($line,0,1));
          $line =~ s/^\d\D//;
          }
        elsif ($line =~ m/^\d\d\D/) {
          $second = join("","0",substr($line,0,2));
          $line =~ s/^\d\d\D//;
          }
        else {
          $second = substr ($line,0,3);
          $line =~ s/^\d\d\d\D//;
          };

        # match third number in ip address
        if ($line =~ m/^\d\D/) {
          $third = join("","00",substr($line,0,1));
          $line =~ s/^\d\D//;
          }
        elsif ($line =~ m/^\d\d\D/) {
          $third = join("","0",substr($line,0,2));
          $line =~ s/^\d\d\D//;
          }
        else {
          $third = substr ($line,0,3);
          $line =~ s/^\d\d\d\D//;
          };

        # match fourth number in ip address
        if ($line =~ m/^\d\D/) {
          $fourth = join("","00",substr($line,0,1));
          $line =~ s/^\d\D//;
          }
        elsif ($line =~ m/^\d\d\D/) {
          $fourth = join("","0",substr($line,0,2));
          $line =~ s/^\d\d\D//;
          }
        else {
          $fourth = substr ($line,0,3);
          $line =~ s/^\d\d\d\D//;
          };

# convert the IP back into 4 sets of 3 digits
        $ip = join(".", $first, $second, $third, $fourth);
        $my_ip = join(".", $first, $second, $third, $fourth);
        &breakip;
# The URL of the whois server query
        if ($whois_server == 0) {
          $whois = join("", "http://ws.arin.net/cgi-bin/whois.pl?queryinput=", $my_ip);
          }
        elsif ($whois_server == 1) {
          $whois = join("", "http://www.dnsstuff.com/tools/ptr.ch?ip=+", $my_ip, "+");
          }
        elsif ($whois_server == 2) {
          $whois = join("", "http://www.zoneedit.com/lookup.html?ipaddress=", $my_ip, "&server=&reverse=Look+it+up");
          }
        elsif ($whois_server == 3) {
          $whois = join("", "http://www.ripe.net/fcgi-bin/whois?form_type=simple&full_query_string=&searchtext=", $my_ip, "&submit.x=9&submit.y=9&submit=Search");
          }
        elsif ($whois_server == 4) {
          $whois = join("", "http://apnic.net/apnic-bin/whois.pl?searchtext=", $my_ip, "&whois=Go");
          }
        elsif ($whois_server == 5) {
          $whois = join("", "http://lacnic.net/cgi-bin/lacnic/whois?lg=EN&query=", $my_ip);
          }
        elsif ($whois_server == 6) {
          $whois = join("", "http://www.afrinic.net/cgi-bin/whois?form_type=simple&full_query_string=&searchtext=", $my_ip);
          }
       else {
         $whois = "unable to determine the whois server";
         };

        $linenumber++;
        # strip off carriage returns
        $line =~ s/\n//;
        
        # ------ coloring start ------
        $line =~ s/games/<b>games<\/b>/g;
        $line =~ s/stories/<b class=\"red\">stories<\/b>/g;
        $line =~ s/\ 401\ /<b class=\"red\">\ 401\ <\/b>/;
        $line =~ s/\ 404\ /<b class=\"red\">\ 404\ <\/b>/;
        $line =~ s/\ 414\ /<b class=\"red\">\ 414\ <\/b>/;
        $line =~ s/\ 501\ /<b class=\"red\">\ 501\ <\/b>/;
        $line =~ s/DR_Scripts/<b class=\"purple\">DR_Scripts<\/b>/g;
        $line =~ s/images/<b class=\"green\">images<\/b>/g;
        $line =~ s/cgi-bin/<b class=\"yellow\">cgi-bin<\/b>/g;
        $line =~ s/css/<b class=\"maroon\">css<\/b>/g;
        # ------ coloring end ------
        
        print "<p class=\"noindent\">",$linenumber,": <a class=\"noindent\" href=\"",$whois,"\" target=\"_blank\">",$ip,"</a> ",$line,"</p>\n";
        };
      };
    };

  close(LOGFILE);
  if ($linenumber == 0) {
    print "<p class=\"noindent\">No log entries at this time.  The log has just been freshly cleaned.</p>\n";
    };
  };

# print the HTML footer
print "</small>\n\n<hr />\n";
print "<h1>The End</h1>\n<hr />\n";
print "</td>\n</tr>\n</table>\n";
print "</body>\n",;
print "</html>\n\n";


exit 0 ;

sub breakip {
  $first =~ s/^0//;
  $first =~ s/^0//;
  $second =~ s/^0//;
  $second =~ s/^0//;
  $third =~ s/^0//;
  $third =~ s/^0//;
  $fourth =~ s/^0//;
  $fourth =~ s/^0//;
  $my_ip = join(".", $first, $second, $third, $fourth);
  };




=head1 getlog

This script allows for ease of getting and reading the access logs of the website
through a web page

=head1 DESCRIPTION

This script scans through the site's access log and ensures all IP addresses are
4 sets of 3 digits, adds a link to the whois page, and then displays that information
to the screen.  It strips out overloads and local accesses.

=head1 README

This script scans through the site's access log and ensures all IP addresses are
4 sets of 3 digits, adds a link to the whois page, and then displays that information
to the screen.  It strips out overloads and local accesses.

=head1 INSTRUCTIONS

You will also need a style sheet on your website according to the requisites you provide.

=head1 PREREQUISITES

The Apache web server and an access log.

=head1 COREQUISITES

CGI

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

Web

=cut

