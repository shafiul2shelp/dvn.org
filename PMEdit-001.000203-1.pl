#!/usr/bin/perl
use strict;
use warnings;

BEGIN {our @usedModules; unshift @INC, sub {push @usedModules, [@_]; return undef;}}

our @usedModules;

use Tk;
#use Tk::TextUndo; #Removed due to bugs that are too much effort to work around ATM
use Tk::Balloon;
use Tk::Clipboard;
use Storable qw(dclone);

my $VERSION = '001.000203'; # 1.0 Beta 3

use constant DEBUG => 0;
use constant kParaSpace => 6;

=head1 NAME

PMEdit - A wysiwyg PerlMonks.org markup savy editor.

=head1 DESCRIPTION

This script is a PerlMonks.org markup savy editor. It may be useful for most
everything based web sites and can be adapted for use for light weight HTML
generation.

=head1 README

PerlMonks editor is designed to allow wysiwig editing of material to be
posted on everything based web sites such as PerlMonks. Initial versions are
intended to be used to prepare the material offline and then render to the
clipboard for pasting into a node's edit field. It is expected that later
versions will interact more directly with the web site to allow easier
updating of existing nodes and quoting material from nodes that are being
replied to.

The current version is considered to be a beta version. It does some cool
stuff and the main intial features are implemented with a good number of bugs
ironed out. There are still various editing foibles due to the way the Tk Text
widget behaves that may get resolved before the notional final version 1
release, but more likely won't.

The current version provides configuration information for associating
markup with display styles, menu entries, key assignements and (in the
future) toolbar entries. The configuration is included in the script in a
__DATA__ section.

There are two sectons in the configuration data seperated by a line starting
with "#key ". The first section contains information mapping tags to display
formatting and management and output rendering. The lines are of the form:

tag name,HTML tag, UI text, flags, modifiers as key value pairs

For example

code,c,Code block,BFXCU,-spacing1 => 0,-spacing3 => 0,-foreground => #e0e0ff,-font => [-family => courier, -weight => bold]

=over 8

code: the name used internally for tagging text

c: the HTML or link element tag text

Code block: String that may be used in the user interface

BFXCU: flags that control display, placement and rendering

...: display formatting. See the Tk::Text TAGS section

=back

The following flags may be used:

=over 8

B: Block level element (paragraph tag <p>)

C: Clear all or specified tags: C or Ctag (note lower case). Allows code tags to
reset any other tags when the code tag format is applied for example.

F: Format tag (inline element such as bold <b>)

I: Item in a list. Implies B. Will get special display handling.

L: Link. Gets [] brackets to signal a PerlMonks link

N: Needs block level tag (any one of multiple): Ntag. Used to ensure a the
flaged tag is a child element of one of the specified element types. For example
a list item (I flag) would specify NolistNulist to indicate it must be contained
in a ol or ul element.

P: Applies to whole paragraph. Set for element types such as <centre> and <readmore>

R: Readmore text. <readmore> semantics (implies P)

