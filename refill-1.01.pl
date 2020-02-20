#!D:/Programs/Perl/Bin/perl -w
#--- refill.pl ----------------------------------------------------------------
# function: Refill remote files (via FTP) with content of specified local file.
# credits:  FVu, Sep-2000, version 1.01;  Added version number.
#           FVu, Jul-2000 (fvu@fvu.myweb.nl)
#
#           This program is free software; you can redistribute it and/or
#           modify it under the terms of the GNU General Public License
#           as published by the Free Software Foundation; either version 2
#           of the License, or any later version.
#
#           This program is distributed in the hope that it will be useful,
#           but WITHOUT ANY WARRANTY; without even the implied warranty of
#           MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#           GNU General Public License for more details.
#
#           You should have received a copy of the GNU General Public License
#           along with this program; if not, write to the Free Software
#           Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-
#           1307, USA.

=head1 NAME

refill - Refill remote files (via FTP) with content of specified local file.

=head1 SYNOPSIS

refill [OPTION] [FILE]...

Options:
--filler <file>
--help
--man
--password <password>
--port <number>
--recursive
--server <server> 
--user <user> 
--verbose
--version

=head1 OPTIONS

=over 24

=item B<--filler <file>>

File (local) to fill files with.

=item B<--force>

Never prompt.

=item B<--help>

Display short help message.

=item B<--man>

Display help information.

=item B<--port <number>>

Port number for FTP server.

=item B<--password <password>>

FTP password.

=item B<--recursive>

Look through directories recursively.

=item B<--server <server>>

Name of FTP server.

=item B<--user <user>>

FTP username.

=item B<--verbose>

Be verbose.

=item B<--version>

Show version number.

=back

=head1 DESCRIPTION

B<This program> will establish an FTP connection and fill the specified files with the content of the 'filler' file.  Transfer will be done in 'ascii' mode.

Example:

   refill -r -verb -s server -u foo -fi /tmp/moved.htm *.htm *.html

=head1 README

B<This program> will establish an FTP connection and fill the specified files with the content of the 'filler' file.  Transfer will be done in 'ascii' mode.

=pod SCRIPT CATEGORIES

Web

=head1 AUTHOR

Freddy Vulto E<lt>fvu@fvu.myweb.nlE<gt>

=cut

use Net::FTP;
use File::Basename;
use Getopt::Long;
use Pod::Usage;
use Term::ReadLine;
use strict;

my $gs_Version = 1.01;
my $ghr_Options = {};
my $gs_Ftp;
my $gs_Term;
my @gl_ArgFileSpec;


#--- gf_ArgumentProcessor() ---------------------------------------------------
# function: Process arguments which aren't recognized by 'Getopt'.
# credits:  FVu, Jul 2000: Created

sub gf_ArgumentProcessor {
	my($as_Argument) = shift();
		# Add argument to list of file specifications
	push @gl_ArgFileSpec, $as_Argument;
}


#--- gf_FileProcessor() -------------------------------------------------------
# function: Process file.  Replace contents of file with contents of 'filler'
#           file.
# credits:  FVu, Jul-2000

sub gf_FileProcessor {
		# Retrieve argument
	my($as_File) = shift();
		# Declare local variable
	my($ls_Continue);
		# Must user be consulted for confirmation?
	if (defined($ghr_Options->{force})) {
		# No, user needn't be consulted for confirmation;
			# Indicate so
		$ls_Continue = 1;
	}
	else {
		# Yes, user must be consulted for confirmation;
			# Ask user for confirmation by comparing input with 'Y' or 'y'
		$ls_Continue = ($gs_Term->readline("Refill $as_File?") =~ m/^[yY]$/);
	}

	if ($ls_Continue) {
		print "Refilling $as_File\n" if ($ghr_Options->{verbose});
			# Putting file is successful?
		if (! $gs_Ftp->put($ghr_Options->{filler}, $as_File)) {
			# No, putting file isn't successful;
				# Show error
		  	print STDERR $gs_Ftp->message;
		}
	}
}


#--- gf_FilesProcessor() ------------------------------------------------------
# function: Process file specifications.
# credits:  FVu, Jul-2000

