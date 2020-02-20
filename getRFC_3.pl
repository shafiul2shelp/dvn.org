#!/usr/bin/perl -w
use Socket;
use strict;
$main::SIG{'INT'} = 'closeSocket';

my $VERSION = 0.2;
my($protocol)      = getprotobyname("tcp")|| 6;
my($port)       = 80;
my($serverAddr) = (gethostbyname("proxy..."))[4];

socket(SMTP, AF_INET(), SOCK_STREAM(), $protocol)
    or die("socket: $!");

my($packFormat) = 'S n a4 x8';   # Windows 95

connect(SMTP, pack($packFormat, AF_INET(), $port, $serverAddr))
    or die("connect: $!");

 my($len)=$#ARGV;
 my($inc)=0;
 
 if ($len < 0)
 {
        print ("\n Usage rfc.pl xxxx [xxxx,xxxx...] \n xxxx is rfc number \n The utility uses faqs.org to get RFC's\nBy Naunidh Singh Chadha (naunidh[at]gmail[dot]com)\n");
        exit;
 }
 #Start Leeching......
  for ($inc = 0; $inc <= $len ; $inc++) 
  {  
    my($rfcNum)=$ARGV[$inc];
    #Create the file name and create output file.
    my ($filename)=$rfcNum . ".txt";    
    open OUTFILE, ">$filename";     
    
    my($buffer) = "GET http://www.faqs.org/rfcs/rfc" . $rfcNum . ".html HTTP/1.0\x0d\x0aAccept: */*\x0d\x0aProxy-Connection: Keep-Alive\x0d\x0aHost: www.faqs.org\x0d\x0aUser-Agent: Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; .NET CLR 1.1.4322)\x0d\x0a\x0d\x0a";
    my($flag)=1;
    send(SMTP, $buffer, 0); 
    my($final)="";     
    while ($flag==1)
      {
          recv(SMTP, $buffer, 50000, 0);                       
		  #Test for </HTML> meaning end of file for us 
		  #I didnt want to count the number of bytes received :))
          if ($buffer =~ /<\/HTML>/)
          {
          $flag=0; 
          }
          $final .= $buffer;
      }      
	  #Put all that is in between <PRE> </PRE> tags into a txt file. Works for all the rfc's I have tested.
      if($final =~ /<PRE>(.*)<\/PRE>/s)
      { 
        print OUTFILE $1;    
      } 
     #Close the file and go up to fetch a new RFC.
    close OUTFILE;
  }    
    close(SMTP);

sub closeSocket {     # close smtp socket on error
    close(SMTP);
    die("SMTP socket closed due to SIGINT\n");
}

=pod

=head1 NAME

getRFC - This script downloads RFC's from faqs.org and put them in the current directory. 

=head1 DESCRIPTION

Just pass on the RFC numbers to the script as arguments and it will zap them all in a directory leaching them one by one in batch mode.

For bugs/corrections contact naunidh [at] gmail [dot] com

=pod OSNAMES

Linux
Windows

=pod README

getRFC - This script downloads RFC's from faqs.org and put them in the current directory. 
Just pass on the RFC numbers to the script as arguments and it will zap them all in a directory leaching them one by one in batch mode.
For bugs/corrections contact naunidh [at] gmail [dot] com

=pod SCRIPT CATEGORIES

Web
Win32/Utilities

=cut
