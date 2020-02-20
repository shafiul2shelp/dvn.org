#!/usr/bin/perl

$VERSION = '1.00';

# XAlbum2Rss - Generate RSS Feed from Photo Album XML, (see XPhotoAlbum.pl)
# Version 1.00
#
# Get docs and newest version from
#       http://www.neystadt.org/XPhotoAlbum/
#
# Copyright (c) 2005, John Neystadt <http://www.neystadt.org/john/>
# You may install this script on your site for free
# To obtain permision for redistribution or any other usage
#       contact john@neystadt.org.
#
# Drop me a line if you deploy this script on your site.

=head1 NAME

XAlbum2Rss.pl v1.00 - XML Photo Album Script RSS Feed Generator

=cut

use XML::DOM;
use XML::RSS;
use Image::ExifTool;
use File::stat;
use POSIX;

my ($DateFormat) = '%Y-%m-%dT%H:%M:%S+02:00'; # '%a, %d %b %Y %H:%M:%S GMT+2';
my ($FeedSize) = 100;

if ($#ARGV < 1) {
	print STDERR "Usage: $0 <album.xml> <picture root>
	Will print RSS feed on the output\n.";

	die 1;
}

my ($IndexFile, $PictureRoot) = @ARGV;
$PictureRoot .= '/'
	if !($PictureRoot =~ q|/$|);

my $parser = new XML::DOM::Parser;
my $doc = $parser->parsefile ($IndexFile);
my $album = $doc->getChildNodes ()->item (0);

die "Can't load XML file $IndexFile" if (!$doc || !$album);

my $PicturePath = $album->getAttribute ('PATH');
$PicturePath .= '/'
	if !($PicturePath =~ q|/$|);

my $children = $album->getChildNodes ();
my $anno;
for (0..$children->getLength ()-1) {
	my $child = $children->item ($_);
	if ($child->getNodeName eq 'ANNOTATION') {
		$anno = $child->getFirstChild ()->getData ();
		last;
	}
}

my $rss = new XML::RSS (version => '1.0');

$rss->channel(
   title        => $album->getAttribute ('TITLE'),
   link         => $album->getAttribute ('LINK'),
   description  => $anno,
   dc => {
     date       => getNowTime(),
     subject    => $album->getAttribute ('TITLE'),
     creator    => $album->getAttribute ('AUTHOR'),
     publisher  => $album->getAttribute ('AUTHOR'),
     rights     => $album->getAttribute ('COPYRIGHT'),
     language   => 'en-us',
   },
   syn => {
     updatePeriod     => "hourly",
     updateFrequency  => "1",
     updateBase       => "1901-01-01T00:00+00:00",
   },
 );

$rss->image(
	title  => "Album Logo",
	url    => $album->getAttribute ('ICON'),
	link   => $album->getAttribute ('LINK'),
);

my @images = sortAlbumImages ($doc);
for (@images [0..$FeedSize-1]) {
	last if !$_;
	image2Rss ($rss, $_, $album);
}

print $rss->as_string;

## END OF MAIN ##

sub image2Rss {
	my ($rss, $image, $album) = @_;

	my $link = $PicturePath . $image->getAttribute ('HREF');


	# Enumerate through parent folders to prepend folder titles
	my $elem = $image;
        
	my $title = $image->getFirstChild ()->getData ();
        while ($elem) {
		$elem = $elem->getParentNode ();
		last if $elem->getNodeName () ne 'FOLDER';
		$title = $elem->getAttribute ('TITLE') . ' : ' . $title;
	}

	my $desc = <<EOD;
<span>$title</span><p/><img src="$link" alt="$title"/>
EOD

	$rss->add_item (
		title		=>	$title,
		link		=>	$link,
		description	=>	$desc,
		dc => {
			subject	=> $album->getAttribute ('TITLE'),
			creator	=> $album->getAttribute ('AUTHOR'),
			date	=> $image->getAttribute ('DATE'),
   		},
	);
}

sub sortAlbumImages {
	my ($doc) = @_;

	my @images = $doc->getElementsByTagName ('PICTURE');
	my ($f);

	foreach (@images) {
		my $file = $PictureRoot . $_->getAttribute ('HREF');
		my $date = getImageTime ($file);

		$f = 0;
		if (!$date) {
			$f = 1;
			$date = getFileTime ($file);
		}
		$_->setAttribute ('DATE', $date);

		print STDERR "$date\t";
		if ($f) { print STDERR "FILE"; } else { print STDERR "EXIF"; }
		print STDERR "\t$file\n";
	}

	sub ByImageDate { 
		$b->getAttribute ('DATE') cmp $a->getAttribute ('DATE');
	}

	return sort ByImageDate @images;
}

sub getImageTime {
	my ($file) = @_;

	my $exifTool = new Image::ExifTool;
	$exifTool->Options(Group0 => ['EXIF'], Unknown => 0, DateFormat => $DateFormat);

	my $info = $exifTool->ImageInfo($file);

	return udef if !$info;

	if (exists $info->{'DateTimeOriginal'}) {
		return $info->{'DateTimeOriginal'};
	} elsif (exists $info->{'ModifyDate'}) {
		return $info->{'ModifyDate'};
	}

	return undef;
}

sub getFileTime {
	my ($file) = @_;

	my $info = stat($file);
	die "Can't access referenced file $image!" if !$info;

	return POSIX::strftime ($DateFormat, gmtime ($info->mtime));
}

sub getNowTime {
	return POSIX::strftime ($DateFormat, gmtime ());
}

__END__

=head1 DESCRIPTION

This simple script can be used to generate RSS feed out of the album file, which you created for XPhotoAlbum.pl. The script can be used for off-Line
RSS generation - add it to your schedule tasks or crontab.

Once you created RSS feed, your friends may add your album to their RSS Reader (http://www.bradsoft.com/feeddemon/), http://www.LiveJournal.com friend lent, or http://my.yahoo.com 
personalized portal. Each time you ad a photo, they will instantly see it in their news feed.

=head1 USAGE

I<XAlbum2Rss.pl album.xml pictures-path>
       
Will print RSS feed on the output. You can redirect this into album.rdf file, and use it for RSS feed.

=head1 XML Index File Format

Please see the examples below to understand the format of the files.

=head1 CAVEATS

You need to add few new attributes to you album XML file, which will be used for RSS meta-data:

=over

=item 1

LINK - URL of the full album

=item 2

AUTHOR - Your name

=item 3

COPYRIGHT - Copyright text

=back

For example:

... LINK="http://www.neystadt.org/john/album/" AUTHOR="John Neystadt" COPYRIGHT="John Neystadt" ...

=head1 TIPS AND TRICKS

Send your feedback...

=head1 EXAMPLES

Please see http://www.neystadt.org/ for three instances of the albums using this technology.
Particulary examples of the XML index files are located at:

    http://www.neystadt.org/john/album/index.rdf
    http://www.neystadt.org/john/family-album/index.rdf

=head1 PREREQUISITES

This script requires the C<XML::DOM>, C<XML::RSS> and C<Image::ExifTool> modules available from CPAN (http://www.cpan.org)

=pod OSNAMES

All UNIXes, Windows NT

=pod SCRIPT CATEGORIES

Web

=pod README

This simple script can be used to generate RSS feed out of the album file, which you created for XPhotoAlbum.pl. The script can be used for off-Line
RSS generation - add it to your schedule tasks or crontab. 

See http://www.neystadt.org/XPhotoAlbum/ for additional details.

=cut
