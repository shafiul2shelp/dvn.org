#!/usr/bin/perl

#
# This program is designed to clean out the extraneous information from an Apache log file
# It is suggested that you run it as a cron script with apache turned off.  Turning Apache
# off is essential as Apache will just continue it's log file from the location it ended up
# at and you'll have a whole lot of nulls in the resulting file if it's left on.  The program
# usually runs for about 10-30 seconds max with 3 log files to process, much shorter with
# only one log to process.
#
# my files are defines as:
#   access_log   standard default Apache log file
#   agent_log    default log file plus referer information and user agent information
#   referer_log  default log plus the referer information
#   overload_log this is where all overloads are moved to
#
# Enjoy this program.  Feel free to distribute it as you feel with my name still in it.
#   Robert R. Dell
#

# 3.1.0  Added check for css sheet and adds it if necessary.
#        Added variable refresh rate for new files.
# 3.2.0  Added dots instead of printing out the item to be searched for
#        fixed bug in test for counter incrementation
$version = "fixlog 3.2.0";

# variables
$debug=0;
# absolute path to the counter file on the website.
if ($debug == 1) {
  $logpath = "/Library/WebServer/Documents/count1.shtml";
  }
else {
  $logpath = "/Library/WebServer/Documents/count.shtml";
  };
# pad the counter to 5 digits minimum
$pad = 5;
$counterlocation = "0.0.0.0   Skip this line\n";
$line = "";
# maximum number of dots printed to the screen in one line
$maxdots = 64;
# global storage for where the dot is
$dotposition = 0;
# indent each row of dots
$indentation = "     ";
# what will the dot look like, will it be an at sign, peroid, comma, dash ...
$step = ".";
$marker = "*";
$dot = ".";

@counterdata = ();
$pads = join ("", "%0", $pad, "d");

# refresh how often?
$refreshhours = 24;
$refreshminutes = 0;
$refreshseconds = 0;
$refreshtime = ((($refreshhours*60)+$refreshminutes)*60)+$refreshseconds;

# check for a valid css file
$csslocation = "/Library/WebServer/Documents/css/counter.css";
open ($cssfile, "$csslocation");
@cssdata = <$cssfile>;
close ($cssfile);
# create the file if it never existed
if ($#cssdata == -1) {
  # brute force create the css folder if it doesn't exist
  mkdir "/Library/WebServer/Documents/css/", 0777;
  open ($cssfile, ">$csslocation");
  print $cssfile "/* main body information */\r\n";
  print $cssfile "body {background-color:#F0F8FF; color:black; font-size: 12pt}\r\n";
  print $cssfile "\r\n";
  print $cssfile "/* table items */\r\n";
  print $cssfile "table {border: none; padding: 6px; width: 680px; text-align: justify}\r\n";
  print $cssfile "td {color:black; font-size: 12pt; text-align: right}\r\n";
  print $cssfile "\r\n";
  print $cssfile "/* headers */\r\n";
  print $cssfile "h1 {color: maroon;  font-size: 28pt; font-family: Arial, Helvetica, sans-serif; text-align: center; font-weight: bold}\r\n";
  print $cssfile "h2 {color: maroon;  font-size: 18pt; font-family: Arial, Helvetica, sans-serif; text-align: center; font-weight: bold}\r\n";
  print $cssfile "\r\n";
  print $cssfile "/* links  */\r\n";
  print $cssfile "a:link     {color: blue;   text-decoration: none;      font-weight: normal; cursor: pointer;  font-size: 12pt}\r\n";
  print $cssfile "a:hover    {color: purple; text-decoration: underline; font-weight: bold;   cursor: pointer;  font-size: 15pt}\r\n";
  print $cssfile "a:visited  {color: red;    text-decoration: underline; font-weight: bold;   cursor: pointer;  font-size: 12pt}\r\n\r\n\r\n";
  close ($cssfile);
  };

# open up the counter file
open ($countfile, "$logpath");
@counterdata = <$countfile>;
close($countfile);