S: Single spaced text. Prevents additional paragraph spacing on the displayed
text (doesn't affect output rendering).

U: Untranslated - don't translate entities. Used in code elements and other
elements to retain characters such as <>&[] as litteral characters.

X: Exclude all or specified tags: X or Xtag (note lower case). Prevent the
listed tags being applied in regions that contain the current tag. Used to
prevent formatting being applied in a code block for example.

=back

The second section describes key and menu bindings for tags. Eventually toolbar
support may be added also. The lines in this section are of the form:

tag,key,menu item,toolbar item,right click item

For example:

code,Control k,Format/Code,,Code

=over 4

code: the tag name used in the previous section

Control k: the key combination used to access the tag

Format/Code: the menu path to the entry used to access the tag. In this case a
'Code' entry would be created in the 'Format' menu

missing: The missing entry is a place holder for a toolbar entry

Code: the right click menu entry used to access the tag

=back

a special case entry is used to put dividers in menus. It is of the form:

-,-,Format/-,,

Note that menu entries are currently generated in the order that they are
specified in the configuration section.

=head1 PREREQUISITES

This script requires the following modules:

C<strict> C<warnings> C<Tk> C<Tk::Balloon> C<Tk::Clipboard> C<Storable>

=pod OSNAMES

any

=head1 AUTHOR

Peter Jaquiery <F<grandpa@cpan.org>>

=head1 COPYRIGHT

Copyright (c) 2006, Peter Jaquiery. All rights reserved.
This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=pod SCRIPT CATEGORIES

Web

=cut

our @bindings;       # Key, menu and toolbar bindings.
our @stdFlags;
our %tagTypes;

my $currentFile = '';
my %formatFonts;    # Fonts used in style tags. Keyed by tag
my %menuItems;      # Child menu widgets keyed by menu label path
my %entities =      # Entities we need to use outside code blocks
    (
    '&', '&amp;',
    '<', '&lt;',
    '>', '&gt;',
    '[', '&#91;',
    ']', '&#93;',
    );
my @filetypes = (
    ['PerlMonks editor', '.PMEdit',  'TEXT'],
    ['PerlMonks editor test', '.PMEditT',  'TEXT'],
    ['PerlMonks editor test', '.PMEditF',  'TEXT'],
    ['Text', '.txt',  'TEXT'],
    );

LoadConfig ();

my $mw = MainWindow->new (-title => "PerlMonks node editor");
my $text = $mw->Scrolled
    ('Text', -font => 'normal', -wrap => 'word', -scrollbars => 'e',);

my $status = $mw->Label(-width => 60, -relief => "sunken", -bd => 1, -anchor => 'w');
my $balloon = $mw->Balloon(-statusbar => $status);
my $msg = '';
my $balloonCharIndex = '';
my $balloonLastIndex = '';

$status->pack(-side => "bottom", -fill => "both", -padx => 2, -pady => 1);
#$balloon->attach
#    (
#    $text, -msg => \$msg,
#    -balloonposition => 'mouse',  # Not really used since the postcommand returns the real position.
#    -postcommand => \&balloonPostCommand,
#    -motioncommand => \&balloonMotionCommand,
#    );

my $menuBar = $mw->Menu (-type => 'menubar');

$mw->configure(-menu => $menuBar);
$text->pack (-expand => 'yes', -fill => 'both');

# Build file menu
$menuItems{'~File'} = $menuBar->cascade(-label => '~File', -tearoff => 0);
$menuItems{'~File'}->command (-label => '~Render', -command => \&fileRender);
$menuItems{'~File'}->command (-label => '~New', -command => \&fileNew);
$menuItems{'~File'}->command (-label => '~Open...', -command => \&fileOpen);
$menuItems{'~File'}->command (-label => '~Save', -command => \&fileSave);
$menuItems{'~File'}->command (-label => 'Save ~As...', -command => \&fileSaveAs);
$menuItems{'~File'}->command (-label => 'E~xit', -command => \&fileExit);

# Build menus and bind keys
my %commands = (
    selAll => \&do_selAll,
    copy => \&do_copy,
        paste => \&do_paste,
    );

my $realText = $text->Subwidget ('scrolled');

for my $tagData (@bindings) {
    my $menuPath = $tagData->[2];

    next if ! defined $menuPath;

    my $tag = $tagData->[0];
    my ($top, $item) = split '/', $menuPath;

    next if ! defined $item; # Not allowed in top level menus
    if (! defined $menuItems{$top}) {
        $menuItems{$top} = $menuBar->cascade(-label => $top, -tearoff => 0);
    }

    my $newItem;

    if ($tag eq '-') {
        $newItem = $menuItems{$top}->separator ();
        next;
    } elsif (exists $commands{$tag}) {
        $newItem = $menuItems{$top}->command
            (-label => $item, -command => $commands{$tag});
    } else {
        $newItem = $menuItems{$top}->command
            (-label => $item, -command => [\&doCommand, $tag]);
    }

    next if ! defined $tagData->[2];

    #Set up accelerator bindings
    my $key = $tagData->[1];

    next if ! length $key;

    my $ok = eval {
        if (exists $commands{$tag}) {
            $realText->bind ("<$key>" => $commands{$tag});
        } else {
            $realText->bind ("<$key>" => [\&keyCommand, $tag]);
        }
        
        1;
    };

    if (! $ok) {
        print "Unable to bind <$key> to <$tag>: $@\n";
        next;
    }
    
    $key =~ s/^Control/ctrl/;
    $key =~ s/^<Control\s(.*)>$/ctrl $1/;
    $newItem->configure (-accelerator => $key);
}

$realText->bindtags ([$realText, ref($realText), $realText->toplevel, 'all']);
$text->bind("<Return>", \&handleReturn);
$text->bind ('<Control i>', [\&keyCommand, 'italic']);

$menuItems{'~Help'} = $menuBar->cascade(-label => '~Help', -tearoff => 0);
$menuItems{'~Help'}->command (-label => '~PerlMonks Editor Help', -command => \&help);
$menuItems{'~Help'}->command (-label => '~About', -command => \&about);

# A couple of phantom paragraph spacing tags to ease calculating paragraph spacing
$text->tagConfigure("!para_start", -spacing1 => 0, -spacing3 => -(kParaSpace));
$text->tagConfigure("!para_end", -spacing1 => -(kParaSpace), -spacing3 => 0);

MainLoop ();


sub balloonPostCommand {
    return 0 if ! length $balloonCharIndex;

    my %balloonCharTags;
    my  $charIndex = $text->index ("$balloonCharIndex +1 char");

    @balloonCharTags{$text->tagNames()} = ($balloonCharIndex);

    # If no tags under mouse don't post the balloon.
    return 0 if ! %balloonCharTags;

    if (exists $balloonCharTags{name}) {
        my ($start, $end) = $text->tagPrevrange ('name', $balloonCharIndex);
        my $name = $text->get($start, $end);

        $name =~ s/\|.*//;
        $msg = "link to [${name}]'s home node";
    } elsif (exists $balloonCharTags{node}) {
        my ($start, $end) = $text->tagPrevrange ('node', $balloonCharIndex);
        my $node = $text->get($start, $end);

        $node =~ s/\|.*//;
        $msg = "link to node id $node";
        $msg .= ' (badly formed - digits only allowed)' if $node !~ /^\d+$/;
    } else {
        return 0;
    }

    my @p = $text->bbox($balloonCharIndex);
    my $x = $text->rootx + $p[0] + $p[2] - 4;
    my $y = $text->rooty + $p[1] + $p[3] + 2;
    print "-$x,$y-\n";
    return "$x,$y";
}


sub balloonMotionCommand {
    my $x = $text->pointerx - $text->rootx;
    my $y = $text->pointery - $text->rooty;

    $balloonCharIndex = $text->index ("\@$x,$y");

    # If the same char don't cancel the balloon.
    return 0 if $balloonLastIndex eq $balloonCharIndex;

    # New char under mouse - cancel it so a new balloon will be posted.
    $balloonLastIndex = $balloonCharIndex;
    print ">$balloonLastIndex<\n";
    return 1;
}


sub fileRender {
    $text->clipboardClear ();
    my @dumpText = $text->dump ('-tag', '-text', '1.0', 'end');
    $text->clipboardAppend (Render (\%tagTypes, @dumpText));
}


sub fileOpen {
    $currentFile = $text->getOpenFile
        (
        -defaultextension => '.pmEdit',
        -filetypes => \@filetypes
        );

    return if ! defined $currentFile;

    if (! open inFile, '<', $currentFile) {
        $text->messageBox
            (
            -title => 'Load failed', -icon => 'error',
            -type => 'Ok',
            -message => "Unable to open '$currentFile' - $!"
            );
        return;
    }

    my @oldTags = $text->tagNames ();
    $text->delete ('1.0', 'end -1 char');
    $text->tagDelete (@oldTags);

    my @tagStates;
    my $currLine = 1;

    while (<inFile>) {
        next if ! /-(\S+)\s([^-]+)-(.*)/;
        my ($type, $index, $item) = ($1, $2, $3);

        if ($type eq 'tagon') {
            push @tagStates, [$type, $index, $item] if $item !~ /^(?:!|_)/;
        } elsif ($type eq 'tagoff') {
            push @tagStates, [$type, $index, $item] if $item !~ /^(?:!|_)/;
        } elsif ($type eq 'text') {
            if ($currLine != int ($index)) {
                $currLine = int ($index);
                $text->insert ('end', "\n");
            }

            $text->insert ($index, $item);
        } else {
            print "Token type $type at $index not handled.\n";
        }
    }

    close inFile;

    my @activeList;
    my $lastIndex = '1.0';

    for my $this (@tagStates) {
        my ($type, $index, $item) = @$this;

        if (@activeList) {
            my @tagList = buildTag (@activeList);

            $text->tagAdd ($_, $lastIndex, $index) for @tagList;
            $lastIndex = $index;
        }

        if ($type eq 'tagon') {
            push @activeList, $item;
            $lastIndex = $index;
        } else {
            @activeList = grep {$_ ne $item} @activeList;
        }
    }

    fixParaSpacing ();
}


sub fileNew {
    my @oldTags = $text->tagNames ();
    $text->delete ('1.0', 'end -1 char');
    $text->tagDelete (@oldTags);
    $currentFile = undef;
}


sub fileSave {
    if (defined $currentFile and length $currentFile) {
        doSave ($currentFile);
    } else {
        fileSaveAs ();
    }
}


sub fileSaveAs {
    my $filename = $text->getSaveFile
        (-defaultextension => '.pmEdit', -filetypes => \@filetypes);
    doSave ($filename);
}


sub doSave {
    my $filename = shift;

    return if ! defined $filename or ! length $filename;

    open outFile, '>', $filename or
        $text->messageBox
            (
            -title => 'Save failed', -icon => 'error',
            -type => 'Ok',
            -message => "Unable to create '$filename' - $!"
            );
    my @dumpText = $text->dump ('-tag', '-text', '1.0', 'end');
    my ($html, $name, $mode, $params);

    while (@dumpText) {
        my ($type, $item, $index) = splice @dumpText, 0, 3;
        next if $type =~ /^tago(?:n|ff)$/ and $item =~ /^(?:_|!)/;
        print outFile "-$type $index-$item\n";
    }

    close outFile;
    $currentFile = $filename;
}


sub fileExit {
    exit 1;
}


sub keyCommand {
    my @params = @_;
    doCommand ($params[1]);
    Tk->break;
}


sub handleReturn {
    fixParaSpacing ();
}


sub doCommand {
    my %newTag = (tag => shift);
    my @selections = $text->tagRanges('sel');
    @newTag{'name', 'html', 'flags', 'params'} = @{$tagTypes{$newTag{tag}}};

    do {
        if (@selections) {
            my %tags;
            @tags{$text->tagNames($selections[0])} = (); # Preset current tags

            $newTag{isOn} = ! exists $tags{$newTag{tag}}; # Complement new tag's curr state
            $tags{$newTag{tag}} ||= $newTag{isOn};

            @newTag{'start', 'end'} = splice @selections, 0, 2;
        } else {
            my %activeTags;
            @activeTags{$text->tagNames('insert')} = ();
            return if ! exists $activeTags{$newTag{tag}};
            @newTag{'start', 'end'} = $text->tagPrevrange ($newTag{tag}, 'insert');
            $newTag{isOn} = 0;
        }

        return if ! defined $newTag{end};

        my $msg = $newTag{flags}{L} ? manageLink (%newTag) : updateTextTags (%newTag);

        if (length $msg) {
            $status->configure (-text => $msg);
            return;
        }


    } while (@selections);
}


sub updateTextTags {
    my %newTag = @_;
    my @dumpText = $text->dump ('-tag', '-text', $newTag{start}, $newTag{end});
    my @activeTags = $text->tagNames($newTag{start});
    my %tags;

    @tags{@activeTags} = (1) x @activeTags; # Preset current tags
    $tags{$newTag{tag}} = $newTag{isOn};

    TOKEN: while (@dumpText) {
        my ($type, $item, $index) = splice @dumpText, 0, 3;
        my $segEnd = exists $dumpText[2] ? $dumpText[2] : $newTag{end};

        if ($type eq 'tagon') {
            $tags{$item} = 1 if $item ne $newTag{tag};
        } elsif ($type eq 'tagoff') {
            $tags{$item} = 0 if $item ne $newTag{tag};
        } elsif ($type eq 'text') {
            my @tagList = grep {! /^_|^sel$/ && $tags{$_}} keys %tags;
            my @removeList = grep {! $tags{$_} || /^_/} keys %tags;

            # Bail if current tags preclude new tag
            for (@tagList) {
                next if ! exists $tagTypes{$_} or $newTag{tag} eq $_;
                my ($Ihtml, $Iname, $Iflags, $Iparams) = @{$tagTypes{$_}};

                # Check for existing tag that precludes all new tags
                if ($Iflags->{'X'}{'ALL'}) {
                    next TOKEN
                }

                # Check for existing tag that precludes $newTag
                if ($Iflags->{'X'}{$newTag{tag}}) {
                    next TOKEN;
                }
            }

            if ($newTag{isOn}) {
                if ($newTag{flags}->{'C'}{'ALL'}) {
                    # Strip all other tags
                    push @removeList, @tagList;
                } elsif (%{$newTag{flags}->{'C'}}) {
                    # Clear specific tags
                    push @removeList, keys %{$newTag{flags}->{'C'}};
                }
                push @tagList, $newTag{tag};
            }

            $text->tagRemove ($_, $index, $segEnd) for @removeList;

            @tagList = buildTag (@tagList);
            $text->tagAdd ($_, $index, $segEnd) for @tagList;
            fixParaSpacing ($index);
        } else {
            print "Token type $type at $index not handled.\n";
        }
    }

    return '';
}


sub manageLink {
    my %newTag = @_;
    my @activeTags = $text->tagNames($newTag{start});
    my %tags;

    if (! $newTag{isOn}) {
        # Remove the link
        $text->tagRemove ($newTag{tag}, $newTag{start}, $newTag{end});
        updateTextTags (%newTag);
        return '';
    }

    @tags{@activeTags} = (1) x @activeTags; # Preset current tags
    for (keys %tags) {
        next if ! exists $tagTypes{$_};
        return 1 if $newTag{tag} eq $_ and $newTag{isOn}; # Link already

        my ($Ihtml, $Iname, $Iflags, $Iparams) = @{$tagTypes{$_}};
        return "Can't link inside $Iname" if $Iflags->{'X'}{'ALL'};
        return "Can't link inside $Iname" if $Iflags->{'X'}{'link'};
    }

    return 'Links must not span line ends.'
        if int ($newTag{start}) != int ($newTag{end});

    # Get the link text
    my $orgLinkText = $text->get($newTag{start}, $newTag{end});
    my ($linkStr, $textStr) = $orgLinkText =~ /^([~|]*\|?)(.*)/;
    my $indexStr = "$newTag{start} +" . length ($linkStr) . 'chars';
    my $linkEnd = $text->index ($indexStr);
    my %linkTag = %{dclone (\%newTag)};
    my %textTag = %{dclone (\%newTag)};

    $linkTag{end} = $linkEnd;
    $textTag{start} = $linkEnd;

    updateTextTags (%linkTag);
    updateTextTags (%textTag);
    return '';
}


sub do_selAll {
    $text->selectAll ();
    Tk->break ();
}


sub do_copy {
    $text->clipboardColumnCopy ();
}


sub do_paste {
    $text->clipboardPaste ();
}


sub buildTag {
    my %tags;

    @tags{@_} = ();

    my @tagList = sort keys %tags;
    my $newFormatTag = '_' . join '_', @tagList;
    my %options;
    my %fontParams;

    for (@tagList) {
        next if ! exists $tagTypes{$_} || ! ref $tagTypes{$_};

        my ($html, $name, $mode, $params) = @{$tagTypes{$_}};
        next if ! ref $params;

        for my $type (keys %$params) {
            if ($type =~ /-font/) {
                for my $subType (keys %{$params->{$type}}) {
                    $fontParams{$subType} = $params->{$type}{$subType};
                }
            } else {
                $options{$type} = $params->{$type};
            }
        }
    }

    $options{-font} = buildFont (%fontParams) if %fontParams;
    $text->tagConfigure ($newFormatTag, %options);

    push @tagList, $newFormatTag;
    return @tagList;
}


sub buildFont {
    my %options = @_;
    my $fontName = '';

    $fontName .= "$_|$options{$_}," for sort keys %options;
    $fontName =~ tr/-+/mp/;
    $fontName =~ tr/a-zA-Z0-9/mp_/c;
    $mw->fontCreate($fontName, %options) if ! $formatFonts{$fontName}++;
    return $fontName;
}


sub fixParaSpacing {
    my $targetLine = shift;

    if (! defined $targetLine) {
        fixGlobalParaSpacing ();
        return;
    }
}


sub fixGlobalParaSpacing {
    my $lastLine = ($text->index ('end') =~ /(\d+)/)[0];
    my $lastTailSpace = -(kParaSpace);
    my @paraTags;

    push @paraTags, "!para_$_" for (1..$lastLine);
    $text->tagDelete (@paraTags); # Clear current spacing tags

    for my $line (1..$lastLine) {
        my $headSpace = kParaSpace;
        my $tailSpace = kParaSpace;
        my @activeTags = $text->tagNames("$line.0");

        # Note that this is currently broken if the first character happens to be a
        # part of a single spaced style applied to a partial line
        for (@activeTags) {
            next if ! exists $tagTypes{$_} || ! ref $tagTypes{$_};

            my ($html, $name, $mode, $params) = @{$tagTypes{$_}};
            next if ! ref $params;

            for my $type (keys %$params) {
                $headSpace = $params->{$type} if $headSpace && $type =~ /-spacing1/;
                $tailSpace = $params->{$type} if $tailSpace && $type =~ /-spacing3/;
            }
        }

        if ($lastTailSpace == -(kParaSpace)) {
            $headSpace = 0;
        } elsif ($lastTailSpace == 0 && $headSpace > 0) {
            $headSpace += kParaSpace;
        } elsif ($lastTailSpace > 0 && $headSpace == 0) {
            $headSpace += kParaSpace;
        }

        $text->tagConfigure("!para_$line", -spacing1 => $headSpace, -spacing3 => $tailSpace);
        $text->tagAdd ("!para_$line", "$line.0");
        $text->tagRaise ("!para_$line");
        $lastTailSpace = $tailSpace;
    }
}


sub help {
    my $msg = <<MSG;
This editor is designed to provide wysiwyg editing for PerlMonks.org nodes. The
contents of the node is edited off-line and rendered (File|Render) to the
clipboard for pasting into a node's text edit field.

Feedback can be /msged to GrandFather in the first instance. If you provide an
email address in your /msg, GrandFather will most likely reply to the email
address.
MSG

    $mw->messageBox (
        -icon => 'info',
        -message => $msg, -title => 'PerlMonks Editor Help',
        -type => 'Ok',
        );
}


sub about {
    my $versions = '';
    for (sort @usedModules) {
        my $name = $_->[1];

        $name =~ s/\..*//;
        $name =~ s|[\\/]|::|g;
        next if $name =~ /^::/;

        my $version = $name->VERSION;
        $versions .= "$name \t$version\n" if defined $version;
    }

    my $msg = <<"MSG";
PerlMonks Editor

Written by GrandFather for the assistance, pleasure and edification of other
monks.

Module\tVersion
PMEdit\t$VERSION
$versions
MSG

    $mw->messageBox (
        -icon => 'info',
        -message => $msg, -title => 'About PerlMonks Editor',
        -type => 'Ok',
        );
}


use constant TYPE => 0;
use constant VALUE => 1;
use constant INDEX => 2;


sub Render {
    my $tagTypes = shift;
    my $blockType;
    my ($html, $name, $mode, $params);
    my $chunk = '';

    my @chunks = preprocessDump ($tagTypes, @_);
    my @paragraphs;
    my $paragraph;
    my %bfTags; # track block/format tag usage

    for (@chunks) {
        my ($type, $item, $index) = @$_;

        #next if $type =~ m/^tago(?:n|ff)$/ and $item =~ m'^(?:sel|_|!)'; # Ignore

        if ($type eq 'para' && defined $paragraph && length $paragraph) {
            # Start of new paragraph
            my ($endCharIndex) = $item =~ /\.(\d+)/;

            # Figure out if previous is a non-p block
            my $paraType;
            for my $tag (keys %bfTags) {
                # Check for Block/Format (code for example) tags in block mode
                my $on = exists $bfTags{$tag}{on} && $bfTags{$tag}{on};
                my $off = exists $bfTags{$tag}{off} && $bfTags{$tag}{off};

                next if $on != 1;
                next if $off != 1;

                my ($lastOffChar) = $bfTags{$tag}{lastOffAt} =~ /\.(\d+)/;
                my ($firstOnChar) = $bfTags{$tag}{firstOnAt} =~ /\.(\d+)/;

                next if $lastOffChar != $endCharIndex or $firstOnChar != 0;
                $paraType = $tag;
            }

            if (! defined $paraType) {
                $paragraph = "<p>$paragraph</p>" ;
            } else {
                # Ensure open tag is followed by a new line
                $paragraph =~ s|^(<$paraType>)(?!\n)|$1\n|;
                # Ensure close tag is preceeded by a new line
                $paragraph =~ s|(?<!\n)(</$paraType>)|\n$1|;
            }

            push @paragraphs, $paragraph;
            print "\n" if DEBUG > 1;
            $paragraph = '';
            %bfTags = ();
            next;
            }

        #next unless definedValue($tagTypes, $item);
        if ($type eq 'tagon') {
            # Render on tags
            my ($html, $name, $mode, $params) = @{$tagTypes->{$item}};

            $bfTags{$item}{on}++ if $mode->{'B'} && $mode->{'F'};
            $bfTags{$item}{firstOnAt} = $index if ! exists $bfTags{$item}{firstOnAt};

            if ($mode->{L}) {
                $html =~ s/\w+\s?//;
                $chunk .= "[$html";
                next;
            } elsif ($mode->{'B'} && $index =~ /\.0$/) {
                $blockType = $html;
            }

            $chunk .= "<$html>";
            next;
        }

        if ($type eq 'tagoff') {
            # Render off tags
            my ($html, $name, $mode, $params) = @{$tagTypes->{$item}};

            $bfTags{$item}{off}++ if $mode->{'B'} && $mode->{'F'};
            $bfTags{$item}{lastOffAt} = $index;

            if ($mode->{L}) {
                $chunk .= ']';
            } elsif (defined $blockType && $blockType eq $html && $mode->{'B'} && $index =~ /\.0$/) {
                $chunk .= "</$blockType>\n";
                $blockType = undef;
            } else {
                $chunk .= "</$tagTypes->{$item}[TYPE]>";
            }

            next;
        }

        next if $type eq 'para';

        if ($type ne 'text') {
            print "Token type $type at $index not handled.\n";
        }

        $chunk .= $item if defined $item; # Add the text
    } continue {
        if (length ($chunk)) {
            print $chunk if DEBUG > 1;
            $chunk =~ s/\n\Z//;
            $paragraph .= $chunk;
            $chunk = '';
        }
    }

    my $result = join "\n", @paragraphs;
    $result =~ s|<p></p>|<br>|gm;
    $result =~ s|\n</code>\n<code>\n|\n|gm;
    $result =~ s|\n<code>(?!\n)|\n<code>\n|gm;
    $result =~ s|(?<!\n)</code>\n|\n</code>\n|gm;
    $result .= "\n<!-- Generated using PerlMonks editor version $VERSION -->";
    print $result if DEBUG;
    return $result;
}

sub preprocessDump {
    my $tagTypes = shift;
    my @paragraphs;
    my @paragraph;
    my @chunks;

    # Pull out individual edit elements
    push @chunks, [splice @_, 0, 3, ()] while @_;

    @chunks = grep
        {$_->[TYPE] !~ m/^tago(?:n|ff)$/ or $_->[VALUE] !~ m/^(?:sel|_|!)/}
        @chunks;

    my $lastLineNum = 1;
    my $lineNum;
    for my $chunk (@chunks) {
        $chunk->[VALUE] =~ s/\n//g;
        ($lineNum) = $chunk->[INDEX] =~ /(\d+)/;

        next if $lastLineNum == $lineNum;

        push @paragraphs, [@paragraph];
        @paragraph = ();
    } continue {
        push @paragraph, $chunk;
        $lastLineNum = $lineNum;
    }

    push @paragraphs, [@paragraph] if @paragraph;

    # Migrate 'off' tags from start of current paragraph to end of previous
    my $lastPara;
    my $lastParaEndIndex;

    for my $para (@paragraphs) {
        next if ! defined $lastPara;
        next if @$para < 2; # Don't move single tags

        for (@$para) {
            next if $_->[TYPE] eq 'tagon';
            last if $_->[TYPE] ne 'tagoff';
            push @$lastPara, splice @$para, 0, 1;
            $lastPara->[-1][2] = $lastParaEndIndex;
        }
    } continue {
        $lastPara = $para;

        my ($line, $offset) = $lastPara->[-1][2] =~ m/(\d+)\.(\d+)/;

        $offset += length ($lastPara->[-1][1]) if $lastPara->[-1][0] eq 'text';
        $lastParaEndIndex = "$line.$offset";
    }

    # Finally unpack the paragraphs and provide missing tags
    my %tags;
    @chunks = ();
    for my $paragraph (@paragraphs) {
        my $startIndex = $paragraph->[0][INDEX];
        my @tagNesting;
        my $endIndex = int ($startIndex) . 'end';

        # Ignore bogus paragraphs
        if (1 == @$paragraph && $paragraph->[0][TYPE] eq 'tagoff') {
            my $type = $paragraph->[0][VALUE];
            #next unless definedValue($tagTypes, $type);
            
            my ($html, $name, $mode, $params) = @{$tagTypes->{$type}};

            next if $mode->{'B'}; # Skip orphaned terminating block level tag
        }

        # Provide tagons at start of paragraph
        for (grep {$tags{$_}} sort keys %tags) {
            push @chunks, ['tagon', $_, $startIndex];
            push @tagNesting, $_;
        }

        for my $chunk (@$paragraph) {
            $endIndex = $chunk->[INDEX];

            if ($chunk->[TYPE] eq 'tagon') {
                $tags{$chunk->[VALUE]}++;
                push @tagNesting, $chunk->[VALUE];
            }elsif ($chunk->[TYPE] eq 'tagoff') {
                # Manage correct nesting of tags by supplying off tags as required
                my $matchIndex;
                my $chunkIndex = $chunk->[INDEX];

                for (reverse 0 .. $#tagNesting) {
                    if ($tagNesting[$_] eq $chunk->[VALUE]) {
                        $matchIndex = $_;
                        last;
                    }

                    push @chunks, ['tagoff', $tagNesting[$_], $chunkIndex];
                }

                push @chunks, $chunk;
                $tags{$chunk->[VALUE]}--;
                splice @tagNesting, $matchIndex, 1;
                push @chunks, ['tagon', $tagNesting[$_], $chunkIndex]
                    for $matchIndex .. $#tagNesting;
                next; # Avoid pushing chunk twice
            } elsif ($chunk->[TYPE] eq 'text') {
                $endIndex =~ /(\d+)\.(\d+)/;
                $endIndex = "$1." . ($2 + length $chunk->[VALUE]);
            }

            push @chunks, $chunk;
        }

        # Provide tagoffs at end of paragraph
        for my $tag (reverse @tagNesting) {
            push @chunks, ['tagoff', $tag, $endIndex];
        }

        $startIndex = int ($endIndex + 1) . '.0';
        push @chunks, ['para', $endIndex, $startIndex];
    }

    return @chunks;
}


sub definedValue {
    my ($hash , $key) = @_;
    return exists $hash->{$key} && defined $hash->{$key};
}




BEGIN {
    our @stdFlags = (
        'B', # Block level element
        'C', # Clear all or specified tags: C or Ctag (note lower case)
        'F', # Format tag (inline element)
        'I', # Item in a list. Implies B
        'L', # Link
        'N', # Needs block level tag (any one of multiple): Ntag
        'P', # Applies to whole paragraph
        'R', # Readmore text
        'S', # Single spaced text
        'U', # Untranslated - don't translate entities
        'X', # Exclude all or specified tags: X or Xtag (note lower case)
        );
}

sub LoadConfig {
    my $ok = 1;

    while (<DATA>) {
        # Load the default configuration stuff
        s/^\s+//;
        s/\s+$//;
        next if ! length;
        last if /^#key /;
        next if /^#/;

        my ($tag, $htmlTag, $name, $flagsField, @options) = split /\s*,\s*/;

        if (! defined $flagsField) {
            print "Missing entries in tag line ($.): $_";
            $ok = 0;
            next;
        }

        # pull out flags and handle X and C special case flags
        my %flags;
        @flags{@stdFlags} = (0) x @stdFlags; # Preset flags off
        $flags{'C'} = {};
        $flags{'N'} = {};
        $flags{'X'} = {};

        for (split /(?=[A-Z][a-z]*)/, $flagsField) {
            my ($flag, $value) = split /(?<=[A-Z])/, $_;

            if (! exists $flags{$flag}) {
                print "Unhandled flag '$flag' used\n";
                $ok = 0;
            }

            if (-1 != index 'XC', $flag) {
                $flags{$flag}{$value || 'ALL'} = 1;
                $flags{'C'}{$value || 'ALL'} = 1 if $flag eq 'X'; # X implies C
            } elsif ($flag eq 'N') {
                if (! defined $value) {
                    print "Flag N requires a block tag - it has been ignored for $tag.\n";
                } else {
                    $flags{$flag} = $value || 1;
                }
            } else {
                $flags{$flag} = $value || 1;
                $flags{'B'} = $value || 1 if $flag eq 'I';
            }
        }

        #Fix up options
        my $optionStr = join ', ', @options;
        my %optionHash;

        while ($optionStr =~ /\G,?\s*((?:(?!=>).)*)=>\s*(\[[^\]]*\]|[^,]*),?\s*/g) {
            my ($option, $value) = ($1, $2);

            trim (\$option, \$value);

            if ($value =~ s/\[|\]//g) {
                # Nested options. Turn them into a hash
                my @options = split ',', $value;
                my %optionHash;

                for (@options) {
                    my ($suboption, $subvalue) = split /\s*=>\s*/;

                    last if ! defined $subvalue;
                    trim (\$suboption, \$subvalue);
                    $optionHash{$suboption} = $subvalue;
                }

                $value = \%optionHash;
            }

            $optionHash{$option} = $value;
        }

        $tagTypes{$tag} = [$htmlTag, $name, \%flags, \%optionHash];
    }

    while (<DATA>) {
        # Load key binding information
        next if /^#/;
        
        s/^\s+//;
        s/\s+$//;
        
        next if ! length;

        my ($tag, $key, $menuItem, $toolbarItem, $rightClickItem) = split /\s*,\s*/;
        if (! defined $tag) {
            print "Missing tag in binding line ($.): $_";
            $ok = 0;
            next;
        }

        push @bindings, [$tag, "$key", $menuItem, $toolbarItem, $rightClickItem];
    }

    return $ok;
}



