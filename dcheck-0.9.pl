#!/usr/bin/perl -w

=head1 NAME

dcheck - a date-in-file checker and adjuster

=head1 SCRIPT CATEGORIES

Web

=head1 SYNOPSIS

 dcheck [-riyuefcbht] [file/path...] [-m pattern]
        [-d datestyle] [-x ext] [-a path] [-v level]
	[--no-recurs] [--match=pattern] [--no-bin]
	[--date-style=datestyle] [--short-year]
	[--mdate-err] [--nodate-err] [--force-date] [--correct]
	[--backup] [--bak-ext=ext] [--bak-path=path]
	[--help] [--settings] [--verbose=level]

=head1 README

This script checks given files for dates matching a given format and compare
this with the date of last modification of the file.

Actually the script can do the following:

=over 4

=item *

Find and correct false dates.

=item *

Find files without any date.

=item *

Force dates if no date found.

=item *

Find files with more than one date.

=back

The main motivation for writing this script was to adjust the dates of last
modification in today over 1.100 pages on a constantly growing website. Later
I used it for other web-projects, for memos, source codes...

You specify all options by using the command line. The following is the hole
story about this options:

=head2 Directories and Files

All non-options found in commandline assumed to be either a file or a path.
Files and paths can be mixed together (also with options) but the paths should
be valid and will direct send to the find-routine from C<File::Find> for
(recursivly) scanning. B<Note!> You can use your shell-globbing commandline to
submit many files but they also have to pass the C<-m> match if given. If no
file and no path given the current workdirectory is used.

=over 4

=item -r, --no-recurs

No recursive file scanning.

=item -m, --match

Regular expression for files to match. Use Doublequotes to submit complex RXs.
B<Note!> The complete filename including the path is tested. Multiple entries
are possible but the order is important for speed. All files will checked if
not set. (the default behavior)

=item -i, --no-bin

If you don't want to check binary files you have to set this flag. The test is
made by Perls Filetestoperator.

=back

=head2 Date to match

=over 4

=item -d, --date-style

The style of the date to match.

The syntax for submitting datestyles is similar to the syntax of the C<date>
command known in the unix-world. You specify a line containing some directives
which matching and producing parts of a date. All directives starts with '%'
followed by one char. All other chars will used unchanged.

Possible directives:

     %d  %D    Day
     %m  %M    Month
     %y  %Y    Year
     %t  %T    Minute
     %s  %S    Second
     %h  %H    Hour
     %%        simple matchs and produces '%'

The Year-directive looks for numeric fields with exactly two (%y) or exactly
four (%Y) digits. All other directives are looking for one or two digits.
Use the uppercase chars to produce numeric fields with leading zeroes.

This datestyle is used to create an format-string for the printf-routine and
an regular expression to match the date. Also the order of the items extracted
from there. You can view this variables by using the C<-s> flag.

Examples for datestyles:

    # simple
    %D-%M-%Y            => 20-07-1973
    %M/%D/%Y            => 07/20/73
    
    # with time
    %D-%M/%Y %H:%T      => 20-07/1973 07:10
    %D-%M-%Y %H:%T:%S   => 20-07-1973 07:10:24
    
    # short
    %d/%m %h:%m         => 20/7 7:10
    
    # with static stuff
    modified %D-%M-%Y   => modified 20-07-1973

=item -y, --short-year

Produces 2-digit years. This is bad! If not set and datestyles like %d-%m-%y
used all dates causes errors because the script produces 4-digit years by
default. Use only if there is a good reason for keeping short years. The
script can be used to convert short to long years this way:

    # files containing dd/mm/yy

    dcheck -d "%d/%m/%y" -c

    # many errors follows, all errors will corrected with long year
    # now you have to change your datestyle to match long years

    dcheck -d "%d/%m/%Y"
    
    # no more errors

=back

=head2 Error-correcting and backup

All found errors will displayed on STDERR and possible corrected.

=over 4

=item -u, --mdate-err