# if there's an error opening up the counter file, create a new one
# and open it up.
if ($#counterdata == -1) {
  open ($countfile,">$logpath");
  print $countfile, "<?xml version=\"1.0\"?>\r\n";
  print $countfile, "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\r\n";
  print $countfile, "<html xml:lang=\"en\" xmlns=\"http://www.w3.org/1999/xhtml\">\r\n";
  print $countfile, "<head>\r\n";
  print $countfile, "  <title> Counter </title>\r\n";
  print $countfile, "  <meta http-equiv=\"Content-Type\" content=\"text/html; charset=ISO-8859-1\" />\r\n";
  # set the counter html refresh rate to 24 hours, 0 minutes, 0 seconds
  print $countfile, "  <meta http-equiv=\"refresh\" content=\"",$refreshtime,"\" />\r\n";
  print $countfile, "  <link type=\"text/css\" rel=\"stylesheet\" href=\"/css/counter.css\" />\r\n";
  print $countfile, "</head>\r\n";
  print $countfile, "<body>\r\n\r\n";
  print $countfile, "<table>\r\n";
  print $countfile, "</table>\r\n\r\n";
  print $countfile, "<hr />\r\n";
  print $countfile, "<h1>The End</h1>\r\n";
  print $countfile, "<hr />\r\n";
  print $countfile, "</body>\r\n";
  print $countfile, "</html>\r\n\r\n";
  close ($countfile);
  open ($countfile, "$logpath");
  @counterdata = <$countfile>;
  }


# start processing the logs in order.  I have 3 log files, some of you may only have one.
# NOTE:  this needs to be done with apache turned off and under root

############ access log ############
if ($debug == 1) {
  open($accesslogfile, "access.log");
  }
else {
  open($accesslogfile, "/private/var/log/httpd/access_log");
  };
blippr("/private/var/log/httpd/access_log", $indentation);
@accessdata = <$accesslogfile>;
close($accesslogfile);
@data = @accessdata;
if ($debug == 1) {
  open($outfile, ">out.log");
}
else {
  open($outfile, ">/private/var/log/httpd/access_log");
};
# yes, increment the counters
$doincrement = 1;
# no, do not write this to the overloads file
$writeoverload=0;
&processlog;
close ($outfile);
&savecounters;
@data = ();

############ agent log ############
open($agentlogfile, "/private/var/log/httpd/agent_log");
@agentdata = <$agentlogfile>;
close($agentlogfile);
@data = @agentdata;

# outfile is the output of the process, overload is the output of all overload logs
if ($debug == 1) {
  open($outfile, ">agentout.log");
  open($overload,">overload.log");
}
else {
  open($outfile, ">/private/var/log/httpd/agent_log");
  open($overload,">/volumes/macintosh_hd3/log/httpd/overload_log");
};
blippr("/private/var/log/httpd/agent_log", $indentation);
# no, do not increment the counters
$doincrement = 0;
# yes, write to the overloads file
$writeoverload=1;
&processlog;
close ($outfile);
close ($overload);
@data = ();

############ referer log ############
open($refererlogfile, "/private/var/log/httpd/referer_log");
@refererdata = <$refererlogfile>;
close($refererlogfile);
@data=@refererdata;
if ($debug == 1) {
  open($outfile, ">refererout.log");
}
else {
  open($outfile, ">/private/var/log/httpd/referer_log");
};
blippr("/private/var/log/httpd/referer_log", $indentation);
# no, do not increment the counters
$doincrement = 0;
# no, do not write to the overloads file
$writeoverload=0;
&processlog;
close ($outfile);
@data = ();

############ all done ############
print "\n\n";
exit 0 ;


# save the counter html file
sub savecounters {
  open ($countfile, ">$logpath");
  foreach $myarray_line(@counterdata) {
    print $countfile "$myarray_line";
    };
  close($countfile);
  };