sub trim {
    for (@_) {
        $$_ =~ s/^\s+//;
        $$_ =~ s/\s+$//;
    }
}


__DATA__
#tag style definitions
#tag name,HTML tag, UI text, flags, modifiers as key value pairs
big,big,Big font,F,-font => [-size => 16]
bold,b,Bold,F,-font => [-weight => bold]
center,center,Centered text,P,-justify => center
code,code,Code block,BFXCU,-spacing1 => 0,-spacing3 => 0,-foreground => #8080e0,-font => [-family => courier, -weight => bold]
dd,dd,Definition Description,B,
del,del,Deleted Text,F,
dl,dl,Definition List,B,-lmargin1 => 20m, -lmargin2 => 20m, -rmargin => 20m
dt,dt,Definition Term,B,-lmargin1 => 10m, -lmargin2 => 10m, -rmargin => 10m, -font => [-weight => bold]
emphasis,em,Emphasis,F,-font => [-slant => italic]
h3,h3,Header level 3,B,-font => [-size => 24], -background => #c0c0c0,-spacing1 => 18
h4,h4,Header level 4,B,-font => [-size => 24], -background => #8080c0,-spacing1 => 14
h5,h5,Header level 5,B,-font => [-size => 16], -background => #c0c0c0,-spacing1 => 14
h6,h6,Header level 6,B,-font => [-size => 16], -background => #8080c0,-spacing1 => 10
hrule,hr,Horizontal rule,BX,
inserted,ins,ins,BF, -background => #ffffc0,
italic,i,Italic,F,-font => [-slant => italic]
item,li,List item,INolNul,
olist,ol,Ordered list,B,-lmargin1 => 20m, -lmargin2 => 20m, -rmargin => 20m
quote,blockquote,Quoted block,P,-lmargin1 => 15m,-lmargin2 => 15m,-rmargin => 15m
readmore,readmore,Read more block,BR,-background => #a0b7ce
small,small,small,F,-font => [-size => 8]
spoiler,spoiler,Spoiler,B, -background => #000000, -foreground => #404040,
strike,strike,Strike Out,F,-overstrike => on
strong,strong,Strong emphasis,F,-font => [-weight => bold]
sub,sub,Sub script,FCsuper,-offset => -2p,-font => [-size => 8]
super,sup,Super script,FCsub,-offset => 4p,-font => [-size => 8]
teletype,tt,Teletype text,F,-font => [-family => courier], -background => #FFFFc0
ulist,ul,Unordered list,B,-lmargin1 => 20m, -lmargin2 => 20m, -rmargin => 20m
underline,u,Underline,F,-underline => 1,

