#!/usr/bin/perl

=head1 NAME

webupload.pl - website uploader

=head1 SYNOPSIS

webupload [options]

=head1 DESCRIPTION

This is a perl script for uploading files to an FTP site. This script was
designed specifically for uploading website files, in the cases where:

=over 8

=item *

You don't want to use an interactive FTP Program

=item *

You want to be able to specify specific files/directories to upload rather than
spending time uploading the whole site.

=back

webupload allows the user to specify a file containing a list of
files/directories to be uploaded. The user may also specify commands to create
directories or delete files.

A distinction is made between binary and text files via their extensions for the
purpose of uploading. A config file can be used to specify inital
setup/connection paramters.

Special support is integrated for those that wish to use ActiveState's port of
Perl with cygwin. If the script detects that $^O is MSWin32 and the $CGYWIN
environment variable is set, it will use cygpath to translate POSIX cygwin paths
into Win32 paths.

=cut

# perl pragmas and directives
require 5.6.0;
use strict;

# CPAN Modules
use ConfigReader::DirectiveStyle;
use File::Find;
use Getopt::Long;
use Net::FTP;
use Pod::Usage;
use Term::ReadLine;

our $VERSION = 1.53;
$! = 1;   # to get proper output when using activestate perl on cygwin

#################################################################################
# MAIN LINE CODE                                                                #
#################################################################################
my($ftp, $cfg, $term);
my(@filelist, $binary_extensions, @config_options, @files);
my(%clo, %options, %commands);

# Initialise variables
%options = ();
@filelist = ();
@files = ();
$binary_extensions = ".gif|.jpeg|.jpg|.class|.ico|.exe|.doc|.eot|.jar|.tar|.gz|.zip|.pdf|.png";
@config_options = ('host', 'user', 'pwd', 'ldir', 'rdir');
$term = new Term::ReadLine 'terminal';

# Process command line options
GetOptions(\%clo, qw(file|f=s list|l=s config|c=s nobinary|n help|h|? version|v));
pod2usage({-exitval => 0}) if($clo{help});
if($clo{version}) {
  print "upload Version $VERSION\nSagar R. Shah\nhttp://www.netnexus.uklinux.net\n";
  exit;
}

# Process config file
if ($clo{config}) {
$clo{config} = translate_cygpath($clo{config});
$cfg = new ConfigReader::DirectiveStyle;
$cfg->required($_) foreach (@config_options);
$cfg->load($clo{config});
%options = %{$cfg->values};
}

foreach my $opt (@config_options) {
  unless($options{$opt}) {
    $options{$opt} = $term->readline("Enter " . $opt . ": ");
  }
}

#process filelist
@filelist = readfile($clo{list}) if($clo{list});

chdir($options{ldir}) and print "Changed local dir to $options{ldir}\n"
  or die("Failled to change dir to $options{ldir}\n");

push @filelist, $clo{file} if($clo{file});

foreach my $file (@filelist) {
  chomp($file);
  next unless($file);
  $file =~  s/\\/\//g;
  if(-f $file) {push @files, $file; }
  elsif(-d $file) {find( { wanted   => \&process_dir, no_chdir => 1 }, $file);}
  elsif($file =~ m/^%/) { process_cmd($file); }
  elsif($file =~ m/^#/) { next; }
  else {print "Unknown $file\n";}
}

# Start FTPing
login();
rmfile ($_) foreach (@{$commands{rm}});
md ($_) foreach (@{$commands{mkdir}});
putfile($_) foreach (@files);
logout();

sub login {
  $ftp = Net::FTP->new($options{host}, Passive => 1 ) || die("Error: $@\n");

  print "Attempting to connect to $options{host}...\n";
  $ftp->login($options{user},$options{pwd}) and print "Login Successful\n";

  $ftp->ascii and print "Set type to ASCII\n";
  $ftp->cwd($options{rdir}) and print "Changed remote dir to $options{rdir}\n";
}

sub logout {
  $ftp->quit and print("Logged off\n");
}

sub process_dir {
  push @files, $_ if(-f $_);
}

sub process_cmd {
  my($cmd) = @_;
  push @{$commands{$1}}, $2 if($cmd =~ m/^% (.+)\s(.+)/x);
}

sub putfile {
  my($file) = @_;
  ($file =~ /$binary_extensions$/i) ? put_binary($file) : put_ascii($file);
}

sub put_ascii {
  my($file) = @_;
  print "Attempting to upload $file...";
  $ftp->put($file, $file) or print_failure();
  print "\n";
}

sub put_binary {
  my($file) = @_;
  return if($clo{nobinary});
  print "Attempting to upload $file [binary mode]...";
  $ftp->binary;
  $ftp->put($file, $file) or print_failure();
  $ftp->ascii;
  print "\n";
}

sub rmfile {
  my($file) = @_;
  print "Attempting to delete $file...";
  $ftp->delete($file) or print_failure();
  print "\n";
}

sub md {
  my($dir) = @_;
  print "Attempting to make dir $dir...";
  $ftp->mkdir($dir, 1) or print_failure();
  print "\n";
}

sub print_failure {
  printf "FAILED " . $ftp->code() . " " . $ftp->message();
}

sub readfile {
  my($filename) = @_;
  my(@lines);
  $filename = translate_cygpath($filename);
  die("Filename undefined\n") unless(defined $filename);
  die("Error: file $filename does not exist\n") unless(-e $filename);
  open(IN, $filename) or die "Error: couldn't open file $filename : $!\n";
  @lines = <IN>;
  close(IN);
  return @lines
}

sub translate_cygpath {
  my($cygpath) = @_;
  my($winpath);
  if($^O = "MSWin32" and $ENV{CYGWIN}) {
    $winpath = qx/cygpath -w $cygpath/;
    chomp($winpath);
    return $winpath;
  }
  return $cygpath;
}

=head1 OPTIONS

=over 8

=item * B<--config | -c> <filename>

Name of config file containg FTP host settings

=item * B<--file | -f> <filename|dirname>

Name of file or directory to upload

=item * B<--help | -h | -?>

Print Help Information

=item * B<--list | -l> <filename>

Name of a file containg a list of files to upload

=item * B<--nobinary | -n>

Skips binary files.

=item * B<--version | -v>

Prints version information

=back

=head1 FILELIST FORMAT

Each file or directory should be listed on a new line without any characters preceding it.

If a line is prefixed by a hash (#) then it will be treated as a commend unless there really exists a file or directory with a name equal to that line.

If a line is prefixed by a percent sign (%) then it will be treated as a command. The currently supported commands are:

=over 8

=item *

rm

=item *

mkdir

=back

=head1 CONFIG FILE FORMAT

     host    ftp.xxx.com
     user    me
     pwd     xxx
     ldir    c:\websites
     rdir    /public_html/

If any of the fields are ommitted from the config file, the user will be prompted for them on the console.

=head1 PREREQUISITES

C<ConfigReader::DirectiveStyle>

C<File::Find>

C<Getopt::Long>

C<Net::FTP>

C<Pod::Usage>

C<Term::ReadLine>

=head1 COREQUISITES

none

=head1 TODO

Allow list of binary_extensions to be specified in the config file.

Any other good suggestions that people send me!

=head1 AUTHOR

 Sagar R. Shah
 sagarshah@softhome.net
 http://www.shahdot.com/

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2002, Sagar R. Shah. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl.

=begin comment

=pod SCRIPT CATEGORIES

Web

=pod README

This script is designed for helping you upload your website to an FTP server in
the cases where you don't want to use an interactive FTP program and you don't
want to upload the whole website.

=end comment

=cut
