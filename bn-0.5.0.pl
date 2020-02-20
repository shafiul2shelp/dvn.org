#!/usr/bin/perl -w

#use diagnostics -verbose;
#############################################################################
# If you contribute to this script or alter it in some productive way please
# let me know so I can include it in the official release.
#
# Much thanks to Barnes and Noble bookstore for making it possible to find
# excellent books on Perl
#
# Much thanks to Larry Wall for Perl
#
# Much thanks and gratitude to my programming guru "LZ" (Hey, next time
# I'll try it in Tcl...)
#
#############################################################################


#############################################################################
#	Variables and Configuration Settings
#############################################################################

use strict;
use CPAN;
use Config qw(config_sh);
use File::Listing;
use Getopt::Long qw(GetOptions);
use LWP;
use LWP::UserAgent;
use LWP::MediaTypes qw(media_suffix);
use URI::URL qw(url);
use HTML::Entities ();
use HTML::Parse;
use HTML::FormatText;
use Business::ISBN qw(is_valid_checksum);

use vars qw(
	$HELP 
	$ISBN_SEARCH 
	$INFILE 
	$TITLE_SEARCH 
	$BARCODE 
	$OUTFILE 
	$HTML 
	$VERBOSE 
	$VERSION);

my $progname = $0;
$progname =~ s|.*/||;
$progname =~ s|.*\\||;
$progname =~ s/\.\w*$//;

my $VERSION = sprintf("%d.%d.%2d", q$Revision: 0.5.0 $ =~ /(\d+)\.(\d+).(\d+)/);
my $MAIL = qw"thebladerunner@xmission.com";

my $url = "";
my $post_title = qw"http://shop.barnesandnoble.com/booksearch/results.asp?TTL=";
my $post_isbn = qw"http://shop.bn.com/bookSearch/isbnInquiry.asp?isbn=";

my $in_method ="";
my $out_method ="";
my $v ="";

my $count = "";
my $ifts = "";
my $ifis = "";


#############################################################################
#	Code Section
#############################################################################

&file_check;

die (&usage) if (!(@ARGV));

GetOptions("version" => \&print_version,
	"help|h" => \&usage,
	"isbn|i|I=s" => \$ISBN_SEARCH,
	"title|t|T:s" => \$TITLE_SEARCH,
	"infile|in|IN:s" => \$INFILE,
	"barcode|b" => \$BARCODE,
	"outfile|o|O:s" => \$OUTFILE,
	"html:s" => \$HTML,
	"verbose" => \$VERBOSE);

$in_method = "1" if ($ISBN_SEARCH || $TITLE_SEARCH || $INFILE || $BARCODE);
$out_method = "1" if ($OUTFILE || $HTML || $VERBOSE);

unless ($in_method and $out_method) {
	print "\n\tAN INPUT AND AND OUTPUT METHOD MUST BE DEFINED\n";
	&usage;
	die;}

if ($VERBOSE){
$v = 1};

if ($ISBN_SEARCH){
print "\nDoing an ISBN search\n";
&get_info_from_isbn};

if ($TITLE_SEARCH){
print "\nDoing a Title search\n";
&get_info_from_title};

if ($INFILE){
print "\nDoing a search via $INFILE\n";
&get_info_from_infile};

if ($BARCODE){
print "\nDoing a search via ISBN Barcode\n";
&get_info_from_barcode};

if ($OUTFILE){
&save_to_outfile};

if ($HTML){
&save_to_html};

unlink "database.tmp";
unlink "tempfile.tmp";

#############################################################################
#	Subroutine Section
#############################################################################