Files with more than one date causes errors. This errors could'nt be corrected
but will reported with linenumbers for easy finding them.

=item -e, --nodate-err

Files without date causes errors.

=item -f, --force-date

Any files must have a date otherwise the file will expanded by a line
containing the date in the actual format. Sets C<-e>. No changes will made
unless the C<-c> flag is given. B<Note!> Be very very carefull with that flag!
Using it without neither the C<-i> nor the C<-m>-flag can destroy all your
binary stuff!

=item -c, --correct

Determines if found errors will be corrected.

=item -b, --backup

Keeping backups of changed files. I<This is strongly recommented.>

=item -x, --bak-ext

Extension for backup-files. Not in use if a backup-path is specified.

=item -a, --bak-path

Path to hold the backups. If this path is given the directory-structure of the
original data is copied there if backups necessary. The file-names keeping
untouched. You can simply delete this backuptree later or use it to restored
your original data. Overrides C<-x>.

=back

=head2 User-interface

=over 4

=item -h, --help

Shows a usage-summary and exits.

=item -s, --settings

Shows the actual settings (and dependence) and exits.

=item -v, --verbose

Show statusmessages during run. 0=silent...3=noisy.

=back

=head1 EXAMPLES

    # This checks every found file in ~/public_html for a date
    # matching the given style and report false dates. No changes.

    dcheck ~/public_html -d "last changed: %M/%D/%Y"
    
    # The same but files without any date causes errors.

    dcheck ~/public_html -e -d "last changed: %M/%D/%Y"

    # This checks all files found in the current workdir and matching
    # the -m regex (should be .htm and .html). Dates will corrected
    # if necessary and backups of the changed files will stored
    # in ~/bak with the original names.

    dcheck -a ~/bak -b -c -m "\.html?$" -d "last changed: %D/%M/%Y"

    # The same but the backup files will stored in the same directory
    # like the original file with the extension "bak".
    
    dcheck -b -c -m "\.html?$" -d "last changed: %D/%M/%Y"

    # The same but files without any date will expanded by one
    # line containing the date of last modification in the given format.
    # No backups will made (bad).

    dcheck -c -f -m "\.html?$" -d "last changed: %D/%M/%Y"

    # The same but the date contains time-information
    
    dcheck -c -f -m "\.html?$" -d "last changed: %D/%M/%Y %H:%T:%S"

=head1 COPYRIGHT

Copyright (c) 1999 S<Bertram Wegener> <bertram@island.free.de>. All rights
reserved. This program is free software. You may modify and/or distribute it
under the same terms as Perl itself. This copyright notice must remain
attached to the file.

=head1 TODO

=over 4

=item *

Matching and producing Names of Days/Months. Any suggestions?

=back

=cut


## ----------------------------------------------------------------------------
## now we begin with working code

my $VERSION = 0.9;

use strict;
$|++;

use File::Find;
use File::Basename;
use File::Path;
use File::Copy;
use Getopt::Long;
use Cwd;


## ----------------------------------------------------------------------------
## definitions section:
## (the next values are defaults and will overwritten by using the commandline)

my $VERBOSE     = 1;                    # 0..3
my $SHOWHELP    = 0;	                # set/unset
my $SETTINGS    = 0;                    # set/unset
my $CORRECT     = 0;                    # correct errors?
my $BACKUP      = 0;                    # keep backup-files?
my $BACKUPEXT   = "bak";                # the extension for backup-files
my $BACKUPPATH  = "";                   # copy the backups to this path
my $DATESTYLE   = "modified %D-%M-%Y";  # the date definition
my $SHORTYEAR   = 0;                    # produce short years (bad)
my $NODATEERR   = 0;                    # files without date causes errors?
my $MDATEERR    = 0;                    # files with more than one date causes errors?
my $FORCEDATE   = 0;                    # force a date in file?
my $NORECURS    = 0;                    # recurs into subdirs?
my $NOBIN       = 0;                    # don't perform binaries?
my @NODES       = ();                   # files/paths to scan
my @REGEXS      = ();                   # regex to match for file (no if empty)

