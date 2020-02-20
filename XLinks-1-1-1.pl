#!/usr/local/bin/perl -w

use strict;
my $VERSION = "1.1.1";

#### USER CONFIGURATION OPTIONS ####

# Don't forget to change the path to perl on the first line.

# The base directory of the site, without trailing slash
my $base = "/home/ajdelore/pub_html";

# The name of the file to start at, in the base directory.
my $startfile = "index.html";

# The name of your default index file for directories
my $indexfile = "index.html";

# Valid file extensions for XHTML documents -- others will not be 
# crawled or parsed.
my @extensions = ('html');

# Should the program print output to screen(0) or file (1);
# Include a name and path for a logfile, if set to 1. 
# Do not comment out if not using.
my $output_to_file = 0;
my $logfile = "";
 
# Should program output be: 
#      0: minimal (print failed links only) 
#      1: verbose (print all links checked)
my $verbose = 1;

#### END CONFIGURATION ####

use URI::file;
use XML::XPath;
use XML::XPath::XMLParser;
use LWP::UserAgent;

if ($output_to_file) {
  open (LOGFILE,">$logfile") or die "Couldn't open logfile";
  select LOGFILE;
}

chdir ($base) or die "Couldn't access directory $base";
$startfile = URI::file->new_abs($startfile,$base);

my (@files, @files_checked);
my $pages_checked = 0;
my $checked_ok = 0;
my $checked_failed = 0; 

push @files, ($startfile);
push @files_checked, ($startfile);

my $ua = LWP::UserAgent->new;

PARSE: while ( scalar @files > 0 ) {
  my $file_uri = URI->new(pop @files);
  my @path_segments = $file_uri->path_segments; 
  my $filename = pop @path_segments;
  my $ext = (split /\./,$filename)[1];
  next PARSE unless ( grep { $_ eq $ext } @extensions );
  chdir (join('/', @path_segments));
  my $base_uri = URI::file->cwd;
  print "Trying to parse $file_uri\n";
  my $parser = XML::XPath->new(filename => $filename);
  $pages_checked++;

  my $nofollow = 0;
  my $path = ("/html/head/meta[\@name='XLinks']");
  foreach my $meta ( ($parser->find($path))->get_nodelist) {
    my $content = lc $meta->getAttribute('content');
    if ($content eq 'nocheck') {
      print "  Found meta 'nocheck' directive. Ignoring file.\n\n"; 
      next PARSE; 
    }
    elsif ($content eq 'nofollow') {
      print "  Found meta 'nofollow' directive.\n";
      $nofollow = 1;
    }
  }

  foreach my $path ('//a','//link','//img') {
    CHECK: foreach my $node ( ($parser->find($path))->get_nodelist) {
      next CHECK if $node->getAttribute('check') eq 'no'; 
      unless ( $path eq '//img' ) {
        my $href = $node->getAttribute('href');
        if ( $href =~ /\/$/ ) { $href .= $indexfile }
        next if $href =~ /\#[\w\d]+$/;
        my $uri = URI->new_abs($href, $base_uri);
        next if $uri->scheme eq 'mailto';
        if ( $uri->scheme eq 'file' ) {
          if (check_uri($uri)) {
            $nofollow = 1 if $node->getAttribute('check') eq 'nofollow';
            next CHECK if $nofollow;
            foreach (@files_checked) { next CHECK if URI::eq($_, $uri) }
            push @files, ($uri);
            push @files_checked, ($uri);
          }
        }
        else { check_uri($uri) }
      }
      else {
        my $src = $node->findvalue('@src');
        my $uri = URI->new_abs($src, $base_uri);
        check_uri($uri);
      }
    }
  }
  print "\n";
}

print "\nSUMMARY\n";
print "Pages Checked: " . $pages_checked . "\n";
print "Links Checked: " . ($checked_ok + $checked_failed) . "\n";
print "Pass/Fail: $checked_ok/$checked_failed\n\n";

sub check_uri {
  my $uri = shift;
  my $req = HTTP::Request-> new ('HEAD',$uri);
  my $res = $ua->request($req);

  if ( $res->is_success ) {
    print ("  Valid (".$res->code.") $uri\n") if $verbose;
    $checked_ok++;
    return 1;
  }
  else {
    print ("  Failed (".$res->code.") $uri\n");
    $checked_failed++;
    return 0;
  }
}

__END__

=head1 NAME

XLinks

=head1 README

Link validator for XHTML web pages. Based on XML parsing methods, 
this script allows a high degree of control on a page-by-page and 
link-by-link basis. Able to crawl entire sites.

Complete documentation at http://www.sfu.ca/~ajdelore/XLinks/

=head1 PREREQUISITES

This script runs under C<strict> and requires C<URI>, C<LWP::UserAgent>,
C<XML::Parser> and C<XML::XPath>.

=head1 AUTHOR

Anthony DeLorenzo (ajdelore@sfu.ca)

=pod SCRIPT CATEGORIES

CGI
Web

=cut