#links - still tag style definitions
acronym,link acronym://,Acronym link,L, -underline => 1, -foreground => #0060c0,
cpan,link cpan://,Cpan link,L, -underline => 1, -foreground => #00a0a0,
dict,link dict://,Dictionary link,L, -underline => 1, -foreground => #00a0a0,
dist,link dist://,CPAN Distro link,L, -underline => 1, -foreground => #00a0a0,
doc,link doc://,perldoc link,L, -underline => 1, -foreground => #00a0a0,
ftp,link ftp://,Ftp link,L, -underline => 1, -foreground => #00a0a0,
google,link google://,Google link,L, -underline => 1, -foreground => #00a0a0,
href,link href://,Href link,L, -underline => 1, -foreground => #00a0a0,
http,link http://,Http link,L, -underline => 1, -foreground => #00a0a0,
https,link https://,Https link,L, -underline => 1, -foreground => #00a0a0,
id,link id://,Node id link,L, -underline => 1, -foreground => #00a0a0,
isbn,link isbn://,Isbn link,L, -underline => 1, -foreground => #00a0a0,
jargon,link jargon://,Jargon link,L, -underline => 1, -foreground => #00a0a0,
kobes,link kobes://,Kobes link,L, -underline => 1, -foreground => #00a0a0,
lj,link lj://,Live journal link,L, -underline => 1, -foreground => #00a0a0,
lucky,link lucky://,Google lucky link,L, -underline => 1, -foreground => #00a0a0,
mod,link mod://,Mod link,L, -underline => 1, -foreground => #00a0a0,
module,link module://,Module link,L, -underline => 1, -foreground => #00a0a0,
name,link,Node name link,L, -foreground => #0060c0, -underline => 1
pad,link pad://,Scratchpad link,L, -underline => 1, -foreground => #00a0a0,
perldoc,link perldoc://,Perldoc link,L, -underline => 1, -foreground => #00a0a0,
pmdev,link pmdev://,Pmdev link,L, -underline => 1, -foreground => #00a0a0,
readmore,readmore,Readmore,RB,-stipple => 1,
wp,link wp://,Wp link,L, -underline => 1, -foreground => #00a0a0,

#key bindings, menu items and tool bar items
#tag,key,menu item,toolbar item,right click item
selAll,Control a,Edit/Select All,,Select All
copy,Control c,Edit/Copy,,Copy
paste,<Control v>,Edit/Paste,,Paste
big,Control 2,Format/Big,,Big
bold,Control b,Format/Bold,,Bold
center,,Format/Center,,Center
italic,Control i,Format/Italic,,Italic
item,,Format/List item,,List item
small,Control s,Format/Small,,Small
strike,Control s,Format/Strike out,,Strike out
sub,Control u,Format/Subscript,,Subscript
super,Control s,Format/Superscript,,Superscript
underline,Control underscore,Format/Underline,,Underline
-,-,Format/-,-,
code,Control k,Format/Code,,Code
quote,Control q,Format/Blockquote,,Blockquote
ulist,,Format/Unordered list,,Unordered list
#links - still bindings
cpan,,Links/CPAN,,CPAN link
id,Control d,Links/Node,,Node id link
name,Control n,Links/Name,,Node name link