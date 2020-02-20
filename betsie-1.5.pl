#!/usr/local/bin/perl

# parser.pl v 1.5 - 16th December, 1999
# by wayne.myers@bbc.co.uk (et al)
# Enormous thanks to:
# Chay Palton, Damion Yates, Matt Blakemore, Dan Tagg, T.V. Raman, Mark Foster
# and many others.

# parser.pl aka BETSIE is Copyright 1998,1999 BBC Digital Media
# See licence.txt for full licence details
# See readme.txt for more information
# These documents and more are available on the Betsie website:
# http://www.bbc.co.uk/education/betsie/

# Changes: 1.5
# 1 - Made move_nav a seperate subroutine
# 2 - Fixed anchors bug in auto-detected referers
# 3 - Cleaned up code some.
# 4 - Added some notion of changeable settings

# modules

use Socket;
#use strict;

# variables

my $VERSION = "1.5";	# version number
my @x = ();         	# this array holds all the lines of the html page we're parsing
my $contents = "";  	# this string is @x concatenated
my $inpath = "";    	# this is the path_info string from which we get the rest
my $root = "";      	# this is the domain of the page we are looking at
my $path = "";      	# this is the path of the page we are looking at
my $file = "";      	# this is the name of the file we are looking at
my $postdata = "";  	# this is any POST method data
my $method = "GET"; 	# and remains this way unless we get POST data
my $length = -1;    	# but is the length of content if any greater in a POST
my $count;				# counter for main request loop
my $httptype;			# http type of request
my $code;				# http return code
my $msg;				# http message
my $newurl;				# used to store redirect target
my $tag;				# used to store meta redirect tags
my $loop_flag;			# flag used to make sure we get the right page
my $script_flag;    	# flag used to see if we are in script tags or not
my $ws_flag;			# flag used to minimise unnecessary white space
my $set = 0;            # is 1 if we want the settings page
my $body; 				# holds the body tag

# VARIABLES YOU MIGHT WANT TO CHANGE:

my $maxpost = 65536; # is maximum number of bytes in a POST
my $parsehome = "http://www.bbc.co.uk/education/betsie/";
my $name = "betsie-1.5.pl";					# name of this file
my $agent = $ENV{'HTTP_USER_AGENT'};	# pretend to be the calling browser