# check if an entry exists for a record.  If it's there, increment it.  If not, create one.
sub incrementcounter {
  $count = 0;
  $checkline = $line;
  $checkline =~ s/\n//;
  $checkline =~ s/^.*] "//;
  $checkline =~ s/^.*GET //;
  $checkline =~ s/^.*POST //;
  $checkline =~ s/^.*HEAD //;
  $checkline1 = "";
  $checkline2 = "";
  $stop = 0;
  # grab the url from the log file entry
  for ($i=0; $i<length($checkline); $i++) {
    if ((substr($checkline,$i,1) eq " ") and ($stop == 0)) {
      $stop = 1;
      }
    else {
      if ($stop == 0) {
        $checkline1 = join("", $checkline1, substr($checkline,$i,1));
        }
      else {
        $checkline2 = join("", $checkline2, substr($checkline,$i,1));
        };
      };
    };
  $checkline1 =~ s/"//;
  $checkline2 =~ s/^.*\" //;
  $checkline2 = substr($checkline2,0,3);
  $#myarraydata2 = -1;
  $count = 0;
  $found = 0;
  if (($checkline2 eq "200") or ($checkline2 eq "302") or ($checkline2 eq "304")) {
    foreach $myarray_line(@counterdata) {
      $oldmyarrayline = join("",$myarray_line);
      $url = "<tr><td><a href=\"$checkline1\">$checkline1</a>:</td>";
      if (($found == 0) and (($myarray_line =~ m/$url/) or ($debug == 5))) {
        # found the record containing the url
        $oldmyarrayline =~ s/^.*<\/td><td>//;
        $oldmyarrayline =~ s/\n//;
        $oldmyarrayline =~ s/\r//;
        $oldmyarrayline =~ s/<.*$//;
        $count = $oldmyarrayline;
        $count++;
        $found = 1;
        $count = sprintf($pads, $count);
        $myarrayline = join("", $url, "<td>",$count,"</td></tr>\r\n");
        # put the line into an array instead of constant disk accessing
        # we'll save the array later
        $myarraydata2[++$#myarraydata2] = $myarrayline;
        }
      elsif (($count == 0) and (substr($myarray_line,0,8) eq "</table>")) {
        # didn't find the entry containing the url so create one
        $count++;
        $count = sprintf($pads, $count);
        $myarrayline = join("", $url, "<td>$count</td></tr>\r\n");
        $myarraydata2[++$#myarraydata2] = $myarrayline;
        $myarraydata2[++$#myarraydata2] = $myarray_line;
        }
      else {
        # we'll just pass these lines through
        $myarraydata2[++$#myarraydata2] = $myarray_line;
        };
      };
    # replace the old array with the one we just created
    @counterdata = @myarraydata2;
    }
  else {
    };
  };
  

# this is an old message routine from the old adventure game
sub blip {
  print $dot;
  $dotposition++;
  my $position = $dotposition;
  my $max = $maxdots;
  if ($position >= $max) {
    print "\n",$indentation;
    $dotposition = 0;
    };
  };
  
sub blippr {
  ($msg, $msg2) = @_;
  print "\n\n<",$msg,">\n",$msg2;
  $dotposition = 0;
  };

# this is where the meat comes in.  This handles all of the processing of the log.
sub processlog {
  $increment = 0;
  foreach $line(@data) {
    # tell the console we are doing another line
    if ($line =~ m/^0\D0\D0\D0\D.*/) {
      $dot = $marker;
      }
    else {
      $dot = $step;
      };
    blip;
    
    # filter out all search and connect because they are most likely overloads
    # designed to fill your logs and crash your web server.
    if (($line =~ m/^.*\"SEARCH.*\"/) or ($line =~ m/^.*\"CONNECT.*\"/)) {
      if ($writeoverload == 1) {
        print $overload $line;
        }
      }
    else {

      # increment counter if we already passed the mark where we last incremented it.
      # and are allowed to increment it
      if (($increment == 1) and ($doincrement == 1)) {
        &incrementcounter;
        };

      # here's where we last incremented the counter
      if ($line =~ m/^0\D0\D0\D0\D.*/) {
        $increment = 1;
        };

      # filter out the local net addresses (10.0.1.x and 192.168.1.x)
      if (($line =~ m/^10\D0\D1\D.*/) or ($line =~ m/^192\D168\D1\D.*/) or ($line =~ m/^0\D0\D0\D0\D.*/)) {

        # skip the local IPs and the marker
        }
      else {

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
        
        # save the entry back to the log file with all IP addresses listed
        # as 4 numbers of 3 digits each
        print $outfile $first,".",$second.".",$third,".",$fourth," ",$line;
        };
      };
    };

  # save the last location of the counter so we won't add previously added entries
  print $outfile $counterlocation;
  };
  
__END__

=head1 fixlog.pl

fixlog.pl - fix the Apache logs and count the URLs

=head1 DESCRIPTION

This program is designed to clean out the extraneous information from an Apache log file
It is suggested that you run it as a cron script with apache turned off.  Turning Apache
off is essential as Apache will just continue it's log file from the location it ended up
at and you'll have a whole lot of nulls in the resulting file if it's left on.  The program
usually runs for about 10-30 seconds max with 3 log files to process, much shorter with
only one log to process.

=head1 AUTHOR

Robert R. Dell xyzzy@cpan.org

=head1 README

This script scans through the site's access log and ensures all IP addresses are
4 sets of 3 digits, strips out extraneous information such as local accesses and
overloads (32k long SEARCH or CONNECT requests).

Apache must be turned off for this script to run as it modifies the log files.

It is suggested to run this script as a part of a root cron job script which would
turn off apache, run fixlog.pl, turn apache back on.

I have mine stored in /usr/bin where a simple fixlog.pl from the command line will
run this perl script.

chmod 0755 fixlog.pl


=head1 PREREQUISITES

The Apache web server and an access log.

=head1 COREQUISITES

shell, apache

This script works flawlessly with "getlog.cgi" and "getcount.cgi"

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

Web


=cut