sub gf_FilesProcessor {
		# Declare local variables
	my($ls_DpfSpec, $ls_Name, $ls_Path, $ls_Type, $ls_FileSpec);
		# Create term in case user needs to give input
	$gs_Term = new Term::ReadLine 'Refill';
		# Loop through file specifications
	foreach $ls_DpfSpec (@gl_ArgFileSpec) {
			# Set file parser to UNIX format
		fileparse_set_fstype("UNIX");
			# Parse filespec
		($ls_Name, $ls_Path, $ls_Type) = fileparse($ls_DpfSpec, '');
			# Does path resemble current directory?
		if ($ls_Path =~ m/\.\//) {
			# Yes, path resembles current directory;
				# Substitute dot with full path of current directory
		  	$ls_Path = $gs_Ftp->pwd;
		}
		else {
			# No, path doesn't resemble current directory;
				# Remove trailing slash from path
			$ls_Path =~ s/\/$//;
		}
			# Does directory exist?
		if ($gs_Ftp->cwd($ls_Path)) {
			# Yes, directory exist;
				# Is name a directory?
			if ($gs_Ftp->cwd($ls_Name)) {
				# Yes, name is a directory;
					# Indicate so
		  		$ls_Path = "${ls_Path}/${ls_Name}";
				$ls_Name = "*";
		  	}
		}
			# Turn file specification into regular expression

			# Match string to end of line ($)
		$ls_FileSpec = "$ls_Name\$";
			# . -> \.
		$ls_FileSpec =~ s/\./\\\./g;
			# * -> .*
		$ls_FileSpec =~ s/\*/\.\*/g;
			# Traverse tree
		gf_TraverseTreeFtp(
			\&gf_FileProcessor, $ls_Path, $ls_FileSpec 
		); 
	}
}


#--- gf_Login() --------------------------------------------------------------- # function: Login to FTP server.
# returns:  TRUE if successful, FALSE if not.
# credits:  FVu, Jul-2000

sub gf_Login {
		# Declare local variables
	my ($ls_Verbose, $ls_Server, $ls_Port, $ls_User, $ls_Password, $ls_Return);
		# Default to error return value
	$ls_Return = 0;
		# Set easy local variables
	$ls_Verbose = $ghr_Options->{verbose};
	$ls_Server = $ghr_Options->{server};
	$ls_User = $ghr_Options->{user};
	$ls_Password = $ghr_Options->{password};
	$ls_Port = $ghr_Options->{port};

	print "Connecting to remote host $ls_Server...\n" if ($ls_Verbose);

		# Is port specified?
	if (! defined($ls_Port)) {
		# No, port not specified;
			# Use default port number
		$ls_Port = 0;
	}
		
		# Connecting to server is successful?
	if ($gs_Ftp = Net::FTP->new($ls_Server, Port => $ls_Port)) {
		# Yes, connecting to server is successful;

			# Login to server

		print "Logging as user $ls_User...\n" if ($ls_Verbose);
			# Logging in to server is successful?
		if ($gs_Ftp->login($ls_User, $ls_Password)) {
			# Yes, logging in to server is successful;
				# Indicate success
			$ls_Return = 1;
		}
		else {
			# No, logging in to server isn't successful;
				# Show error
			print STDERR $gs_Ftp->message;
		}
	}
	else {
		# No, connecting to server yields error
			# Show constructor error
		print STDERR "$@\n";
	}
		# Return value
	return ($ls_Return);
}


#--- gf_OptionProcessor() -----------------------------------------------------
# function: Process options.
# args:     - as_ShowUsage: pointer to variable to hold TRUE if usage must be 
#                shown, FALSE if not.
#           - as_UsageVerboseness: pointer to variable to 'usage verboseness'
#                return value:
#                - 0 (FALSE): don't show usage
#                - 1: show usage synopsis
#                - 2: show usage complete description
# uses:     - ghr_Options (global hash reference)
# return: 	TRUE if successful, FALSE if not 
# credits:  FVu, Jul-2000