#############################################################################
#
#	sub file_check #checks for prerequisit modules and installs them
#
#############################################################################
sub file_check{

print "\n\tChecking for required modules...\n";

my $str = "perl -MCPAN
		-MBarcode::Cuecat 
		-MBusiness::ISBN
		-MConfig
		-MFile::Listing
		-MGetopt::Long
		-MBusiness::ISBN
		-MLWP
		-MLWP::UserAgent
		-MLWP::MediaTypes
		-MURI::URL
		-MHTML::Entities
		-MHTML::Parse
		-MHTML::FormatText
		-MBusiness::ISBN
";
$str .= " -e 'exit;' ";
my $return = system ($str);
if ($return == 0) {
	print "\n\t...Required modules found\n";
	}else{
	print "\nThe required modules were not found on your system\n\n";
	print "Installing the required modules via CPAN\n";
		for my $mod (qw(Barcode::Cuecat Business::ISBN )) {
		my $obj = CPAN::Shell->expand('Module', $mod);
		if (!$obj) {die "\nUnable to connect... 
			\nPlease connect and try again\n";}
		$obj->install;
	}
}
}

#############################################################################
#	sub get_info_from_isbn
#############################################################################
sub get_info_from_isbn (){

my $isbn = $_[0];

$isbn = $ISBN_SEARCH if ($ISBN_SEARCH);

if ($BARCODE){
	open (TEMPFILE, "tempfile.tmp") 
		or die "\tcould not open data file\n";
	my @working_array = (<TEMPFILE>);
	while (@working_array){
		my $isbn = pop @working_array;
		print "\nProcessing ISBN code: $isbn\n\n";
		$url = $post_isbn . $isbn;
		print "url: $url\n" if $v;
		&post_method($url);
		close TEMPFILE;
	}
}
else{
$url = $post_isbn . $isbn;
print "url: $url\n" if $v;
&post_method($url);
}
}


#############################################################################
#	sub get_info_from_title
#############################################################################
sub get_info_from_title (){

my $title = $_[0];
$title = $TITLE_SEARCH if ($TITLE_SEARCH);

print "\nSearching for:\t$title\n" if $v;
$_ = $title;
$title =~ s/\s/\+/g;

$url = $post_title . $title;
print "url: $url\n\n" if $v;
&post_method($url);

}

#############################################################################
#	sub get_info_from_barcode
#############################################################################
sub get_info_from_barcode {
my $isbn;

open (TEMPFILE, "+>>tempfile.tmp") 
	or die "\tcould not open data file\n";
while(1){
	print "scan barcode now or \'q\' to quit\n\n";
	$isbn = <STDIN>;
	chomp($isbn);
	last if($isbn eq "q");
	$isbn = &Cue_Decrypt($isbn) if($isbn =~ /\./);
	$isbn =~ s/^978//;
	$isbn = substr($isbn,0,10);
	my $cs   = new Business::ISBN($isbn);
	$cs->fix_checksum();
	$isbn = $cs->as_string();
	$isbn =~ s/\-//g;

	print "ISBN code: $isbn\n\n";
	print TEMPFILE "$isbn\n";
}
close TEMPFILE;
&get_info_from_isbn;
}


#############################################################################
#	sub Cue_Decrypt #much thanks again to Larry Wall for this snippit
#############################################################################
sub Cue_Decrypt{
    $_ = shift;

    my @data = map {
        tr/a-zA-Z0-9+-/ -_/;
        $_ = unpack 'u', chr(32 + length()*3/4) . $_;
        s/\0+$//;
        $_ ^= "C" x length;
    } /\.([^.]+)/g;

    return($data[2]);
}

#############################################################################
#	sub get_info_from_infile
#############################################################################
sub get_info_from_infile($INFILE) {

my $isbn;
my $title;

open (IN, "<$INFILE") || die "\t\ncould not open $INFILE\n";
my @working_array = (<IN>);

while (@working_array){
	my $file = shift (@working_array);
	chop $file;
	($title, $isbn) = split (/,/,$file);

if ($isbn){
	$ifis = "1";
	&get_info_from_isbn($isbn);
}
elsif (!$isbn && $title){
	$ifts = "1";
	&get_info_from_title($title);

close (IN);   
}
}
}

#############################################################################
#	sub save_to_outfile
#############################################################################
sub save_to_outfile{

open (DATAFILE, "database.tmp") || die "\t\ncould not open data file\n";
open (OUT, ">$OUTFILE") || die "\t\ncould not create $OUTFILE\n";
print "\n\tSaving $OUTFILE\n";

my @working_array = (<DATAFILE>);
	while (@working_array){
		my $file = shift (@working_array);
		print OUT "$file";
	}
close (OUT);
close (DATAFILE);   
}
#############################################################################
#	sub print_version
#############################################################################
sub print_version{

print <<"EOT";
\nThis is version: $VERSION of ($progname)

Copyright 2002, Jason Carling.
$MAIL

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
EOT
	exit 0;
}

#############################################################################
#	sub usage 
#############################################################################
sub usage{

	die <<"EOT";

Usage: $progname [options] 
Usage: $progname --isbn 0123456789 --outfile foo.txt

Allowed options are:
	--help		prints this help page
	--version 	prints the version number

INPUTS
	-i --isbn 	"ISBN number" as a 10 or 13 digit ISBN number
	-t  --title 	"TITLE" (surround with quotes)
	-in --infile 	"FILENAME" as a tab seperated input file
	-b  --barcode	"BARCODE" accepts input via a CueCat barcode scanner

OUTPUTS
	-o  --outfile 	"FILENAME" as a tab seperated output text file
	-ht --html 	"FILENAME" as an html formatted output file
	--verbose 	print to STDOUT
EOT
}


########################################################################################
#	sub get_html: writes an html formated file 
#
#			This is formatted how I wanted to see it. If you want something
#			different to the HTML formatting just change it here.
#
########################################################################################
sub save_to_html (){

my $title = "";
my $price = "";
my $authors = "";
my $format = "";
my $publisher = "";
my $pub_date = "";
my $isbn ="";

print "\n\tSaving HTML file\n";

open (HTMLOUT, "+>>$HTML")
	or die "\tcould not open $HTML";

print HTMLOUT qq(<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<HTML><HEAD><TITLE>Perl BookSearch</TITLE>
<META http-equiv=Content-Type content="text/html; charset=windows-1252"><LINK 
href="null" rel=stylesheet>
<STYLE type=text/css>BODY {
	BACKGROUND: #000040
}
.para1 {
	MARGIN-TOP: -38px; FONT-SIZE: 30px; MARGIN-LEFT: 300px; COLOR: #e1e1e1; LINE-HEIGHT: 35px; MARGIN-RIGHT: 10px; FONT-FAMILY: font2, Arial; TEXT-ALIGN: left
}
.para2 {
	MARGIN-TOP: 15px; FONT-SIZE: 50px; MARGIN-LEFT: 15px; COLOR: #004080; LINE-HEIGHT: 40px; MARGIN-RIGHT: 50px; FONT-FAMILY: font1, Arial Black; TEXT-ALIGN: left
}

   BODY { 
    scrollbar-base-color : #003A7A;
    scrollbar-arrow-color : #FFCC00; 
    
    }

</STYLE>

</HEAD>
<BODY text=#ffffff bgColor=#000080 leftMargin=0 topMargin=0>
<DIV align=center>
<DIV class=para2 align=center>
<P>Perl BookSearch</P></DIV>
<DIV class=para1 align=center>
<P>Results</P></DIV></DIV>
<HR align=left width="80%" color=#ffbf00 noShade SIZE=1>
<DIV align=left>
<p>
<table cellpadding="2" cellspacing="2" width="90%">
  <tr>
<td valign="top" width="20%" font size="2" face="Arial"> <strong> Title: 
<td valign="top" width="10%" font size="2" face="Arial"> <strong> ISBN:
<td valign="top" width="8%" font size="2" face="Arial"> <strong> Price:
<td valign="top" width="15%" font size="2" face="Arial"> <strong> Authors:
<td valign="top" width="10%" font size="2" face="Arial"> <strong> Format:
<td valign="top" width="10%" font size="2" face="Arial"> <strong> Publisher:
<td valign="top" width="10%" font size="2" face="Arial"> <strong> Publication Date: 
</font>);

open (DATAFILE, "<database.tmp") 
	or die "\tcould not read data file";

my @working_array = (<DATAFILE>);

while (@working_array) {
	my $file = shift (@working_array);
#	chop ($file);
	($title, $isbn, $price, $authors, $format, $publisher, $pub_date) = split (/,/,$file);

print HTMLOUT qq(<tr><td>);
print HTMLOUT qq($title<td>$isbn<td>$price<td>$authors<td>$format<td>$publisher<td>$pub_date\n);

}; 

print HTMLOUT qq(</td></table><p>
<HR align=left width="80%" color=#ffbf00 noShade SIZE=1><p>
<center>mailto: <a href="mailto:thebladerunner\@hotmail.com">
thebladerunner</center><p>\n);

close HTMLOUT;
close DATAFILE;

}



#############################################################################
#	sub post_method
#############################################################################
sub post_method (){
	
my $title = "";
my $price = "";
my $authors = "";
my $format = "";
my $publisher = "";
my $pub_date = "";
my $isbn = "";
my $count = "";
my $start = "";
my @book;
my $search = "";
my $foo;

open (DATAFILE, "+>>database.tmp");


#############################################################################
if ($TITLE_SEARCH || $ifts){

if (!$url){die "\nNO URL FOUND\n";}

my $ua = new LWP::UserAgent;
$ua->agent("bn_perl_agent/0.5 " . $ua->agent);
my $req = new HTTP::Request GET => $url;
$req->content_type('application/x-www-form-urlencoded');
my $res = $ua->request($req);
my $content = $res->content;

$content =~ /vc_show_cartbutton\('(\d+)'\,2\)\;\/\/-->/;
$search = $1;
$count = 1;
}


#############################################################################
if ($ISBN_SEARCH || $BARCODE || $count || $ifis){
$url = "http://shop.bn.com/bookSearch/isbnInquiry.asp?isbn=$search" if $count;

if (!$url){die "\nNO URL FOUND\n";}
my $ua = new LWP::UserAgent;
$ua->agent("bn_perl_agent/0.5 " . $ua->agent);
my $req = new HTTP::Request GET => $url;
$req->content_type('application/x-www-form-urlencoded');
my $res = $ua->request($req);
my $content = $res->content;
my @content = split("\n", $content);
my $start = "";

foreach (@content){
        if(/<!-- content cell -->/){ $start++; }

        if($start){
            s/\ / /g;
            my $foo = HTML::FormatText->new->format(parse_html($_));

last if ($foo =~ /If you are still unable to locate this book/gi);
            if($foo !~ /^\s+$/){
                if($foo !~ /IMAGE/){
                    if($foo !~ /TABLE NOT SHOWN/){
                        push(@book, $foo);
                    }
                }
            }
            if(/Pub\. Date/) { $start = 0; }
        }
    }

$title   = $book[0];
$authors = $book[1];
$authors =~ s/editor//gi;
$authors =~ s/\(\)//gi;

    chomp($title);
    chomp($authors);


    foreach(@book){

        if(/Retail Price:/){
            $price = $_;
            $price =~ s/^\W*Retail Price://;
            $price =~ s/^\s+//;
            $price =~ s/,/ /g;
            chomp($price);
        }elsif(/Our Price:/){
            $price = $_;
            $price =~ s/^\W*Our Price://;
            $price =~ s/^\s+//;
            $price =~ s/,/ /g;
            chomp($price); }

        if(/Format:/){
            $format = $_;
            $format =~ s/^\W*Format://;
            $format =~ s/^\s+//;
            $format =~ s/,/ /g;
            chomp($format);
        }
        if(/Publisher:/){
            $publisher = $_;
            $publisher =~ s/^\W*Publisher://;
            $publisher =~ s/^\s+//;
            $publisher =~ s/,/ /g;
            $publisher = ~s/O\'Reilly & Associates Incorporated/O\'Reilly/;

	# I made this last change because the whole O'Reilly name 
	# took up too much space on screen. My apologies to Tim.

            chomp($publisher);
        }
        if(/Pub\. Date:/){
            $pub_date = $_;
            $pub_date =~ s/^\W*Pub\. Date://;
            $pub_date =~ s/^\s+//;
            $pub_date =~ s/,/ /g;
            chomp($pub_date);
        }
        if(/ISBN:/){
            $isbn = $_;
            $isbn =~ s/^\W*ISBN://;
            $isbn =~ s/^\s+//;
            chomp($isbn);
		}
    }


print<<BOOK;
Title:        $title
ISBN:         $isbn
Price:        $price
Author(s):    $authors
Format:       $format
Publisher:    $publisher
Publish Date: $pub_date

BOOK

print DATAFILE "$title, $isbn, $price, $authors, $format, $publisher, $pub_date\n";
close (DATAFILE);

}
}
############################################################################
#	POD section: Plain Old Documentation 
############################################################################

=head1 NAME

bn.pl - Perl Book Search


=head1 SYNOPSIS

perl bn.pl [OPTIONS]

=head1 DESCRIPTION

bn is a Perl bot for searching book / media information and saving the 
output as either a comma seperated text file or in HTML format.

This script will accept input in any of the following forms:

ISBN: Search for a single ISBN from the command line.
TITLE: Search for a single title surrounded with "".
INFILE: Input as TITLE, ISBN (or one or the other) seperated by a comma. 
BARCODE: Search via barcode (essentially STDIN, ISBN or UPC).

For barcode scanning I use an old CueCat from Radio Shack.

The script will then search for information on the book or media entered 
(at the Barnes and Noble website) based on the input you provide. The 
information gathered can be saved and output as a CSV formatted text file an
HTML formatted or to STDOUT. (Or you can pipe it to something else if
you want.)

I use this program for two reasons. First it makes it really easy to 
search for book titles that I want to buy. I happen to like Fatbrain{*} 
which is now owned by Barnes and Noble. Second, I have a somewhat large 
book collection and this has made it much easier to create a database 
of my library for kicks and for insurance purposes. 

I wanted to create a database in PostgreSQL but the main machine I work 
on is a Windows box and I had trouble getting PostgreSQL to work 
(most of Cygwin works great. I just couldn't get the database to work 
as I expected.) It wouldn't be very hard to change this script so that 
it would create a database in whatever flavor of database you choose. 
I have extended the basic core of the script to work with CD's and DVD's 
and a different web site. 

=head1 OPTIONS

Options marked with an asterisk (*) require no additional input
Other options require a value after the option

--help *(prints this help page)
--isbn number 	(ISBN number to search)
--title "title"	("title search" - surround with quotes)
--infile filename (input file CSV)
--barcode scan	(barcode input - I use the Cuecat from Radio Shack)
--outfile filename (output text file)
--html filename (html formatted file)
--verbose *(noisy output to STDOUT)
--version *(version info)

=head1 FEATURES

Ability to search for book information via "title", "ISBN" or barcode scan from
the command line. Save output as a txt, HTML file or to STDOUT.

=head1 SCRIPT CATEGORIES

Web

=head1 OSNAMES

MSWin32
Linux

=head1 AUTHOR

Jason Carling  <thebladerunner@xmission.com>. 

=head1 COPYRIGHT

Copyright Jason Carling, 2002. Licenced under the Perl Artistic License.

=head1 README

bn is a Perl bot for searching book / media information and saving the 
output as either a comma seperated text file or in HTML format.

=cut