## end of definition-section


## ----------------------------------------------------------------------------
## now follows some usage-information for the user

(my $progname = $0) =~ s!^.*/!!; # kill any path-information from my progname

my $short_usage = "Usage: $progname [--help] [options]... [file/path]... \n";

my $long_usage  = <<END_OF_LONG_USAGE;

$progname $VERSION: checks and adjusts dates in files.

Usage: dcheck [-riyuefcbht] [file/path...] [-m pattern]
              [-d datestyle] [-x ext] [-a path] [-v level]
	      [--no-recurs] [--match=pattern] [--no-bin]
	      [--date-style=datestyle] [--short-year]
	      [--mdate-err] [--nodate-err] [--force-date] [--correct]
	      [--backup] [--bak-ext=ext] [--bak-path=path]
	      [--help] [--settings] [--verbose=level]

Directories & Files:
file/path         files/paths to scan
	          (default: current workdirectory)
-r, --no-recurs   don't go to subdirectories
                  (default: $NORECURS)
-m, --match RX    only files matching this regular expression will checked
                  (default: "@REGEXS")
-i, --no-bin      don't perform binary files
                  (default: $NOBIN)
		 
Date to match:
-d, --date-style  the style of the date to match
                  possible directives %d %D %m %M %y %Y %h %H %t %T %s %S %%
		  (default: "$DATESTYLE")
-y, --short-year  produces 2-digit years (this is bad)
                  (default: $SHORTYEAR)		 

Error-correcting and backup:
-u, --mdate-err   files with more than one date causes errors
                  note! these errors could'nt be corrected
	          (default: $MDATEERR)
-e, --nodate-err  files without date causes errors
                  (default: $NODATEERR)
-f, --force-date  any files must have a date otherwise a date is printed in
                  the actual format to the last line, sets -e, needs -c
		  (default: $FORCEDATE)
-c, --correct     determines if found errors will be corrected (including -f)
                  (default: $CORRECT)
-b, --backup      keeping backups of changed files
                  (default: $BACKUP)
-x, --bak-ext     extension for backup-files
                  (default: "$BACKUPEXT")
-a, --bak-path    path to copy the backups, overrides -x
                  (default: "$BACKUPPATH")
All found errors will displayed and possible corrected.
		 
User-interface:
-h, --help        shows this usage-summary
-s, --settings    shows the actual settings and exits
-v, --verbose     show statusmessages during run
                  0=silent...3=noisy (default: $VERBOSE)

author address: <bertram\@island.free.de>

END_OF_LONG_USAGE


## ----------------------------------------------------------------------------
## ok, now we get the information from the commandline

GetOptions(
    "r|no-recurs"    => \$NORECURS,
    "m|match=s"      => \@REGEXS,
    "i|no-bin"       => \$NOBIN,
    "d|date-style=s" => \$DATESTYLE,
    "y|short-year"   => \$SHORTYEAR,
    "u|mdate-err"    => \$MDATEERR,
    "e|nodate-err"   => \$NODATEERR,
    "f|force-date"   => \$FORCEDATE,
    "c|correct"      => \$CORRECT,
    "b|backup"       => \$BACKUP,
    "x|bak-ext=s"    => \$BACKUPEXT,
    "a|bak-path=s"   => \$BACKUPPATH,
    "h|help"         => \$SHOWHELP,
    "s|settings"     => \$SETTINGS,
    "v|verbose=i"    => \$VERBOSE,
    "<>"             => sub { push @NODES, @_ },    # nonopts are files/paths
)            	     or  die $short_usage;          # options-error


## ----------------------------------------------------------------------------
## some options need work now

$SHOWHELP    and die $long_usage;                  # help wanted

@NODES       or  push @NODES, cwd();               # no path given -> use workdir

$BACKUPPATH  and $BACKUPEXT = "overwritten by -a"; # -a overrides -x

$FORCEDATE   and $NODATEERR = 1;                   # -f sets -e