sub gf_OptionProcessor {
		# Declare local variables
	my ($ls_ShowUsage, $ls_UsageVerboseness, $ls_Return);
		# Default to not show usage
	$ls_ShowUsage = $ls_UsageVerboseness = 0;
		# Bias to success
	$ls_Return = 1;
		# Configure 'Getopt'
	Getopt::Long::Configure("no_ignore_case", "permute");
		# Storing argument options in hash reference is successful?
	if (
		! GetOptions(
			$ghr_Options, 'filler:s', 'force', 'help|?', 'man', 'password:s', 
			'port:s', 'recursive', 'server=s', 'user:s', 'verbose', 'version',
			'<>' => \&gf_ArgumentProcessor
		)
	) {
		# No, storing argument options in hash reference isn't successful;
			# Indicate so
		$ls_ShowUsage = 1;
		$ls_UsageVerboseness = 0;
	}

		# Process options

		# NOTE: Infinite loop circumvents a 'goto' statement
	OPTION: while(1) {
			# 'help' specified?
		if ($ghr_Options->{help}) {
			# Yes, 'help' specifiedj;
			$ls_ShowUsage = $ls_UsageVerboseness = 1;
			last OPTION;
		}
			# 'man' specified?
		if ($ghr_Options->{man}) {
			# Yes, 'man' specified;
			$ls_ShowUsage = $ls_UsageVerboseness = 2;
			last OPTION;
		}
	
			# 'version' specfied?
		if ($ghr_Options->{version}) {
			# Yes, 'version' specfied;
				# Show version
		  	print "refill version $gs_Version\n";
				# Indicate failure since 'refill' doesn't need to be done
		  	$ls_Return = 0;
			last OPTION;
		}
			# 'server' specified?
		if (!defined($ghr_Options->{server})) {
			# No, 'server' isn't specified;
				# Indicate failure
			$ls_Return = 0;
				# Show error message
			print "Error: server not specified\n";
			last OPTION;
		}
	
			# 'user' specified?
		if (!defined($ghr_Options->{user})) {
			# No, 'user' isn't specified;
				# Indicate failure
			$ls_Return = 0;
				# Show error message
			print "Error: user not specified\n";
			last OPTION;
		}
	
			# 'password' specified?
		if (!defined($ghr_Options->{password})) {
			# No, 'password' isn't specified;
				# Indicate failure
			$ls_Return = 0;
				# Show error message
			print "Error: password not specified\n";
			last OPTION;
		}

			# 'filler' specified?
		if (!defined($ghr_Options->{filler})) {
			# No, 'filler' isn't specified;
				# Indicate failure
			$ls_Return = 0;
				# Show error message
		  	print "Error: filler not specified\n";
			last OPTION;
		}
		else {
			# Yes, 'filler' is specified;
				# File is readable?
		  	if (! -f $ghr_Options->{filler}) {
				# No, file isn't readable;
					# Indicate error
		  		$ls_Return = 0;
					# Show error message
		  		print "Error: can't read file: $ghr_Options->{filler}\n";
				last OPTION;
		  	}
		}
			
			# Arguments specified?
		if (@gl_ArgFileSpec == 0) {
			# No, no arguments specified;
				# Indicate failure
		 	$ls_Return = 0;
				# Show error message
		  	print "Error: no file(s) specified\n";
			last OPTION;
		}

		last OPTION;
	}

	$_[0] = $ls_ShowUsage;
	$_[1] = $ls_UsageVerboseness;

		# Return value
	return($ls_Return);
}


#--- gf_TraverseTreeFtp() -----------------------------------------------------
# function: Traverse directory tree recursively via FTP.
# args:     - $as_FileProcessor: pointer to function to process each file
#           - $as_Dir: directory to process
#           - $as_FileSpec: file specification (regular expression) of files 
#                to process
# credits:  FVu, Jul 2000: Created. 

sub gf_TraverseTreeFtp {
		# Retrieve arguments
	my($as_FileProcessor) = shift();
	my($as_Dir) = shift();
	my($as_FileSpec) = shift();
		# Declare local variables
	my($ls_Line, @dirlist);
		# Retrieve list of files which reside in directory
	if (! (@dirlist = $gs_Ftp->dir($as_Dir))) {
		print STDERR $gs_Ftp->message;
	}
	foreach $ls_Line (@dirlist) {
			# Skip own directory (.) and parent directory (..)
		next if ($ls_Line =~ m/(\s\.$)|(\s\.\.$)/);
			# Skip line indicating total number of files
		next if ($ls_Line =~ m/^total/);
			# Retrieve file from line
		my($ls_File) = $ls_Line;
		$ls_File =~ s/.*\s(\S*)$/$1/;
			# Assemble full path specification for file
		$ls_File = "$as_Dir\/$ls_File";
			# Does line specify a directory?
		if ($ls_Line =~ m/^d/) {
			# Yes, line specifies a directory; 
				# Must directories be traversed recursively?
		  	if (defined($ghr_Options->{recursive})) {
				# Yes, directories must be traversed recursively;
					# Traverse tree recursively
				gf_TraverseTreeFtp($as_FileProcessor, $ls_File, $as_FileSpec);
		  	}
			next;
		}	
			# Does file match file specification?
		if ($ls_File =~ m/$as_FileSpec/) {
			# Yes, file matches file specification;
				# Process file
			&$as_FileProcessor($ls_File);
		}
	}
}


#--- main ---------------------------------------------------------------------
my($gs_ShowUsage, $gs_UsageVerboseness);
	# Processing options is successful?
if (gf_OptionProcessor($gs_ShowUsage, $gs_UsageVerboseness)) {
	# Yes, processing options is successful;
		# Must usage be shown?
	if ($gs_ShowUsage) {
		# Yes, usage must be shown;
			# Show usage
		pod2usage(-verbose => $gs_UsageVerboseness);
	}
	else {
		# No, usage needn't be shown;
			# Login to server is successful?
		if (gf_Login) {
			# Yes, login to server is successful;
				# Process files
			gf_FilesProcessor;
				# Disconnect FTP
			$gs_Ftp->quit;
		}
		else {
			# No, login to server isn't successful;
				# Indicate error
		  	exit(1);
		}
	}
}
