#!/usr/bin/perl

use warnings;
use strict;

use XML::RSS;
use LWP::Simple;
use List::Util qw(first);
use File::Save::Home qw/make_subhome_directory get_subhome_directory_status/;
use Cache::File;
use Getopt::Long;
use Pod::Usage;
use HTML::Entities;

my $VERSION = 0.2;

my ( $show_man, $show_help, $debug);
my ( $installed_only, $act_as_filter, $reload_changes );
my $feed_uri = 'http://search.cpan.org/uploads.rdf';
my $log = sub{};

GetOptions(
  'filter!' => \$act_as_filter, 'uri' => \$feed_uri,
  'installed' => \$installed_only,
  'debug' => \$debug, 'reload' => \$reload_changes,
  'help|?' => \$show_help, man => \$show_man,
);

pod2usage(0) if $show_help;
pod2usage(-exitstatus => 0, -verbose => 2) if $show_man;
$log = sub{ print STDERR @_, "\n" } if $debug;

if ( $installed_only ) {
  require Module::Locate;
  Module::Locate->import(qw/locate/);
};
sub dist2module {
  my ( $m, $v ) = split( qr/-(?=v?\d+\.\d+)/, $_[0] );
  $m =~ s/\W/::/g;
  return $m;
}


my $uploads = $act_as_filter ? join( '', <> ) : get( $feed_uri );
die( "Unable to obtain uploads from standard input or http" ) unless $uploads;

my $cache_dir = get_subhome_directory_status( '.cpan-changes' );
make_subhome_directory( $cache_dir );

my $cache = Cache::File->new
  ( cache_root => $cache_dir->{abs}, default_expires => '1 week' );

my $rss = XML::RSS->new();
$rss->parse( $uploads );

my @ignore;

# print the title and link of each RSS item
foreach my $item (@{$rss->{'items'}}) {

  if ( $installed_only ) {
	 my $mod = dist2module( $item->{'title'} );
	 my $mod_info = eval{ locate( $mod ) };
	 warn( sprintf "Invalid dist name '%s':\n%s", $item->{'title'}, $@ ) if $@;
	 if ( not $mod_info || $@ ) {
		push @ignore, $item;
		next;
	 }
  };

  $log->( "title: ", $item->{'title'} ,"\nlink: $item->{'link'}" );

  my $changes;
  $changes = $cache->get( $item->{link} ) unless $reload_changes;

  if ( not $changes ) {
	 ( my $src_dir = $item->{'link'} ) =~ s|/~([^/]+)/|/src/\U$1\E/|;
	 my $uri = first{ head( $_ ) } map{ $src_dir . $_ }
		map{( $_, uc )} qw/Changes ChangeLog/;
    $changes = $uri ? get( $ uri ) : 'No changelog found';
	 $cache->set( $item->{link}, $changes );
  };

  # for some reason we will need to double encode the changes here
  my $encoded = encode_entities(encode_entities( $changes ),'&');
  $item->{description} .= sprintf( "<hr /><pre>%s</pre>", $encoded );
  $log->( "description: ", $item->{description} );
}


if ( $installed_only ) {
  # filter modules that are not installed locally
  $rss->{items} =
	 [ grep{ my $item=$_; not grep{ $_ == $item } @ignore } @{$rss->{items}} ];
  $log->( "Displaying:\n  ".join( "\n  ", map{$_->{title}} @{$rss->{items}}) );
};

print $rss->as_rss_1_0;
$log->( $rss->as_rss_1_0, "\n\nDONE!\n" );

__END__

=head1 NAME

cpan-changes.pl - Enrich CPAN recent module feed with change-log info

=head1 SYNOPSIS

cpan-changes.pl [options]

 Options:
   --uri        feed uri [default: http://search.cpan.org/uploads.rdf]
   --filter     use as filter, i.e. retrieve RDF from standard input
   --installed  discard modules that aren't installed locally [EXPERIMENTAL]
   --reload     omits cache look-up and reload all changelogs
   --debug      processed info is logged to standard error
   --help       brief help message
   --man        full documentation

=head1 README

This program loads the CPAN recent modules feed, either from your
local CPAN mirror or as a filter in your favorite feed reader.
Afterwards it scans it and tries to fetch the changelog for new module
releases and parses them back into the RSS feed. All retrieved changelogs
are stored in a cache to minimize the load put onto your local CPAN mirror.

=head1 INSTALLED MODULES ONLY

This is a fragile hack using custom regexes to guess the module name
from the distribution (suggestions how to do this in a standard way
would be very welcome) and then just pull the respective item from the
internals of XML::RSS. Use with caution!

=head1 BUGS

Probably many. Up until now this program has only be tested under Linux
and in combination with the Liferea feed reader (both as conversion filter
and as programmatic source). I'd love to get feedback about your experiences
with this module in other environments.

=head1 PREREQUISITES

This script requires C<perl 5.6>, C<XML::RSS 1.00>, C<LWP::Simple>,
C<File::Save::Home 0.03>, C<Cache 2.00>, C<Getopt::Long 2.4>,
C<Pod::Usage 1.08> and C<HTML::Parser 3.26>. I know these are a lot of
prerequisites for a simple script (especially L<File::Save::Home>), but as
the intended use case for this script in on the desktop of an active perl
developer, this should do.

=head1 COREQUISITES

C<Module::Locate 1.2> for the option to display only changes to
locally installed modules.

=head1 CPAN META INFO

=pod SCRIPT CATEGORIES

CPAN
Web
Web/RSS

=pod OSNAMES

any

=head1 AUTHOR

Sebastian Willert <willert@cpan.org>

=cut
