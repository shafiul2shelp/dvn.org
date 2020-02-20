#!/usr/bin/perl

$VERSION = '1.01';

# XPhotoAlbum - XML Photo Album Script
# Version 1.01
#
# Get docs and newest version from
#       http://www.neystadt.org/XPhotoAlbum/
#
# Copyright (c) 2002, John Neystadt <http://www.neystadt.org/john/>
# You may install this script on your site for free
# To obtain permision for redistribution or any other usage
#       contact john@neystadt.org.
#
# Drop me a line if you deploy this script on your site.

=head1 NAME

XPhotoAlbum.pl v1.01 - XML Photo Album Script

=cut

use XML::DOM;
use URI::Escape;

$UrlBase = '/cgi-bin/XPhotoAlbum.pl';

# Script error handling block

print "Content-Type: text/html\n\n";

BEGIN {
	sub _perlerror
	{
	    my $message = $_[0];

	    print <<EOR;
<B>Sorry, CGI internal perl error --
$message</B>
EOR
	    exit (1);
	}

	$SIG{'__WARN__'}=\&_perlerror;
	$SIG{'__DIE__'}=\&_perlerror;
}

# end of script error handling

my $Parm = $ENV {QUERY_STRING};
$Parm =~ s/=\++/=/go;
$Parm =~ s/\++/ /go;
my %Params = split (/[=&]/, $Parm);
if ($Params {'index'}) {
        $IndexFile = $Params {'index'};
} else {
        $IndexFile = '/john/album/index.xml';
}

my $parser = new XML::DOM::Parser;
my $doc = $parser->parsefile ('..' . $IndexFile);
         
my $album = $doc->getChildNodes ()->item (0);
        
my $PicturePath = $album->getAttribute ('PATH');
$PicturePath =~ s|[\\/]$||go;
$PicturePath .= '/'
	if $PicturePath;

print '<HTML><HEAD>
	<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=utf-8">
	<link rel="StyleSheet" href="', $album->getAttribute ('CSS'), '" type="text/css">
	<TITLE>', $album->getAttribute ('TITLE'), '</TITLE>
</HEAD>
';

if ($Params {'type'} eq 'plain') {
	PrintPlainAlbum ($album);
} elsif ($Params {'type'} eq 'IE') {
	PrintIEAlbum ($album);
} elsif ($Params {'type'} eq 'thumb') {
	PrintThumbAlbum ($album);
} else {
	PrintPic ($album, $Params {'id'});
}

print "</HTML>";              

# *****

sub PrintPic {
        my ($album, $id) = @_;

	print '<BODY bgcolor="#68838b" text="#000000">
';

        my $folder = $album->getChildNodes ()->item (1);
        my $children = $folder->getChildNodes ();
        
        my $picIndex = 0;
	my $prevId, $nextId, $lastId, $thePic;
        for (0..$children->getLength ()-1) {
                my $pic = $children->item ($_);
                next if $pic->getNodeName () ne 'PICTURE';

		my $picId = $pic->getAttribute ('id');

		next if !$picId;

		if ($thePic && $id == $lastId) {
			$nextId = $picId;
			last;
		}

		if ($picId == $id) {
			$prevId = $lastId;
			$thePic = $pic;
		}

		$lastId = $picId;
	}

	my $Url = $UrlBase . '?index=' . $IndexFile . '&type=';

	print "<center>\n";
	print '[ <a href="', $Url, 'pic&id=', $prevId, '">&lt;&lt;</a> ]', "\n" if $prevId;
	print '[ <a href="', $Url, 'thumb">Index</a> ]', "\n";
	print '[ <a href="', $Url, 'pic&id=', $nextId, '">&gt;&gt;</a> ]', "\n" if $nextId;
	print "<hr>\n";

        my $text = $thePic->getFirstChild ();
        if (defined ($text)) {
                $text = $text->getData ();
        } else {
                $text = '';
        }
	
	print "<span class=PicAnnotation style='width:60%'>", $text, "</span><br>";

	print '<img src="', $PicturePath, $thePic->getAttribute ('HREF'), '" alt="', $thePic->getAttribute ('HREF'), '">
</center>';

        PrintPlainFooter ($album);
        print "</BODY>\n";
}

# ***

