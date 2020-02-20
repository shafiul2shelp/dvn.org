use strict;
use LWP::UserAgent;

my $VERSION = 1.0;
my %pages = (
				'Firewall 1' => 'http://www1.fatbrain.com/asp/bookinfo/bookinfo.asp?theisbn=007134229x',
				'Bay Network Router Configuration' => 'http://www1.fatbrain.com/asp/bookinfo/bookinfo.asp?theisbn=0070284857',
				'Mastering Algorthims with Perl' => 'http://www1.fatbrain.com/asp/bookinfo/bookinfo.asp?theisbn=1565923987',
				);

foreach (keys %pages) {
my $ua = new LWP::UserAgent;
my $req = new HTTP::Request GET => $pages{$_};
my $string = $ua->request($req)->as_string;
	if ($string =~ m/Not yet published/g) {
	print "$_ is not out yet.\n";
	} else {
	print "$_ has been published.";
	}
}

=head1 NAME

fatbrain - This script takes a list of books and looks to see if they are considered published on fatbrain.

=head1 DESCRIPTION

I am always waiting for books to be published and I am sick of doing all the work in looking them up.  
I created this script to check if the books I am looking for are published.

=head1 README

=head1 PREREQUISITES

This script has a few requirements.  You will need LWP and you will need to look up the book the first time
yourself.  Once you have the url cut and paste it into the value field  in %pages and put in a description in the key
of the hash.

=head1 COREQUISITES

None

=pod SCRIPT CATEGORIES

Web

=cut












