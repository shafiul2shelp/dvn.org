#!/usr/bin/perl
# Image Reaper 0.1
# A script to download image files from websites

#
# see description at the end of the file
# 

use strict;
use warnings;
use LWP::UserAgent;
use Getopt::Std;
use Image::Size;

my $VERSION = 0.1;

# options
###############

our ($opt_u, $opt_l, $opt_d, $opt_x, $opt_y, $opt_a, $opt_v, $opt_h, $opt_r) = ();

getopts('l:d:u:x:y:avhr');

if ($opt_h or not $opt_u) {
print <<INSTRUCTIONS;
use: 
perl reaper.pl -u http://target.site.com/ -d /path/to/image/dir

options:
-u url      url of website
-d path     directory where to store images (default, current directory)
-l n        max depth of exploration (default 30)
-x n        min width of image in pixels (default 120)
-y n        min height of image in pixels (default 120)
-a          aggressive mode (fishes out urls from javascript code and such) (default NO)
-r			reload (images saved or discarded on a previous run will be fetched again)
-h          help (what you're seeing now)
INSTRUCTIONS

exit;
}


# globals 
################

our $startlink 			= $opt_u || die("must provide url");
our $min_width  		= $opt_x || 120;			# default minimum size in pixels
our $min_height 		= $opt_y || 120;
our $aggressive_mode 	= $opt_a || 0;				# fishes out urls from javascript code and such
our $reload 			= $opt_r || 0;				# reload rejects 
our $dir 				= $opt_d || './';			# where to save image files (default current dir) 
our $verb 				= 1;		# verbose (not optional for now) 

# for statistics
our %stats;

$stats{failed_links} 	= 0;
$stats{visited_links} 	= 0;
$stats{new_images} 		= 0;
$stats{failed_images} 	= 0;
$stats{corrupt_images} 	= 0;
$stats{rejected_images} = 0;

my ($root, $abspath, $relpath, $htmlfile, $fullurl) = splitURL($startlink);

our $base = $root;


if ($dir) {
	unless (-e $dir) {
		die "directory $dir does not exist!\n";
	}
	unless ($dir =~ /\/$/) {
		$dir .= '/';
	}
}
else {
	print "must supply a directory!\n";
}

our $maxdepth 	= $opt_l || 30;
our $depth 		= 0;
our $count 		= 0;
our %vlinks; # visited links
our %rejects; # rejected imgs


# load names of files discarded on previous run 
###############################################

our $rejects_file = $dir.'rejects.log';

if (-e $rejects_file and !$reload) {
	open SMALL, "<$rejects_file" || die "couldn't open $rejects_file -> $!";
	my $x = <SMALL>;
	my $y = <SMALL>;
	if ($x == $min_width and $y == $min_height) {
		while (<SMALL>) {
			chomp $_;
			$rejects{$_} = 1;
		}
	}
	else {
			`rm $rejects_file`;
	}
	close SMALL;
}
else {
	open SMALL, ">$rejects_file" || die "couldn't open $rejects_file -> $!";
	print SMALL "$min_width\n";
	print SMALL "$min_height\n";
	close SMALL;
}



# useragent
################
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;


# entry point
################
reap(url=>$fullurl);


# stats report
###############

print <<STATS;

########################################

new images:          $stats{new_images}       
not found images:    $stats{failed_images}    
corrupt images:      $stats{corrupt_images}   
rejected:            $stats{rejected_images}  
                                              
visited links:       $stats{visited_links}    
failed links:        $stats{failed_links}     

########################################
STATS


# main recursive function
####################
sub reap {
	my %h = @_;
   
	print '-'x20,"\n";
	print "fetching: $h{url}\n";
	print "depth: $depth\n";
	print '-'x20,"\n";

	$vlinks{$h{url}} = 1;	# mark link so we don't repeat ourselves
  
	
	$depth++;	

	
	# fetch URL	
	my $response = $ua->get($h{url});
 
	unless ($response->is_success) {
		print "(failed!!! ".$response->code.")\n";
		$depth--;
		$stats{failed_links}++;
		return;
	}

	$stats{visited_links}++;
	
	my $htm =  $response->content;
	my $newurl = $response->base;

	# normalize url
    my ($currbase, $currpath, $relpath, $currfile, $fullurl)  = splitURL($newurl);

	unless (compare_roots($currbase, $base)) {
		print "new[$currbase] <> old[$base]    !!!\n";
		goto RETURN;
    }	   

	
	## parse image urls
	my @img;
	if ($aggressive_mode) {
		while ($htm =~ m/('|")([^'"]*?)(\.jpg|\.gif|\.png|\.jpeg)\1/sgi) {
			push @img, "$2$3"; 
		}
	}	
	else {
		@img = ($htm =~ /<\w*?img.+?src ?= ?["|']?(.*?)\n*[ |"|'|>]/sgi);
 	}
	
	## parse anchor urls
	my @url2;
	if ($aggressive_mode) {
		while ($htm =~ m/('|")([^'"]*?)(\.htm|\.html|\.shtml|\.cgi|\.php|\.pl|\.asp)\1/sgi) {
			push @url2, "$2$3"; 
		}
	}	
	else {
		@url2 = ($htm =~ /<\w*?a.+?href ?= ?["|']?(.*?)\n*[ |"|'|>]/sgi);
	}
	
	## parse frame urls	
	my @frm = ($htm =~ /<\w*?frame.+?src ?= ?["|']?(.*?)\n*[ |"|'|>]/sgi);
	
	push @url2, @frm;

	## move anchor urls which are images into the image array (rare)
	my @url;
	foreach my $url (@url2) {
		if ($url =~ /\.(jpg|gif|jpeg|png)$/i){
			push @img, $url;
		}
		else {
			push @url, $url;
		}
	}


	#
	# process images
	######################
	
	foreach my $img (@img){
		print "img: $img" if $verb;

		my $auxpath = $currpath;
		if ($img =~ /^\.\./) { 	# path goes up the file hierarchy
			while ($img =~ s[^\.\./][]g) {
				$auxpath =~ s{[^/]+/$}{};
			}
		}	

		if ($img =~ m[^\./]) { 	# path points to itself (rare)
			while ($img =~ s[^\./][]) {
			}
			$img .= $currbase.$auxpath;
		}	

		my ($imgbase, $absdir, $reldir, $file, $imgurl) = splitURL($img, $currbase, $auxpath);

		
		print " --->  $imgurl " if $verb;	
		
		my $filename = $imgurl;
		
		$filename =~ s/\//:/g;

		if (-e "$dir$filename" and !$reload) {
			print "(already got it)\n" if $verb;
		}
		elsif ($rejects{$filename}) {
		   	print "(already discarded)\n" if $verb;
		}	
		else {
			my $rsp = $ua->get($imgurl, Referer=>$fullurl);
			if ($rsp->is_success) {
				my ($xsize, $ysize) = imgsize(\$rsp->content);
				if (!defined($xsize) || !defined($ysize)) {
					$rejects{$filename} = 1;
					print "(couldn't get imgsize!)\n" if $verb;
					add_to_reject_file($filename);
					$stats{corrupt_images}++
				}
				elsif ($xsize < $min_width or $ysize < $min_height) {
					$rejects{$filename} = 1;
					print "(too small ${xsize}x${ysize})\n" if $verb;
					add_to_reject_file($filename);
					$stats{rejected_images}++
				}
				else {
					print "(success)\n";
					open (FIL, ">$dir$filename") || die("error:[$filename] $!"); 
					print FIL $rsp->content;
					close FIL;
					$stats{new_images}++
				}
			}
			else {
				$rejects{$filename} = 1;
				print "(failed!! ".$rsp->code.")\n" if $verb;
				$stats{failed_images}++
			}
		}
				
	}

	if ($depth >= $maxdepth) {	# do not go further than maxdepth
		print "--------------------- (maxdepth) --------------------------\n";
		goto RETURN;	
	}	

	## Process links
	#######################################

	foreach my $link (@url) {
		$link =~ s/#.*$//;	# take out anchor if exists

		next if $link =~ /^mailto:/;
		
		print "link: $link " if $verb;
		my $auxpath = $currpath;
		if ($link =~ /^\.\./) { 	# path goes up the file hierarchy
			while ($link =~ s[^\.\./][]) {
				$auxpath =~ s{[^/]+/$}{};
			}
		}	
		
		if ($link =~ m[^\./]) { 	# path points to itself (rare)
			while ($link =~ s[^\./][]) {
			}
			$link .= $currbase.$auxpath;
		}	
		
		# normalize url
		my ($root, $abspath, $relpath, $filename, $fullurl, $scheme) = splitURL($link, $currbase, $auxpath);

		
		print " ---> $fullurl  " if $verb;

		if ($fullurl =~ /\.(wmv|mpg|mpeg|avi|mov)$/) {
			print " (not a web page: $1)\n";
			next;
		}

		unless ($scheme eq 'http'){
			print " (not http)\n";
			next;
		}
		
		if ($root) {
		  	unless (compare_roots($root, $base)) {
				print " (external, won't visit)\n" if $verb;
				next;
			}
		}
			
		if ($vlinks{$fullurl}) {
			print " (already visited)\n" if $verb;
			next;
		}
		reap(url=>$fullurl);
	}

RETURN:	
	$depth--;
	return;

}


sub splitURL {
	my ($url, $currbase, $currpath) = @_;

	my ($root, $abspath, $relpath, $filename, $resto, $scheme) = ('','','','','',''); # initialize


	
	# strip out the query
	my $query = '';
	if ($url =~ s/(\?.*)$//) {
    	$query = $1;
	}	
	
	if ($url =~ m{^(\w+?://[^/]+)$}) {			# eg: http://sample.com
		$root = $1.'/';
	}
	elsif ($url =~ m{^(\w+?://.*?/)(.*)$}) {	# eg: http://sample.com/<something>
		$root = $1;
		$resto = $2;
		if ($resto =~ m{(.*/)(.*?)$}) {			# eg: <something> = path/to/file.jpg 
			$abspath = $1;
			$filename = $2;
		}
		elsif ($resto =~ m{(.+)$}) {			# eg: <something> = file.jpg
			$filename = $1;
		}
	}	
	elsif ($url =~ m{^/(.*?)([^/]*)$}) {		# eg: /absolute/path/to/file.jpg
		$abspath = $1;
		$filename = $2;
	}
	else {
		$url =~ m{^(.*?)([^/]*)$};				# eg: relative/path/to/file.jpg
		$relpath = $1;
		$filename = $2;
	}



	# string together a 'normalized' URL	
	my $fullurl = '';
	if ($root) {
		$fullurl = $root.$abspath.$filename.$query;
	}
	elsif ($currbase) {
		if ($abspath) {
			$fullurl = $currbase.$abspath.$filename.$query;
		}
		else {
			$fullurl = $currbase.$currpath.$relpath.$filename.$query;
		}
	}	

	$filename =~ s/&amp;/&/g;
	$fullurl =~ s/&amp;/&/g;

	
	if ($fullurl =~ /^(\w*?):/) {
		$scheme = $1;
	}
	
	return ($root, $abspath, $relpath, $filename, $fullurl, $scheme, $query);
}

sub compare_roots {
	my ($a, $b) = @_;
	$a =~ s{^(http://)(www\.)(.*)$}($1$3);	# strip the www 
	$b =~ s{^(http://)(www\.)(.*)$}($1$3);	# strip the www 
	if ($a eq $b) {
		return 1;
	}
	else {
		return 0;
	}
}	

sub add_to_reject_file {

	my $file = shift;

	open FILE, ">>$rejects_file";
	print FILE "$file\n";
	close FILE
}


__END__

=head1 NAME

Image Reaper

=head1 DESCRIPTION

This script fetches all images on a website and saves them into a designated directory. 
It uses a recursive depth first search.
It can discard images which are smaller than a certain width or height.

=head1 README

This script fetches all images on a website and saves them into a designated directory. 
It uses a recursive depth first search.
It can discard images which are smaller than a certain width or height.

=head1 EXAMPLES 

1) perl reaper.pl -l5 -u http://coolwebsite.com/path/gallery.html  -d /path/to/your/image/folder

Starts a search of depth five (l=5) for all images available on coolwebsite.com starting at /path/gallery.html
and saves them in /path/to/your/image/folder 

2) perl reaper.pl -u http://anothercoolsite.com/  -x 200 -y 300    

Searches all images available on anothercoolsite.com up to a depth of 30 (default), discarding images smaller than 200x300, and saves them in the current directory

3) perl reaper.pl -u http://yetanothercoolsite.net/  -a 

Searches for all images on yetanothercoolsite.net by (a)ggressively parsing any URL found in the html or javascript code. Useful when links are generated dynamically. 


=head1 PREREQUISITES

This script runs under C<strict> and requires C<LWP::UserAgent> and C<Image::Size>.

=head1 AUTHOR

Frank Cizmich (logicalATadinetDOTcomDOTuy)

=pod SCRIPT CATEGORIES

CGI
Web

=pod OSNAMES

linux