sub PrintThumbAlbum {
        my ($album) = @_;
        print '<BODY bgcolor="#68838b" text="#000000">

<center>
<h1>', $album->getAttribute ('TITLE'), '</h1>
</center>

<hr>

<center>
<table border=0 cellspacing=0 cellpadding=5 width="100%">

';

	my $Columns = $album->getAttribute ('COLUMNS');
	$Columns = 8 if $Columns < 1;

	my $folder = $album->getChildNodes ()->item (1);
	my $children = $folder->getChildNodes ();

	my $picIndex = 0;
	for (0..$children->getLength ()-1) {
		my $pic = $children->item ($_);
		next if $pic->getNodeName () ne 'PICTURE';

		if ($picIndex % $Columns == 0) {
			if ($picIndex != 0) {
				print "</tr>\n";
			}

			print "<tr>\n";
		}

		my $Thumb = $PicturePath . 'thumb/' . $pic->getAttribute ('HREF');
		$Thumb =~ s/(\....)$/_thumb\1/o;

		print '
<td width=', 100 / ($Columns+2), '% valign=top>';

		my $text = $pic->getFirstChild ();
		if (defined ($text)) {
			$text = $text->getData ();
		} else {
			$text = '';
		}

		print '<center>
<a href="', $UrlBase, '?type=pic&index=' . $IndexFile . '&id=' . $pic->getAttribute ('id'), '"><img
src="', 
	$Thumb, '" hspace=0 vspace=0 border=0 
	ALT="', $pic->getAttribute ('HREF'), '"></a><br>
<span class=ThumbAnnotation>', $text, '</span>
</center>' if !$pic->getAttribute ('SKIP');
		print '</td>
';

		$picIndex++;
	}        

	print "</table></center>\n\n";
	PrintPlainFooter ($album); 
	print "</BODY>\n";
}

# *****

sub PrintPlainAlbum {
	my ($album) = @_;
	print "<BODY>\n";

	PrintPlainFolders ($album, 0);
	PrintPlainFooter ($album);

	print "</BODY>\n";
}

sub PrintPlainFolders {
	my ($folder, $level) = @_;

	my $title = $folder->getAttribute ('TITLE');
	if (!$level) {
		print '<H1>';
	} else {
		print '<dt><font size="+', 3-$level, '">';
	}

	print $title;

	if (!$level) {
		print '</H1>';
	} else {
		print '</font></dt><dd>';
	}

	# Any annotation?
	my $children = $folder->getChildNodes ();
	for (0..$children->getLength ()-1) {
		my $child = $children->item ($_);
		print "\n", $child->getFirstChild ()->getData (), "\n"
			if $child->getNodeName eq 'ANNOTATION';
	}
	print "</ul>\n" if $TagOpened;

	# Now the pictures
	PrintPlainPictures ($folder);
        
	# Now the sub folders
	my $TagOpened = 0;
        for (0..$children->getLength ()-1) {
                my $child = $children->item ($_);
		next if $child->getNodeName ne 'FOLDER';

		print "<dl>\n" if !$TagOpened;
		$TagOpened = 1;

		PrintPlainFolders ($child, $level+1);
        }
	print "</dl>\n" if $TagOpened;

	print "</dd>" if $level;
}       


sub PrintPlainPictures {
	my ($folder) = @_;

        my $children = $folder->getChildNodes ();

	my $TagOpened = 0;
        for (0..$children->getLength ()-1) {
                my $child = $children->item ($_);
                next if $child->getNodeName () ne 'PICTURE';

		print "<ul>\n" if !$TagOpened;
		$TagOpened = 1;

                print "\t" x 3, '<li><a href="', $PicturePath, $child->getAttribute ('HREF'), '">', 
			$child->getFirstChild ()->getData (), "</a></li>\n";
        }
	print "</ul>\n" if $TagOpened;
}

sub PrintPlainFooter {
        my ($album) = @_;

	print "<HR>\n";
        
        if (open (fhFooter, $album->getAttribute ('FOOTER'))) {
                print <fhFooter>;
                close fhFooter;
        } else {
                print "Can't open footer file (", $album->getAttribute ('FOOTER'), ")!";
        }
}                       

# *****