# variables for colour/font settings etc
# be sure to amend make_body() if you amend them
my $setstr = "/0005";	# is default string for settings.
my $chsetstr = "/1005";  # string used for default change settings page
# next five arrays are for each set of colour options. feel free to add to or amend these.
my @bg = qw(#000000 #FFFFFF #0000FF #FFFFCC);
my @text = qw(#FFFF00 #000000 #FFFFFF #000000);
my @link = qw(#00FFFF #0000FF #FFFFCC #0000FF);
my @vlink = qw(#00CCFF #0000CC #FFFF99 #0000CC);
my @alink = qw(#FFFF00 #000000 #FFFFFF #000000);
# ten fonts. again, you can change these if you like
my @font_face = ("Verdana, Arial", "Times", "Courier", "Helvetica", "Arial",
				 "Bookman Old Style", "Geneva", "Chicago", "Courier New", "System");


# VARIABLES YOU MUST SUPPLY:

my $pathtoparser = "http://$ENV{'SERVER_NAME'}/cgi-bin/education/betsie/$name";
#my $pathtoparser = "http://localhost/cgi-bin/betsie/$name";
my $parsecontact = "education.online\@bbc.co.uk";
my $localhost = "www.bbc.co.uk";
my @safe = qw (	bbc.co.uk
				beeb.com
				bbcworldwide.com
				bbcresources.com
				bbcshop.com
				radiotimes.com
				open.ac.uk
				open2.net
				freebeeb.net
				);

# VARIABLES YOU (PROBABLY) DON'T WANT TO TOUCH:

my ($rec_test) = $pathtoparser =~ /^http:\/(.*)$/;	# var to solve recursion problem

# Set alarm handler (comment this out on systems that can't handle it)
alarm 10;
$SIG{ALRM} = \&alarm;

# main loop

$|=1;
print "Content-type: text/html\n\n";

# handle POST requests

if ($ENV{'REQUEST_METHOD'} eq "POST") {

  $length = $ENV{'CONTENT_LENGTH'};

  if ($length > 65536) {
    $x[0] = "Too much data for POST method.";
    error();
    exit;
  }

  if ($length) {

    read(STDIN, $postdata, $length, 0);
    $method = "POST";

  }
}

# take path info or referer allowing easy linking in...
$inpath = $ENV{'PATH_INFO'} || $ENV{'HTTP_REFERER'};
# strip http/ftp/gopher etc scheme if present (ie came from referer)
$inpath =~ s/^\w+:\///;

# Uncomment the following ugly hack for servers that don't do PATH_INFO properly 
# (if you couldn't do alarm above, you probably need this too :( )
# $inpath =~ s/^.*?$name//;

unless ($inpath =~ /^[a-zA-Z0-9_.\-\/\#]+$/) {
  $x[0] = "Unknown error";
  error();
  exit;
}

# beat recursive betsie bug

$inpath =~ s/^$rec_test//i;

# get optional settings string
$inpath =~ s#(\/\d+)\/#\/#;
$setstr = $1 || "/0005";
if (length $setstr != 5) { $setstr = "/0005"; }
$chsetstr = $setstr;
$chsetstr =~ s/^\/(\d)/\/1/;
if ($1 eq "1") { $set = 1;};

($root, $path, $file) = urlcalc($inpath);

unless (safe("http:\/\/$root")) {
  $x[0] = "<A HREF=\"http:\/\/$root$path$file\">http:\/\/$root$path$file<\/A> not on safe list. Sorry";
  error();
  exit;
}

$loop_flag = 0;
$count = 0;

LOOP: while ($loop_flag == 0) {

  $count++;
  if ($count == 9) {
    $x[0] = "Too many times through the loop.";
    error();
    exit;
  }

  if ($ENV{'QUERY_STRING'} ne "") { $file .= "\?$ENV{'QUERY_STRING'}" }

  @x = graburl($root, $path . $file);
  $contents="";

  foreach (@x) {
     $contents .= $_;
  }

  # handle http codes
  # 3xx we follow the redirect
  # anything other than 200 is an error.

  ($httptype, $code, $msg) = split /\s+/, $x[0];

  if ($code =~ /^3\d\d/) {
    $contents =~ s/^.*Location:\s+(\S+)\s.*$/$1/s;
    $newurl = $contents;
    redir();
    next LOOP;
  }

  if ($code !~ /200/) {
    error();
    exit;
  }

  # check for autoredirects of all sorts

  if ($contents =~ /(<META[^>]*?HTTP-EQUIV[^>]*?REFRESH[^>]*?>)/is) {
    $tag = $1;
    unless ($tag =~ /content=\"\d{3,}/is) {     # only deal with refreshes of 99 secs or less
      if ($tag =~ /url=(.*?)\"/is) {            # don't refresh if no url given
        $newurl = $1;
        unless ($file =~ /$newurl$/) {         # don't refresh to same page
          redir();
          next LOOP;
        }
      }
    }
  }
  
  # if we got here we must have got something and can end the loop

  $loop_flag = 1;

}

	# make the body tag
	$body = make_body();

	# if we're on the settings page, send that and exit
	if ($set != 0) {
		print <<HTML;	
<HTML>
<HEAD>
<TITLE>Betsie Settings Page</TITLE>
<META NAME="ROBOTS" CONTENT="NO INDEX, NO FOLLOW">
</HEAD>
$body
</BODY>
</HTML>
HTML

		exit;
		}

  # we're not on the settings page. call parser routines

  $contents = preparse($contents);

  @x = split /\n/, $contents;

  $contents = "";

  # start sending

  $script_flag = 0; # it will be 1 if we are in <SCRIPT> tags
  $ws_flag = 0;   # it will be 2 if we just printed a second <BR> in a row

  for (@x) {
    $contents = parse($_);
    unless ((!$contents) || ($script_flag == 1) || ($contents =~ /^\s+$/s) || (($ws_flag > 1) && ($contents =~ /^(\s*<BR[^>]*?>\s*)+$/is))) {
        print $contents;
        if ($contents !~ /<BR[^>]*?>\s*$/is) { $ws_flag = 0; }
        unless ($contents =~ /\n$/) { print "\n"; }
    }
    if ($contents =~ /<BR[^>]*?>\s*$/is) { $ws_flag++; }
  }


# subroutines

# redir
# handles redirects.
# assumes $newurl contains the new url to redirect to...

sub redir {

  # case 1 - it begins with /

  if ($newurl =~ /^\//) {
    $newurl = "\/" . $root . $newurl;
    ($root, $path, $file) = urlcalc($newurl);
    return;
  }

  # case 2 - it's the full path

  if ($newurl =~ /^http/) {
    $newurl =~ s/^http:\///;
    ($root, $path, $file) = urlcalc($newurl);
    return;
  }

  # case 3 - it's a filename

  if ($newurl =~ /^(\w|-|_)+\.\w+$/) {
    $file = $newurl;
    return;
  }

  # case 4 - it's a relative path

  if ($newurl =~ /[(\w|-|_)+\/]*(\w|-|_)+\.\w+/) {
    $path .= $newurl;
    $path =~ s/\/((\w|-|_)+\.\w+)$/\//;
    $file = $1;
    $path =~ s#\/(\w|-|_)+\/\.\.##g;
    return;
  }

  # case 5 - the ones i haven't thought of...

  $x[0] = "Unknown redirect - $newurl";

  error();
  exit;

}

# error
# displays error page with message

sub error {

print <<HTML;
<HTML>
<HEAD>
<TITLE>Betsie Error Page</TITLE>
</HEAD>
$body
<P>Sorry, but Betsie was unable to find the page at http://$root$path$file.

<P>The error was as follows: $x[0].

<P>If you have just found a bug in Betsie (it's possible), please email the details
to <A HREF=\"mailto:$parsecontact\">$parsecontact</A>

<P><A HREF=\"$parsehome\">Return to the Betsie
homepage</A>, or select your browser's 'back' button (or equivalent) to return to the
page you just came from.

<P>Inpath: $inpath
<P>Root: $root
<P>Path: $path
<P>File: $file
<P>Contents: $contents

</FONT>
</BODY>
</HTML>
HTML

}


# graburl
# homebrewed page grabber thing. gets remote page.

sub graburl {
  my ($host, $file) = @_;

  my ($remote, # the name of the SMTP server
      $port,   # the mail port
      $iaddr, $paddr, $proto, $line); # these vars used internally

  $remote  = $host;
  $port    = 80;

  #DMY
  if ($host eq "www.bbc.co.uk") {
    $host = "localhost";
  }

  unless ($iaddr   = inet_aton($remote)) {
    warn "no host: $remote";
    return ("Error: no host", "$!");
  }


  $paddr   = sockaddr_in($port, $iaddr);
  $proto   = getprotobyname('tcp');
  select(SOCK);
  $| = 1;

  unless (socket(SOCK, PF_INET, SOCK_STREAM, $proto)) {
    warn "socket: $!";
    return ("Error: socket problem", "$!");
  }

  unless (connect(SOCK, $paddr)) {
    warn "connect: $!";
    return ("Error: connection problem", "$!");
  }

  select(STDOUT);

  print SOCK "$method $file HTTP/1.0\n";
  print SOCK "Accept: */*\n";
  print SOCK "User-Agent: $agent\n";
  print SOCK "Host: $host\n";
  if ($length > -1) { print SOCK "Content-Length: $length\n"; }
  print SOCK "\n";
  if ($length > -1) {
    print SOCK "$postdata\n";
  }

#  sleep(5);

  @x = <SOCK>;

  unless (close (SOCK)) {
    warn "close: $!";
    return ("Error: problem closing socket", "$!");
  }

  $method = "GET";
  $length = -1;
  $postdata = "";

  return @x;

}

# parser routines

# preparse
# preparses take the whole page and does the bits that need the whole of the page

sub preparse {

	my $page = shift;

	# preparsing:

	# remove http header lines and insert missing html/body tags
	
	if ($page !~ /<HTML>/is) {
		$page =~ s/^(.+?)\n\n/<HTML>/s;
	} else {
		$page =~ s/.*?<HTML>/<HTML>/is;
	}

	if ($page !~ /<\/HTML>/is) {
		$page .= "<\/HTML>";
	}

    if ($page !~ /<FRAMESET/is) {    # don't do this to frames pages

		if ($page !~ /<\/BODY>/is) {
			$page =~ s/<\/HTML>/<\/BODY>\n<\/HTML>/is;
		}

		if ($page !~ /<BODY/is) {						# if there's no body tag
			if ($page =~ /<\/HEAD>/is) {					# look for an end head tag
				$page =~ s/<\/HEAD>/<\/HEAD>\n<BODY>/is;	# put body tag there if we find it
			} else {
				if ($page =~ /<\/TITLE>/is) {			# if we don't find end head look for end title
					$page =~ s/<\/TITLE>/<\/TITLE><\/HEAD>\n<BODY>/is;	# insert both end head and body start
				} else {
					$page =~ s/<HTML>/<HTML><HEAD><TITLE>$root$path$file<\/TITLE><\/HEAD><BODY>/is;
					# this is clumsy, true, but so is the code it's trying to fix.
				}
			}
		}

	}

	# now we have a head we can look out for and exclude robots.
	$page =~ s/(<\/HEAD>)/<META NAME="ROBOTS" CONTENT="NO INDEX, NO FOLLOW">\n$1/is;

	# remove stylesheets part 1

	$page =~ s/<STYLE.+?<\/STYLE>//gis;

	# remove java

	$page =~ s/<APPLET.+?<\/APPLET>/<P>Java applet removed\.\n/gis;

	# put MAPs in BODY (later on AREAs become As...)
# beginning of body?	
#	while ($page =~ s/<MAP[^>]*?>(.*?)<\/MAP>(.*?<BODY[^>]*?>)/$2\n$1/is) {};
# or end of body...
	while ($page =~ s/<MAP[^>]*?>(.*?)<\/MAP>(.*)(<\/BODY>)/$2\n$1\n$3/is) {};


	# remove all extraneous whitespace and newlines in tags

	$page =~ s/\s+=/=/gs;
	$page =~ s/=\s+/=/gs;
	$page =~ s/<\s+([^>]+)>/<$1>/gs;
	$page =~ s/<([^>]+)\s+>/<$1>/gs;
 # $page =~ s/<([^>]+?)\s+>/<$1>/gs;
	while ($page =~ s/<([^>]+)\n([^>]+)>/<$1 $2>/gs) {}
 # $page =~ s/<([^>]+?)\n([^>]+?)>/<$1 $2>/gs;
	while ($page =~ s/<([^>]+?)\s{2,}([^>]+)>/<$1 $2>/gs) {}
	
	# remove empty links - mucho ta to Matt Blakemore for suggesting this one
	
	$page =~ s/<A[^>]*HREF\s*\=\s*[^>]*>\s*<IMG[^>]*ALT\s*\=\s*\"\"[^>]*>\s*<\/A>//gis;

	# go to move_nav and move the nav
	
	$page = move_nav($page);  

	# remove hidden javascript. and comments. (sorry).

	$page =~ s/<!--.*?-->//gs;

  # make sure no two tags are on same line

  $page =~ s/(>)([^\n|=])/$1\n$2/gs;

  # remove blank lines

  #$page =~ s/\n\n/\n/gs;
  $page =~ s/\s{2,}/\n/gs;
  return $page;
}

# move_nav
# moves the nav bar around
# this one is for the BBC site. your site may need a whole different one...

sub move_nav {

	my $page = shift;
	
	if ($root =~ /\.bbc\.co\.uk$/) {

    # first make sure all table widths have double quotes

    $page =~ s/(<T[^>]*?)WIDTH=(\d+)/$1WIDTH="$2"/gis;
  
    for ($root) {

      /^news/ and do {
    
                  # news nav mangling - sits in a table width 90 pixels... Or 100 pixels. Depends on the template.

                  $page =~ s/(.*?)<TABLE([^>]*?)WIDTH=["|']?(?:90|100)["|']?.*?>(.*?)<\/TABLE>(.*)<\/BODY>/$1$4$3<\/BODY>/is;

                  last;

                  };

      /^www/  and do {
    
                  # normal or worldservice...

                  if ($path =~ /worldservice|arabic|cantonese|mandarin|russian|spanish|ukrainian/) {

                      # world service nav mangling - sits in a td width 98 pixels and followed by td width 1 pixel
                      # but mileage varies, hence all the \d's...

                      $page =~ s/(.*?)<TD([^>]*?)WIDTH=["|'](?:9\d|1\d\d)["|'].*?>(.*?)<TD([^>]*?)WIDTH=["|']\d["|'].*?>(.*)<\/BODY>/$1$5$3<\/BODY>/is;

                  } elsif ($path =~ /^\/news\//) {

                      # news nav mangling - sits in a table width 90 pixels... Or 100 pixels. Depends on the template.

                      $page =~ s/(.*?)<TABLE([^>]*?)WIDTH=["|'](?:90|100)["|'].*?>(.*?)<\/TABLE>(.*)<\/BODY>/$1$4$3<\/BODY>/is;

                  } else {

                    # deal with old education navbar

                    last if ($page =~ s#(<A HREF=\"\/education\/nav\/bbcedbar\.map\">).*?(</A>)#$1BBC Education$2#is);
                      
                    if ($page =~ /<!--\s+GLOBALNAVBEGIN/s) {

                      	# code for new templates here -->
                      	$page =~ s/(.*?)<!--\s+GLOBALNAVBEGIN[^>]+?>(.*?)<!--\s+SERVICESNAVEND\s+-->(.*)<\/BODY>/$1$3$2<\/BODY>/is;
 
                    } else {
                      
                      	# Old standard navs. Should be 107 and 3 pixels, but you never know...
                    	$page =~ s/(.*?)<TD([^>]*?)WIDTH=["|']1\d\d["|'].*?>(.*?)<TD([^>]*?)WIDTH=["|']\d["|'].*?>(.*)<\/BODY>/$1$5$3<\/BODY>/is;

					}
					

                  }

                  last;

                  };
 
		# i don't know where we are, here, but lets try for standard nav bars anyway...
		if ($page =~ /<!--\s+GLOBALNAVBEGIN/s) {
           	# code for new templates here -->
           	$page =~ s/(.*?)<!--\s+GLOBALNAVBEGIN[^>]+?>(.*?)<!--\s+SERVICESNAVEND\s+-->(.*)<\/BODY>/$1$3$2<\/BODY>/is;
		} else {
            # Old standard navs. Should be 107 and 3 pixels, but you never know...
            $page =~ s/(.*?)<TD([^>]*?)WIDTH=["|']1\d\d["|'].*?>(.*?)<TD([^>]*?)WIDTH=["|']\d["|'].*?>(.*)<\/BODY>/$1$5$3<\/BODY>/is;
		}
    }
  }
	
	
	return $page;	
	
}

# parse
# handles the line-by-line bits of betsification

sub parse {

	my ($line) = shift;
	my $link;
	my $alt;    # used in area tag handler
	my $target; # ditto

	$line =~ s/click here/select this link/gis;

	# nuke javascript event handlers

	while ($line =~ s/(<[^>]*?)(\s+on\S+?=\".*?\")+(.*?>)/$1 $3/i) {}; # dbl quotes
	while ($line =~ s/(<[^>]*?)(\s+on\S+?=\'.*?\')+(.*?>)/$1 $3/i) {}; # sgl quotes
	while ($line =~ s/(<[^>]*?)(\s+on\S+?=\S+?)(>)/$1 $3/i) {};     # no quotes. naughty!

    # lose inline stylesheeting

    $line =~ s/(<[^>]*?)STYLE\s*=\s*\".*?\"/$1/gis;

    # lose arbitrary justification arbitrarily

    $line =~ s/(<[^>]*?)ALIGN\s*=\s*\".*?\"/$1/gis;

    # S T O P   P E O P L E   L I K E   T H I S (thanx to T.V.Raman for the suggestion)

    if ($line =~ /(\w ){3,}/) {
    	$line =~ s/(\w) /$1/g;
    }

	my $tag = "";
	($tag) = $line =~ /<(\S+)[^>]*?>/;
	if ($tag eq "") { return $line; }
	$tag = uc $tag;

	for ($tag) {

	# handle javascript script
	
		/NOSCRIPT/		 and do {
									 $line =~ s/<(?:\/)?NOSCRIPT[^>]*?>//gis;	 
									 last;
								 };

		/SCRIPT/ and do {
							if ($line =~ /<SCRIPT/i) {
								$script_flag = 1;
								$line =~ s/<SCRIPT.*$//gis;
							} elsif ($line =~ /<\/SCRIPT/i) {
								$line =~ s/^.*?<\/SCRIPT>//i;
								$script_flag = 0;
							}
							last;
						 };
						 
	# lose NOBR

		/NOBR/   and do {
							$line =~ s/<(?:\/)?NOBR>//gis;
							last;
						};

	# lose link rel=stylesheet *only*

		/LINK/   and do {
							if ($line =~ /REL\s*=\s*\"?stylesheet\"?/gis) {
								$line =~ s/<LINK[^>]*?>//gis;
							}
							last;
						};

	# lose that deprecated CENTER tag!

		/CENTER/		 and do {
									 $line =~ s/<(?:\/)?CENTER[^>]*?>//gis;	 
									 last;
								 };


	# nuke all fonts

		/FONT/	 and do {
									 $line =~ s/<(?:\/)?FONT[^>]*?>//gis;
									 $line =~ s/<(?:\/)?BASEFONT[^>]*?>//gis;
									 last;
								 };

		/BASE/	 and do {
		
									 if (($link) = $line =~ /<BASE[^>]+?HREF\s*=\s*(\S+)[^>]*?>/i) {
										 $link =~ s/\"//g;
										 $link =~ s#^http:\/##i;
										 ($root, $path) = urlcalc($link);
									 }

									 last;
								 };
								 
	# lose layers

		/LAYER/	and do {
									 $line =~ s/<(?:\/)?LAYER[^>]*?>//gis;
									 last;
								 };
								 
	# lose divs

		/DIV/	and do {
									 $line =~ s/<(?:\/)?DIV[^>]*?>//gis;
									 last;
								 };
	# detableiser

		/TABLE/	and do {
									 $line =~ s/<(?:\/)?TABLE[^>]*?>//gis;
									 last;
								 };
		/TR$/		 and do {
									 $line =~ s/<(?:\/)?TR[^>]*?>//gis;	 
									 last;
								 };
		/TD$/		 and do {
									 $line =~ s/<\/TD>//gis;
									 $line =~ s/<TD.*?>/<BR>/gis;
									 last;
								 };

	# link masher

		/^A$/		 and do {

									# get the link out and remove any quoting
										($link) = $line =~ /<A[^>]+?HREF\s*=\s*(\S+)[^>]*?>/i;
										$link =~ s/\"//g;
										$link =~ s/\'//g;
										last if ($link =~ /^\#/);	 # ignore anchors

										$line =~ s/\s*=\s*/=/;

									# check for URL passing scripts and make them external
									# this should fix webguide and all other script based
									# URL passers for whom A HREF is just too easy... :)
									# note that URLs automatically end if an & is present. For some reason. ;)

										if ($link =~ m#\?.*?http(:|CHR\(58\))\/\/#i) {

											$link =~ s/CHR\(58\)/:/gi;
											$link =~ s/.*?(\?.*)/$1/;
											$link =~ s#^\?.*?(http:\/\/.*)$#$1#i;
											$link =~ s/&.*$//;
											unless (safe($link)) {
												$line =~ s#(<A[^>]+?HREF=)\S+([^>]*?>)#$1$link$2 (External)#i;
												last;
											}
										}

										# handle real audio

										if ($link =~ /\.(ram|rm|ra)$/i) {
											if ($link =~ /^http:/i) {
												last;
											}
											if ($link =~ /^\//) {
												$link = "http:\/\/" . $root . $link;
												$line =~ s/(<A[^>]+?HREF=)\S+([^>]*?>)/$1"$link"$2/i;
												last;
											}
											$link = $root . $path . $link;
											$link =~ s#\/\w+\/\.\.\/#\/#g;
											$link = "http:\/\/" . $link;
											$line =~ s/(<A[^>]+?HREF=)\S+([^>]*?>)/$1"$link"$2/i;
											last;
										}

									# handle fully qualified links

										if ($link =~ /^\w+:/) {
											unless (safe($link)) {
												$line =~ s/(<A[^>]+>)/$1 (External)/i;
												last;
											}
											if ($link =~ /^http/i) {
												$link =~ s/^http:\/(\/.*)$/$pathtoparser$setstr$1/i;
												$line =~ s/(<A[^>]+?HREF=)\S+([^>]*?>)/$1"$link"$2/i;
											} elsif ($link =~ /javascript:/) {
													$line =~ s/<A[^>]+>/<A HREF="">/i;
											}
											last;
										}

									# now the slash led links

										if ($link =~ /^\//) {
											$link = $pathtoparser . "$setstr" ."\/". $root . $link;
											$line =~ s/(<A[^>]+?HREF=)\S+([^>]*?>)/$1"$link"$2/i;
											last;
										}

									# now the rest of them

										$link = "\/" . $root . $path . $link;
										$link =~ s#\/\w+\/\.\.\/#\/#g;
										$link = $pathtoparser. "$setstr" . $link;
										$line =~ s/(<A[^>]+?HREF=)\S+([^>]*?>)/$1"$link"$2/i;
										last;
									};

/^AREA$/			and do {
									
									# get the link out and remove any quoting
										($link) = $line =~ /<AREA[^>]+?HREF\s*=\s*(\S+)[^>]*?>/i;
										$link =~ s/\"//g;
										$link =~ s/\'//g;
										last if ($link =~ /^\#/);	 # ignore anchors

									# get ALT out

										($alt) = $line =~ /<AREA[^>]+?ALT\s*=\s*\"(.*?)\"[^>]*?>/i;

										$alt = $alt || $link;  # so non-ALT tagged stuff sort of works...

									# get TARGET out (if present) - we don't need to do this elsewhere
									# because it's retained, but here we're rewriting the whole tag...

										($target) = $line =~ /<AREA[^>]+?TARGET\s*=\s*\"(.*?)\"[^>]*?>/i;

										$target = $target || "_top";  # so non-targeted stuff sort of works...

									# handle fully qualified links

										if ($link =~ /^\w+:/) {
											unless (safe($link)) {
												$line = "<A HREF=\"$link\" TARGET=\"$target\">$alt (External)</A>&nbsp;";
												last;
											}
											if ($link =~ /^http/i) {
												$link =~ s/^http:\/(\/.*)$/$pathtoparser$setstr$1/i;
												$line = "<A HREF=\"$link\" TARGET=\"$target\">$alt</A>&nbsp;"
											} elsif ($link =~ /javascript:/) {
													$line = "<A HREF=\"\">&nbsp;";
											}
											last;
										}

									# now the slash led links

										if ($link =~ /^\//) {
											$link = $pathtoparser . "$setstr" ."\/". $root . $link;
											$line = "<A HREF=\"$link\" TARGET=\"$target\">$alt</A>&nbsp;";
											last;
										}

									# now the rest of them

										$link = "\/" . $root . $path . $link;
										$link =~ s#\/\w+\/\.\.\/#\/#g;
										$link = $pathtoparser. "$setstr" . $link;
										$line = "<A HREF=\"$link\" TARGET=\"$target\">$alt</A>&nbsp;";
										last;

								};


/^FRAMESET$/	and do {
									 $line =~ s/(<FRAMESET[^>]*?) COLS/$1 ROWS/i;
									 $line =~ s/(<FRAMESET[^>]+)FRAMEBORDER\s*=\s*['|"]?[NO|0]['|"]?([^>]*)>/$1 $2>/i;
									 $line =~ s/(<FRAMESET[^>]+)BORDER\s*=\s*['|"]?0['|"]?([^>]*)>/$1 $2>/i;
									 while ($line =~ s/(<FRAMESET[^>]*?\=\s*["|']?\s*)\d{1,2}\%?,/$1\*/i) {};
									 last;
								 };																	 

/^FRAME$/		 and do {


									# make all frames resizeable...

										$line =~ s/(<FRAME[^>]+?)NORESIZE[="NORESIZE"]?([^>]*>)/$1 $2/ig;
										$line =~ s/(<FRAME[^>]+)FRAMEBORDER\s*=\s*['|"]?[NO|0]['|"]?([^>]*)>/$1 $2>/i;
										$line =~ s/(<FRAME[^>]+)BORDER\s*=\s*['|"]?0['|"]?([^>]*)>/$1 $2>/i;
										
									# get the link out and remove any quoting
									
										($link) = $line =~ /<FRAME[^>]+?SRC\s*=\s*(\S+)[^>]*?>/i;
										last if ($link eq "");
										$link =~ s/\"//g;
										$link =~ s/\'//g;
										$line =~ s/\s*=\s*/=/;
										if ($line !~ /scrolling/i) {
										
											$line =~ s/(<FRAME[^>]+)>/$1 SCROLLING=YES>/i;

										} else {

											$line =~ s/(<FRAME[^>]+)SCROLLING\s*=\s*['|"]?NO['|"]?([^>]*)>/$1 SCROLLING=\"YES\" $2>/i;

										}
									# handle fully qualified links

										if ($link =~ /^\w+:/) {
											if ($link =~ /^http/i) {
												$link =~ s/^http:\/(\/.*)$/$pathtoparser$setstr$1/i;
												$line =~ s/(<FRAME[^>]+?SRC=)\S+([^>]*?>)/$1"$link"$2/i;
											}
											last;
										}

									# now the slash led links

										if ($link =~ /^\//) {
											$link = $pathtoparser . "$setstr" ."\/". $root . $link;
											$line =~ s/(<FRAME[^>]+?SRC=)\S+([^>]*?>)/$1"$link"$2/i;
											last;
										}

									# now the rest of them

										$link = "\/" . $root . $path . $link;
										$link =~ s#\/\w+\/\.\.\/#\/#g;
										$link = $pathtoparser . "$setstr". $link;
										$line =~ s/(<FRAME[^>]+?SRC=)\S+([^>]*?>)/$1"$link"$2/i;
										last;
									};

/^FORM$/		 and do {

									# get the link out and remove any quoting

										($link) = $line =~ /<FORM[^>]+?ACTION\s*=\s*(\S+)[^>]*?>/i;
										last if ($link eq "");
										$link =~ s/\"//g;
										$link =~ s/\'//g;
										$line =~ s/\s*=\s*/=/;

									# handle fully qualified links

										if ($link =~ /^\w+:/) {
											if ($link =~ /^http/i) {
												$link =~ s/^http:\/(\/.*)$/$pathtoparser$setstr$1/i;
												$line =~ s/(<FORM[^>]+?ACTION=)\S+([^>]*?>)/$1"$link"$2/i;
											}
											last;
										}

									# now the slash led links

										if ($link =~ /^\//) {
											$link = $pathtoparser .$setstr. "\/".$root . $link;
											$line =~ s/(<FORM[^>]+?ACTION=)\S+([^>]*?>)/$1"$link"$2/i;
											last;
										}

									# now the rest of them

										$link = "\/" . $root . $path . $link;
										$link =~ s#\/\w+\/\.\.\/#\/#g;
										$link = $pathtoparser .$setstr. $link;
										$line =~ s/(<FORM[^>]+?ACTION=)\S+([^>]*?>)/$1"$link"$2/i;
										last;
									};

		/IMG/		 and do {

										# case 1 - image has empty alt tag

										$line =~ s/<IMG[^>]*?ALT="".*?>//i;

										# case 2 - image has non-empty alt tag

										$line =~ s/<IMG[^>]*?ALT="(.+?)".*?>/<P>$1/i;

										# case 3 - image has no alt tag at all

										$line =~ s/<IMG.*?>//i;

										last;

									};

		/INPUT/		 and do {

										# only screw with it if it's an image...

										if ($line =~ /(<INPUT[^>]*?TYPE=("|')?)IMAGE/gis) {
											$line =~ s/($1)IMAGE/$1SUBMIT/gis;
											last;
										}
										
										last;

									};

		/EMBED/	 and do {

										# sort shockwave etc plus anything else embedded with SRC

										# currently attempts to make sure all SRC left after losing images has the right path

										$line =~ s/<([^>]+?)SRC=(['|"]?)(\/\S+?)(['|"]?)([^>]*?)>/<$1SRQ=$2http:\/\/$root$3$4$5>/i;
										$line =~ s/<([^>]+?)SRC=(['|"]?)(http:\/\/\S+?)(['|"]?)([^>]*?)>/<$1SRQ=$2$3$4$5>/i;
										$line =~ s/<([^>]+?)SRC=(['|"]?)(\S+?)(['|"]?)([^>]*?)>/<$1SRC=$2http:\/\/$root$path$3$4$5>/i;
										$line =~ s#\/\w+\/\.\.\/#\/#g;
										$line =~ s/<([^>]+?)SRQ/<$1SRC/i;
	
									};

		/BODY/		and do {

	                    if ($line =~ /<BODY/i ) {
    	                  	$line =~ s/<BODY[^>]*?>/$body/i;
            	          	last;
						}

						$line =~ s#<\/BODY>#\n<P><A HREF=\"$pathtoparser$chsetstr/$root$path$file\">Change Text Only Settings<\/A>\n<P><A HREF=\"http:\/\/$root$path$file\">Graphic version of this page<\/A>\n<\/FONT>\n<!-- This page parsed by Betsie version $VERSION-->\n<\/BODY>#is;

									};

	}

	return $line;

}

# url calc takes an inpath (is full url without http:/ at beginning
# ie it expects it to begin with a slash and then have the domain name,
# and then whatever else we have or have not got...

sub urlcalc {

  my $url = shift;
  my $root = "";
  my $path = "";
  my $file = "";

  $url =~ s#^\/([^\/]*)##;
  $root = $1;
  ($path, $file) = $url =~ /(.*\/)(.*?)$/;
  if ($path eq "") { $path = "\/"; }
  if ($file eq "/") { $file = ""; }

  return $root, $path, $file;

}

# alarm
# kills hanging Betsies. added by Damion Yates From BBC R&D (Kingswood)
# doesn't work on machines that don't implement alarm
sub alarm {
    my $signame = shift;
    die "Betsie Alert: Timeout after 10 minutes SIG$signame received\n";
}

# safe
# makes sure the url given is in the safe list

sub safe {

  my $url = shift;

  return 1 if ($url =~ /^(javascript|mailto):/is);

  for (@safe) {
    return 1 if ($url =~ /\w+:\/\/((\w|-)+\.)*$_/is);
  }
  return 0;

}

# make_body
# returns a suitable body tag
# including settings page if appropriate
sub make_body {

	my $b = "";
	my ($slash, $set, $code, $font, $font_size) = split '', $setstr;
	
	# brief sanity check - font size must be 1 to 7, code 0 to 3, font 0 to 9 (hence no check)
	# we don't really care about set or slash. in fact we don't even use slash.
	if ($font_size > 7 || $font_size == 0) { $font_size = 5; }
	if ($code > 3) { $code = 0; }
	
	if ($set == 1) {
		
		$b = "<H1>Text Only Settings Page:</H1>
<P>You can change the text-only settings by selecting from the following links. Select the last link when you are done.
<P>Alternatively, <A HREF=\"$pathtoparser/1005/$root$path$file\">select this link</A> to return to the default settings.
<H2>Colours:</H2>
<P><A HREF=\"$pathtoparser/10$font$font_size/$root$path$file\">Yellow On Black</A>
, <A HREF=\"$pathtoparser/11$font$font_size/$root$path$file\">Black On White</A>
, <A HREF=\"$pathtoparser/12$font$font_size/$root$path$file\">White On Blue</A>
, <A HREF=\"$pathtoparser/13$font$font_size/$root$path$file\">Black On Cream</A>	
<H2>Font Size:</H2>
<P><A HREF=\"$pathtoparser/1".$code.$font."1/$root$path$file\">Tiny</A>
, <A HREF=\"$pathtoparser/1".$code.$font."2/$root$path$file\">Small</A>
, <A HREF=\"$pathtoparser/1".$code.$font."3/$root$path$file\">Medium Small</A>
, <A HREF=\"$pathtoparser/1".$code.$font."4/$root$path$file\">Medium</A>
, <A HREF=\"$pathtoparser/1".$code.$font."5/$root$path$file\">Large</A>
, <A HREF=\"$pathtoparser/1".$code.$font."6/$root$path$file\">Extra Large</A>
, <A HREF=\"$pathtoparser/1".$code.$font."7/$root$path$file\">Extra Extra Large</A>
<H2>Font:</H2>
<P><A HREF=\"$pathtoparser/1".$code."0$font_size/$root$path$file\">Verdana</A>
, <A HREF=\"$pathtoparser/1".$code."1$font_size/$root$path$file\">Times</A>
, <A HREF=\"$pathtoparser/1".$code."2$font_size/$root$path$file\">Courier</A>
, <A HREF=\"$pathtoparser/1".$code."3$font_size/$root$path$file\">Helvetica</A>
, <A HREF=\"$pathtoparser/1".$code."4$font_size/$root$path$file\">Arial</A>
, <A HREF=\"$pathtoparser/1".$code."5$font_size/$root$path$file\">Bookman Old Style</A>
, <A HREF=\"$pathtoparser/1".$code."6$font_size/$root$path$file\">Geneva</A>
, <A HREF=\"$pathtoparser/1".$code."7$font_size/$root$path$file\">Chicago</A>
, <A HREF=\"$pathtoparser/1".$code."8$font_size/$root$path$file\">Courier New</A>
, <A HREF=\"$pathtoparser/1".$code."9$font_size/$root$path$file\">System</A>
<H2>Notes:</H2>
<P>Not all browsers support all possible font, size and colour combinations.
<P>Most browsers allow you to specifiy your own font, size and colour combinations, overriding any given 
by the current page. You may find that route more flexible than the options allowed here. Consult your browser
documentation for details.
<HR>
<P><B><A HREF=\"$pathtoparser/0$code$font$font_size/$root$path$file\">Select this link when done</A></B>";

	}
	

	
	$b = "<BODY BGCOLOR=\"$bg[$code]\" TEXT=\"$text[$code]\" LINK=\"$link[$code]\" ALINK=\"$alink[$code]\" VLINK=\"$vlink[$code]\">\n<FONT FACE=\"$font_face[$font]\" SIZE=\"$font_size\">\n" . $b;
	
	return $b;
	
}

=head1 NAME

Betsie - the BBC Education Text To Speech Internet Enhancer

=head1 DESCRIPTION

Betsie is a simple CGI filter to improve the accessibility of arbitrary valid HTML pages.

=head1 README

Betsie is a simple CGI filter to improve the accessibility of arbitrary valid HTML pages. It
effectively creates an on-the-fly text-only version of your site.

For full details of how to use and install Betsie, please refer to the following URL:

http://www.bbc.co.uk/education/betsie/readme.txt

For full details of Betsie's current functionality, contact details, etc etc etc, 
visit the Betsie website: http://www.bbc.co.uk/education/betsie/

=head1 LICENCE

For full details of the licence arrangements for Betsie, please refer to the following URL:

http://www.bbc.co.uk/education/betsie/licence.txt

Executive summary - it's free if you want to use it but you can't sell it.

=head1 PREREQUISITES

This script requires the C<socket> module.

=head2 COREQUISITES

none

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

CGI/Filter
Web

=cut