my $YEARADD  = $SHORTYEAR ? 0 : 1900;              # short years are very bad


## ----------------------------------------------------------------------------
## build the formatstring, regex-string and extract order from given datestyle
##
## We scan the datestyle for %-directives. For that we try to match an '%'
## followed by either a char or the end of the line. If found and known we
## replace it with the corresponding regex/formatvar. If unknown we die. Note!
## If matched the end of the line we found a lonely '%' and that fails.
## Non-directives will stored unchanged (but quoted for the regex).

my $DATEREG    = "";			# the regex to match a date
my $FORMSTRING = "";			# the format-string to printf a date
my @ORDER      = (); 			# the order of directives

$_ = $DATESTYLE;			# easy reading and prevent $DATESTYLE

while (/%(.|$)/) {			# match the %-directives

    $DATEREG    .= quotemeta $`;	# prematch
    $FORMSTRING .= $`;

    push @ORDER, $1;			# store order

    SWITCH: for ($1) {

	/[dmtsh]/	and do {
				$DATEREG    .= "\\d{1,2}";
				$FORMSTRING .= "%d";
				last SWITCH;
	    		       };

	/[DMTSH]/	and do {
				$DATEREG    .= "\\d{1,2}";
				$FORMSTRING .= "%02d";
				last SWITCH;
		               };

	/y/		and do {
				$DATEREG    .= "\\d{2}";
				$FORMSTRING .= "%d";
				last SWITCH;
		               };

	/Y/		and do {
				$DATEREG    .= "\\d{4}";
				$FORMSTRING .= "%d";
				last SWITCH;
		               };

	/%/		and do {
				$DATEREG    .= "\\%";
				$FORMSTRING .= "%%";
				last SWITCH;
		               };
    
	# if we reach this line we've found a unknown directive
	die "unknown directive <%$1> in datestyle <$DATESTYLE>\n";
    };

    $_ = $';				# postmatch for next test
}

$DATEREG    .= quotemeta $_;		# the rest of the line
$FORMSTRING .= $_;


## ----------------------------------------------------------------------------
## collect actual settings in a pretty formatted form

my $actual_settings = <<END_OF_SETTINGS;

$progname: current settings:

  -v  --verbose      => $VERBOSE
  -c  --correct      => $CORRECT
  -b  --backup       => $BACKUP
  -x  --bak-ext      => "$BACKUPEXT"
  -a  --bak-path     => "$BACKUPPATH"
  -d  --date-style   => "$DATESTYLE"
        (formstring) => "$FORMSTRING"
        (datereg)    => "$DATEREG"
        (order)      => @ORDER
  -y  --short-years  => $SHORTYEAR
        (year add)   => $YEARADD
  -u  --mdate-err    => $MDATEERR
  -e  --nodate-err   => $NODATEERR
  -f  --force-dates  => $FORCEDATE
  -r  --no-recurs    => $NORECURS
  -i  --no-bin       => $NOBIN
      files/paths    => @NODES
  -m  --match        => @REGEXS

END_OF_SETTINGS

$SETTINGS and die $actual_settings;


## ----------------------------------------------------------------------------
## ok, now are all things properly set or we dead

$VERBOSE     and print " $progname started (".localtime().")\n";
$VERBOSE > 2 and print $actual_settings;


## ----------------------------------------------------------------------------
## scan the given paths for files and store names and informations:
##
## we need the date of last modification and the permissions (to restore it)
## the hash we build looks like:
## %all_files = { "a_file" => { "date" => "the_date", "perm" => "the_permission }, ... }

my %all_files = ();


## ----------------------------------------------------------------------------
## _add_file - adds files to the hash or returns silent

sub _add_file {
    my $file = shift;

    # First test for matching the given regex. If this fails we don't do any
    # slowly filetest. :-)
    
    if (@REGEXS) {                                # match regexs if given
	my $file_ok = 0;

	for (@REGEXS) {
	    last if $file_ok += ($file =~ /$_/)
	}

	$file_ok or return;
    }

    -f $file or return;			          # real files only

    $NOBIN and -B $file and return;               # handle binaries

    my @stat = (stat($file)) or return;
    
    # now the real inserts to the hash
    $all_files{$file}{mtime} = $stat[9];
    $all_files{$file}{perm}  = $stat[2];

    $VERBOSE > 1 and print "  file added <$file>\n";
}