sub PrintIEAlbum {
	my ($album) = @_;

	print <<"EOF";
<XML id=XmlAlbum src="$IndexFile"></XML>
<script language="JavaScript">
	var PicturePath = "$PicturePath";
EOF

	print <<'EOF';
	MinimizedFoldersWidth = 16;
        MinimizedFoldersHeight = 40;

	var bInited = false;
	var bPictureLoaded = false;
	var bFolderLoaded = false;

	function Resize () {
		footer.style.pixelTop = document.body.clientHeight-footer.offsetHeight;
		pictures.style.pixelWidth = folders.style.pixelWidth = foldersDivider.style.pixelWidth = 
			document.body.clientWidth / 3;
		folders.style.pixelHeight = document.body.clientHeight * 2/3;
		foldersDivider.style.pixelTop = document.body.clientHeight * 2/3;
		pictures.style.pixelTop = document.body.clientHeight * 2/3 + foldersDivider.offsetHeight;
		pictures.style.pixelHeight = document.body.clientHeight-document.body.clientHeight * 2/3 -
			footer.offsetHeight-foldersDivider.offsetHeight;
		image.style.pixelLeft = document.body.clientWidth / 3;
		image.style.pixelWidth = document.body.clientWidth - document.body.clientWidth / 3;
		image.style.pixelHeight = document.body.clientHeight-footer.offsetHeight;

		pictures.style.visibility = 'visible';
		folders.style.visibility = 'visible';
		foldersDivider.style.visibility = 'visible';
		image.style.visibility = 'visible';
		footer.style.visibility = 'visible';

		bInited = true;
	}

	var activeFolder = null;

	function SetFolder (folder) {
		if (folder == activeFolder) return;
		if (activeFolder != null)
			activeFolder.style.display = 'none';
		activeFolder = folder;
		if (activeFolder != null)
			activeFolder.style.display = '';

		bFolderLoaded = true;
	}

	function ShowImage1 (url, width, height, title, nextImage, PrevImage) {
		thePicture.src = PicturePath+url;
		theTitle.innerHTML = unescape (title);

		//if (width != '') thePicture.Width = width;
		//if (width != '') thePicture.Height = height;

		bPictureLoaded = true;
	}

	function ShowImage (ImageId) {
		var album = XmlAlbum.documentElement;

		ImageId = ImageId.valueOf ();

		try {
			var pic = album.selectSingleNode ("//PICTURE[@HREF='" + ImageId + "']");

			if (!pic)
			{
				alert ("No such picture in the album!");
				return;
			}

			ImageXsl.selectSingleNode ("//xsl:variable[@name='PicturePath']").text =
				PicturePath;

			image.innerHTML =
				pic.transformNode(ImageXsl);
		} catch (e) { // older Explorer is installed that does not support XSL as we need.
			thePicture.src = PicturePath+ImageId;
		}
		bPictureLoaded = true;
	}

	var
		DynamicImageActive = false;
		DynamicFoldersActive = false;
		CurrentFoldersWith = 0;

	function DynamicResize () {
		if (!bInited) return;

		// Picture
		if (bPictureLoaded) {
			if ((event.clientX > document.body.clientWidth / 3) && !DynamicImageActive) {
				DynamicImageActive = true;

				pictures.style.pixelWidth = folders.style.pixelWidth = foldersDivider.style.pixelWidth = currentFoldersWidth =
					MinimizedFoldersWidth;
				image.style.pixelLeft = MinimizedFoldersWidth;
				image.style.pixelWidth = document.body.clientWidth - MinimizedFoldersWidth;
			} 
		
			if ((event.clientX < MinimizedFoldersWidth) && DynamicImageActive) {
				DynamicImageActive = false;

				pictures.style.pixelWidth = folders.style.pixelWidth = foldersDivider.style.pixelWidth = currentFoldersWidth =
					document.body.clientWidth / 3;
				image.style.pixelLeft = document.body.clientWidth / 3;
				image.style.pixelWidth = document.body.clientWidth - document.body.clientWidth / 3;
			}
		}

                // Folders
                if (!bFolderLoaded) return;

                if (DynamicImageActive || 
				((event.clientY > document.body.clientHeight * 2/3) && !DynamicFoldersActive)) {
                        DynamicFoldersActive = true;
                        
                        folders.style.pixelHeight = MinimizedFoldersHeight;
                        foldersDivider.style.pixelTop = MinimizedFoldersHeight;
                        pictures.style.pixelTop = MinimizedFoldersHeight + foldersDivider.offsetHeight;
                        pictures.style.pixelHeight = document.body.clientHeight-MinimizedFoldersHeight -
                                footer.offsetHeight-foldersDivider.offsetHeight;
                }       
                
                if (!DynamicImageActive && 
				((event.clientY < MinimizedFoldersHeight) && DynamicFoldersActive)) {
                        DynamicFoldersActive = false;
                        
                        folders.style.pixelHeight = document.body.clientHeight * 2/3;
                        foldersDivider.style.pixelTop = document.body.clientHeight * 2/3;
                        pictures.style.pixelTop = document.body.clientHeight * 2/3 + foldersDivider.offsetHeight;
                        pictures.style.pixelHeight = document.body.clientHeight-document.body.clientHeight * 2/3 -
                                footer.offsetHeight-foldersDivider.offsetHeight;
                }
	}
</script>

<XML id=ImageXsl>
	<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:variable name="PicturePath">This will be set from JavaScript</xsl:variable>
	<xsl:template match="PICTURE">
		<center><table cellpading="0" cellspacing="0" height="100%">
			<tr><td valign="center"><center>
				<xsl:variable name="PrevPic" select="preceding::PICTURE[position() = 1]"/>
				<xsl:variable name="NextPic" select="following::PICTURE"/>

				<xsl:if test="$PrevPic/@HREF">
					[<a><xsl:attribute name="HREF">
						<xsl:value-of select="concat ($PicturePath, $PrevPic/@HREF)"/>
					</xsl:attribute><xsl:attribute name="onClick">
						ShowImage ("<xsl:value-of select="$PrevPic/@HREF"/>"); return false;
					</xsl:attribute>&lt;&lt;</a>]
				</xsl:if>
				<xsl:if test="$NextPic/@HREF">
					[<a><xsl:attribute name="href">
						<xsl:value-of select="concat ($PicturePath, $NextPic/@HREF)"/>
					</xsl:attribute><xsl:attribute name="onClick">
						ShowImage ("<xsl:value-of select="$NextPic/@HREF"/>"); return false;
					</xsl:attribute>&gt;&gt;</a>]
				</xsl:if>
				<hr/>
				<SPAN class="PicAnnotation" style="WIDTH: 100%">
					<xsl:for-each select="ancestor::FOLDER">
						<xsl:value-of select="@TITLE"/> :
					</xsl:for-each>
					<p/>
					<xsl:value-of select="./text()"/>
				</SPAN><br/>
				<img>
					<xsl:attribute name="src">
						<xsl:value-of select="concat ($PicturePath, ./@HREF)"/>
					</xsl:attribute>
				</img>
			</center></td></tr>
		</table></center>
	</xsl:template>
	</xsl:stylesheet>
</XML>

<BODY onLoad="Resize ();" onResize="Resize ();" onMouseMove="DynamicResize ();">
EOF
	PrintDivFolders ($album);
	PrintDivPictures ($album);
	PrintDivImage ($album);
	PrintDivFooter ($album);

	print "\n</BODY>\n";
}

# *******

my $FolderNum = 0;

sub PrintDivFolders {
	my ($album) = @_;

	print '<div class=Folders id=folders
	style="position:absolute; background-color: AZURE; top:0; left:0; overflow:auto; visibility:hidden">', "\n";
	PrintFolders ($album, -1);
	print '</div><div id=foldersDivider
	style="position:absolute; background-color: DIMGRAY; left:0; height:3; overflow:hidden; visibility:hidden"></div>', "\n";
}

sub PrintDivPictures {
	my ($album) = @_;

        print '<div class=Pictures id=pictures
		style="position:absolute; background-color: ALICEBLUE; left:0; overflow:auto; visibility:hidden">', "\n";
	PrintPictures ($album);
        print '</div>';
}

sub PrintDivImage {
        my ($album) = @_;
	print '<div class=Image id=image
		style="position:absolute; background-color: BEIGE; top:0; overflow:auto; visibility:hidden"><center><table
		cellpading=0 cellspacing=0 height="100%"><tr><td valign=center><center>
		<SPAN id=theTitle class=PicAnnotation style="WIDTH: 100%"></SPAN><BR>
		<img id=thePicture src="/john/album/none.gif"></center></td></tr></table></center></div>', "\n";
}

sub PrintDivFooter {
	my ($album) = @_;
	
	print '<div class=Footer id=footer
		style="position:absolute; left:0; background-color: WHITE; visibility:hidden">', "\n";
	if (open (fhFooter, $album->getAttribute ('FOOTER'))) {
		print <fhFooter>;
		close fhFooter;
	} else {
		print "Can't open footer file (", $album->getAttribute ('FOOTER'), ")!";
	}

	print "</div>";
}

# *******

sub PrintFolders {
	my ($folder, $level) = @_;

	my $title = $folder->getAttribute ('TITLE');
	print "\t" x $level, '<table cellpading=0 cellspacing=0><tr><td>', '&nbsp;' x (($level-1)*5), '</td><td><a href=""', 
		" onclick='SetFolder(", folder, ($FolderId {$folder} = $FolderNum++),
		, "); return false;'>$title</a></td></tr></table>\n"
			if ++$level;

	my $children = $folder->getChildNodes ();
	for (0..$children->getLength ()-1) {
		my $child = $children->item ($_);
		PrintFolders ($child, $level)
			if $child->getNodeName eq 'FOLDER';
		}
}