## ----------------------------------------------------------------------------
## this is the scan loop:
##
## if node is already a file we add it directly to the hash
## if node is a directory we scan this for files using the File::find routine
## in the find-routine we possible have to set the File::Find::prune
## to preserve against recursivly scanning

for my $node (@NODES) {

    if (-d $node) {
	$VERBOSE and print " scanning for files in <$node>\n";

	find( sub {
		   $NORECURS and (      -d $File::Find::name)
		             and ($node ne $File::Find::name)
		             and ($File::Find::prune = 1);
	           _add_file($File::Find::name);
	      },
	      $node )
    }
    else {
	_add_file($node);
    }
}
$VERBOSE and print " found ", scalar keys %all_files, " file(s)\n";


## ----------------------------------------------------------------------------
## perform the tests
##
## for this we scan all files in hash for a date matching the given datestyle.
## if there is a date and this is not corresponding with the filedate this
## will be corrected if wished by user. During this we count the found dates
## per file and printing errors for files without or with multiple dates. Last
## it's possible to expand the file with the date of last modification if no
## date found. Very last we play a little bit with backup-logics.

my %STAT = ();		# to store some statistics

for my $file (keys %all_files) {
    $VERBOSE > 1 and print "  checking file <$file>\n";
    
    # setup some stuff for this file
    my @lines_err   = ();		# lines with errors
    my @lines_ok    = ();		# lines with correct dates
    my $date_forced = 0;		# not done yet
    
    # the next is a little bit harder. we have to build a date in given
    # style using the date of last modification of the file
    #
    # for this we get the information from mtime first
    
    my ($sec, $min, $hour, $mday, $month, $year) = (localtime($all_files{$file}{mtime}))[0..5];

    # OK, now we fill the @vals-array with the items in the order found
    # in @ORDER. Then we do the formatted output using sprintf with our
    # earlier builded formatstring.
    
    my @vals = ();
    
    for (@ORDER) {
	/d/i  and  do { push @vals, $mday            ; next };
	/m/i  and  do { push @vals, $month + 1       ; next };
	/y/i  and  do { push @vals, $year + $YEARADD ; next };
	/t/i  and  do { push @vals, $min             ; next };
	/s/i  and  do { push @vals, $sec             ; next };
	/h/i  and  do { push @vals, $hour            ; next };
    }

    my $last_modified = sprintf($FORMSTRING, @vals);

    # open the original for reading and the new one if error-correcting is on
    my $old = $file;
    my $new = "$file.tmp.$$"					   if $CORRECT;

    open(OLD, "< $old")           or die "can't open $old: $!";
    open(NEW, "> $new")           or die "can't open $new: $!"     if $CORRECT;
    
    # now we scan the original line by line
    
    while (<OLD>) {

	# the logic behind the next loop was earlier described
	# by Randal L. Schwartz in his WebTechniques-Columne which can be found
	# at http://www.stonehenge.com/merlyn/col12.html.
	#
	# We try to match a date in given style. If this works we found a
	# date. We store the line before the date (the pre-match) and set $_
	# to everything after the match for the next test. The loop ends if
	# no more hits found and so we walk the line looking for matches.
	#
	# The date itselfs is the match and is stored by Perl in $&.
	# 
	# The so found date is compared with the filedate. If this is not equal
	# we store the date of last modification otherwise the original date.
	#
	# After the loop ends we write the stored data (should be the original
	# line with possible changed dates) and everything leaved in $_ to
	# the new file.
	
	my $line          = "";
	
	while (/$DATEREG/o) {			      # match the date

	    $line .= $`;			      # prematch

	    if ($& ne $last_modified) {               # found date is incorrect

	        warn "error: false date in file <$file> at line <$.>.", 
		     " found date: <$&> should be: <$last_modified>\n";

		$line .= $last_modified;              # the match, but changed
		push @lines_err, $.;		      # store linenumber

		$STAT{"date(s) incorrect"}++;

	    }

	    else {	                              # found date is correct

		$line .= $&;			      # the orginal match
		push @lines_ok, $.;		      # store linenumber

		$STAT{"date(s) correct"}++;

	    }

	    $_ = $';				      # postmatch for next test
	}

        (print NEW $line.$_)      or die "can't write to $new: $!" if $CORRECT;
    }
    
    # scanning lines of original is complete now
    # the new file should contain a copy of the original with adjusted dates

    # handle no-date, multiple-date and force-date
    # @lines_er and @lines_ok contains all numbers of lines with date
    
    my $dates_found = @lines_err + @lines_ok;
    
    $MDATEERR  and $dates_found > 1
               and warn "error: more than one date in file <$file> at lines <",
	                join(", ", sort @lines_err, @lines_ok), ">\n"
	       and $STAT{"file(s) with multiple dates"}++;
    
    $NODATEERR and ! $dates_found
               and warn "error: no date in file <$file>\n"
	       and $STAT{"file(s) without any date"}++;

    $FORCEDATE and $CORRECT
               and ! $dates_found
	       and (print NEW "\n$last_modified\n")
	       and $date_forced++
	       and $STAT{"date(s) forced"}++;
    
    # ok, we can close the original and the new one now
    
    close(OLD)                    or die "can't close $old: $!";
    close(NEW)                    or die "can't close $new: $!"    if $CORRECT;

    # if error-correcting is on we have now two files the original and
    # a copy with possible adjusted dates.
    #
    # If no changes made we just unlink the copy.
    #
    # Otherwise we basicly have to rename the copy to original and restore
    # the permission and the date of last modification of the original.
    # But before doing that we backup the original if wanted. Therefore we 
    # copy the orginal to the backup and restore the permission and mtime.
    # The location of the backup is either beside the file with a given
    # extension (but at least one dot) or in the backuppath. In the second case
    # the backuptree will be a copy of the original directory-structure and the
    # file is named same like the original.
    
    if ($CORRECT) {

	if (@lines_err or $date_forced) {

	    if ($BACKUP) {
    		my $bak = "$file.$BACKUPEXT";

		if ($BACKUPPATH) {
		    ($bak    = $BACKUPPATH.$file) =~ s(//)(/);
	    	    my $dir  = dirname($bak);
		    -d $dir  or mkpath([$dir])              or die "can't mkpath $dir: $!";
		}

		copy($old, $bak)                            or die "can't copy $old to $bak: $!";
		chmod $all_files{$file}{perm}, $bak         or die "can't chmod $bak: $!";
		utime time, $all_files{$file}{mtime}, $bak  or die "can't utime $bak: $!";
	    }

	    rename($new, $old)                              or die "can't rename $new to $old: $!";
	    chmod $all_files{$file}{perm}, $old             or die "can't chmod $old: $!";
	    utime time, $all_files{$file}{mtime}, $old      or die "can't utime $old: $!";

	    warn " note: file changed <$file>\n";
	    $STAT{"file(s) changed"}++;
	}
	else {
	    unlink $new                                     or die "can't unlink $new: $!";
	}
    }

    $STAT{"file(s) checked"}++;
    
    $VERBOSE > 1 and @lines_ok
		 and print "  found correct date(s) in file <$file> ",
		           "at line(s) <", join(", ", @lines_ok), ">\n";
}


## ----------------------------------------------------------------------------
## this is the end

$VERBOSE and do {
    print " $progname ended (".localtime().")\n";
    for (sort keys %STAT) { printf(" %8d $_\n", $STAT{$_}); }
}


## ----------------------------------------------------------------------------
## little nice self-test: last modified 16-07-1999 14:44:28
##
## to check use --datestyle="modified %D-%M-%Y %H:%T:%S"