$Pic = 0;

sub PrintPictures {
        my ($folder) = @_;
        my $children = $folder->getChildNodes ();

	# expand sub-folders
        for (0..$children->getLength ()-1) {
                my $child = $children->item ($_);
                PrintPictures ($child)
                        if $child->getNodeName eq 'FOLDER';
        }

	# Now print the pictures

	print '<div class=Folder id=folder' . $FolderId {$folder} . ' style="display:none">
		<table>';

	# Annotation
	for (0..$children->getLength ()-1) {
		my $child = $children->item ($_);
		next if $child->getNodeName () ne 'ANNOTATION';

		print '<tr><td colspan=2 valign=top>', $child->getFirstChild ()->getData (), "</td></tr>\n";
	}

	# The pictures
	my $PicCount = 0;
	for (0..$children->getLength ()-1) {
                my $child = $children->item ($_);
		next if $child->getNodeName () ne 'PICTURE';

		$PicCount++;
		$Pic = !$Pic;

		print '<tr><td valign=top><img src="/pic/r-bul.gif"></td><td><a href="', 
			$PicturePath, $child->getAttribute ('HREF'), '" ',
			"onClick='ShowImage (",
				'"', $child->getAttribute ('HREF'), '"); return false;', "'>",
			$child->getFirstChild ()->getData (), "</a></td></tr>\n";
        }

	print "</table>\n";

	print "No pictures in this folder."
		if !$PicCount;

	print "</div>\n";
}

__END__

=head1 DESCRIPTION

This simple script can be used for organizing web photo album. The script can be used for online or Off-Line
photo album generation. It does not provides web interface for picture uploading, thumbnail generation or web 
authoring of the album. Those tasks you will have to do using standard image processing tools and ftp. However it generates
rather nice browsable photo album.

Those are XPhotoAlbum features:

=over

=item *

Support threee different alum viewing modes:

=over

=item 1

Three pane DHTML (client side) browsing.

=item 2

Thumbnail based album.

=item 3

Plain text outline for outdated browsers.

=back

=item *

Generate album dynamically from index XML file

=item *

Support dynamic clients side album

=item *

For the 1st two modes are supported only with Internet Explorer.

=item *

Plain text album is supported on all browsers.

=item *

Support international (Unicode based) text within album.

=back

=head1 USAGE

=over

=item 1

Put the script in your cgi-bin directory.

=item 2

Edit the script to set script parameters to your configuration

=over

=item *

$UrlBase = '/cgi-bin/XPhotoAlbum.pl'; # path to the album script from web server root.

=back

=item 3

Refer to the script as:
I<http://www.youserver.here/cgi-bin/XPhotoAlbum.pl?index=B</album/index.xml>&type=B<type>> to be translated.

=over 

=item *

B</album/index.xml> - is relative url to the XML file with the album index.

=item *

B<type> - is one of the three album types:

=over

=item a.

B<IE> - Three pane DHTML (client side) browsing (Internet Explorer only).

=item b.

B<thumb> - Thumbnail based album (Internet Explorer only).

=item c.

B<plain> - Plain text outline (all browsers).

=back

=back

=back

=head1 XML Index File Format

Please see the examples below to understand the format of the files.
However one nuance must be noticed regarding the thumbnail image files.
Thumbnails shiuld be placed in the directory B<thumb/> under image path. Thumbnail image names are derrived 
from regular images names appending B<_thumb> before file extension. For example
for file B<~john/Image.JPG> thumbnils is sought under B<~john/thumb/Image_thumb.JPG>.

=head1 CAVEATS

Send your feedback...

=head1 TIPS AND TRICKS

Send your feedback...

=head1 EXAMPLES

Please see http://www.neystadt.org/ for three instances of the albums using this technology.
Particulary examples of the XML index files are located at:

    http://www.neystadt.org/gal/birth/index.xml
    http://www.neystadt.org/john/album/index.xml 
    http://www.neystadt.org/leonid/album.xml

=head1 PREREQUISITES

This script requires the C<URI::Escape>, C<XML::DOM> 
modules available from CPAN (http://www.cpan.org)

=pod OSNAMES

All UNIXes, Windows NT

=pod SCRIPT CATEGORIES

Web

=pod README

This simple script can be used for organizing web photo album. The script can be used for online or Off-Line
photo album generation. It does not provides web interface for picture uploading, thumbnail generation or web 
authoring of the album. Those tasks you will have to do using standard image processing tools and ftp. However it generates
rather nice browsable photo album.

=cut
