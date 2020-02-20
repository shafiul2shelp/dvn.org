#!C:/Perl/bin/perl -w
#
#   Script to build an applet JAR file, based on the access log file
#   from a web server
#

my $BOL_CLASSES = "C:\\Programme\\Software AG\\Bolero\\classes";
my @CLASSPATH = ("$BOL_CLASSES\\BOAfixes21103.jar",
		 "$BOL_CLASSES\\appserver.jar",
		 "$BOL_CLASSES\\BTA.jar");
my @PREFIXES = ("/avesclient/");
my @EXTENSIONS = (".class", ".properties");


use strict;
use Getopt::Long ();
use Symbol ();
use File::Spec ();
use File::Path ();
use File::Basename ();
use Archive::Zip ();

my $TMPDIR = File::Spec->tmpdir();
my $JAR = FindInPath("jar")
  || "C:\\Programme\\JavaSoft\\JDK-1.3\\bin\\jar.exe";


sub FindInPath {
  my $prog = shift;
  foreach my $p (File::Spec->path()) {
    my $f = File::Spec->catfile($p, $prog);
    return $f if -x $f;
  }
  return undef;
}


############################################################################
#
#   Name:    ExtractJar
#
#   Purpose: Extract the required contents of a JAR file or directory
#
#   Inputs:  $o - Options hash ref
#            $f - JAR file or directory name
#            $classes - Hash ref with required class files
#            $dir - Output directory
#
#   Returns: Nothing; exits with error status in case of trouble
#
############################################################################

sub WriteFile {
  my($file, $contents, $dir) = @_;
  my($fname, $fdir) = File::Basename::fileparse($file);
  if ($fdir) {
    my $cdir = File::Spec->catdir($dir, $fdir);
    die "Failed to create directory $cdir: $!"
      unless -d $cdir || File::Path::mkpath($cdir, 0, 0755);
  }
  my $path = File::Spec->catfile($dir, $file);
  my $fh = Symbol::gensym();
  (open($fh, ">$path") && binmode($fh) && (print $fh $contents) && close($fh))
    || die "Failed to create file $path: $!";
}
sub ExtractJarDir {
  my($o, $jar, $classes, $dir) = @_;
  print "Searching for files in directory $jar ...\n" unless $o->{'quiet'};
  while (my($key, $val) = each %$classes) {
    next unless $val;
    my $f = File::Spec->catfile($jar, $key);
    next unless -f $f;
    $classes->{$key} = 0;
    print "Taking $key from directory $jar\n" if $o->{'verbose'};
    my $contents;
    if (-z _) {
      $contents = "";
    } else {
      my $fh = Symbol::gensym();
      open($fh, "<$f") || die "Failed to open file $f: $!";
      local $/ = undef;
      binmode($fh);
      $contents = <$fh>;
      die "Failed to read contents of file $f: $!" unless defined $contents;
    }
    WriteFile($key, $contents, $dir);
  }
}

sub ExtractJarFile {
  my($o, $jar, $classes, $dir) = @_;
  print "Searching for files in JAR file $jar ...\n" unless $o->{'quiet'};
  my $zipFile = Archive::Zip->new();
  if ((my $status = $zipFile->read($jar)) != Archive::Zip::AZ_OK) {
    die "Failed to open ZIP archive $jar: status = $status";
  }
  foreach my $member ($zipFile->members()) {
    my $fileName = $member->fileName();
    my $className = $fileName;
    if (exists($classes->{$fileName})) {
      if ($classes->{$fileName}) {
	print "Taking $fileName from $jar\n" if $o->{'verbose'};
	$classes->{$fileName} = 0;
	$member->extractToFileNamed(File::Spec->catfile($dir, $fileName));
      } else {
	print STDERR "Ignoring $className in $jar: Already found\n"
	  if $o->{'verbose'};
      }
    } else {
      print STDERR "Ignoring $className in $jar: Not requested\n"
	if $o->{'verbose'};
    }
  }
}

sub ExtractJar {
  my($o, $jar, $classes, $dir) = @_;
  if (-f $jar) {
    ExtractJarFile(@_);
  } elsif (-d _) {
    ExtractJarDir(@_);
  } else {
    print STDERR "Warning: Missing JAR file $jar\n";
  }
}


############################################################################
#
#   Name:    TmpDir
#
#   Purpose: Create an empty temporary directory and return its name
#
#   Inputs:  $o - Options hash ref
#
#   Returns: Directory name
#
############################################################################

sub TmpDir {
  my $o = shift;
  my $try;
  for (my $num = 0;;  ++$num) {
    $try = File::Spec->catdir($o->{'tmpdir'}, "BuildAppletJarDir$num");
    last unless -e $try;
  }
  File::Path::mkpath($try, 0, 0755)
      || die "Failed to create directory $try: $!";
  $try;
}


############################################################################
#
#   Name:    AddFile
#
#   Purpose: Read the contents of a JAR file or directory and insert
#            the contents into a hash ref
#
#   Inputs:  $o - Options hash ref
#            $f - JAR file or directory name
#            $classes - Hash ref of classes
#
#   Returns: Nothing; exits with error status in case of problems
#
############################################################################

sub AddJarDir {
  my($o, $dir, $classes) = @_;
  require Cwd;
  require File::Find;
  my $oldDir = Cwd::cwd();
  chdir $dir;
  File::Find::find(sub {
		     my $f = $_;
		     return if $f =~ /^\.\.?$/;
		     return unless -f $_;
		     $f =~ s/^\.\///;
		     if (!exists($classes->{$f})) {
		       print "Registering class: $f\n" if $o->{'verbose'};
		       $classes->{$f} = 1;
		     }
		   }, ".");
  chdir $oldDir;
}

sub AddJarFile {
  my($o, $jar, $classes) = @_;
  my $zipFile = Archive::Zip->new();
  if ((my $status = $zipFile->read($jar)) != Archive::Zip::AZ_OK) {
    die "Failed to open ZIP archive $jar: status = $status";
  }
  foreach my $member ($zipFile->members()) {
    my $fileName = $member->fileName();
    my $className = $fileName;
    if (!exists($classes->{$fileName})) {
      print "Registering class: $fileName\n" if $o->{'verbose'};
      $classes->{$fileName} = 1;
    }
  }
}

sub AddFile {
  my($o, $f, $classes) = @_;
  if (-f $f) {
    AddJarFile(@_);
  } elsif (-d _) {
    AddJarDir(@_);
  } else {
    print STDERR "Warning: Missing JAR file $f\n";
  }
}


############################################################################
#
#   Name:    ParseFile
#
#   Purpose: Parse a web server log file for class names and insert
#            them into a hash ref.
#
#   Inputs:  $o - Options hash ref
#            $f - Log file name
#            $classes - Hash ref of classes
#
#   Returns: Nothing; exits with error status in case of problems
#
############################################################################

sub ParseFile {
  my($o, $f, $classes) = @_;
  my $fh = Symbol::gensym();
  my $rePrefix =
    "(?:" . join("|", map{quotemeta($_)} @{$o->{'prefix'}}) . ")";
  $rePrefix = "" unless @{$o->{'prefix'}};
  my $reExtension =
    "(?:" . join("|", map{quotemeta($_)} @{$o->{'extension'}}) . ")";
  $reExtension = "" unless @{$o->{'extension'}};
  my $rex = qr{^$rePrefix(.*$reExtension)$};

  open($fh, "<$f") || die "Failed to open log file $f: $!";
  my $lineNum = 0;
  while (defined(my $line = <$fh>)) {
    ++$lineNum;
    if ($line =~ /^(\S+)\s+            # Host name or IP address
                   (\S+)\s+            # Authenticated user name
                   (\S+)\s+            # ???
                   (\[\S+\s+\S+\])\s+  # Date and time
                   \"(\S+)\s+          # HTTP request method
                   (.*?)\s+            # URL
                   HTTP\/\d+\.\d+\"\s+ # HTTP version
                   (\d+)\s+            # Status
                   (\d+)/x) {
      my $url = $6;
      my $status = $7;
      $url =~ s/\?.*//;
      if ($url =~ /$rex/) {
        my $class = $1;
	if (!exists($classes->{$class})) {
	  print "Registering class: $class\n" if $o->{'verbose'};
	  $classes->{$class} = 1;
	}
      }
    } else {
      print STDERR "Failed to parse line $lineNum of file $f\n"
	if $o->{'verbose'};
    }
  }
}


############################################################################
#
#   Name:    Usage
#
#   Purpose: Print the usage message and exit with error status
#
############################################################################

sub Usage {
  my $msg = shift;
  my $classpath = join("", map {"\n\t\t\t\t$_"} @CLASSPATH);
  my $prefixes = join("", map {"\n\t\t\t\t$_"} @PREFIXES);
  my $extensions = join("", map {"\n\t\t\t\t$_"} @EXTENSIONS);
  if ($msg) {
    print STDERR "$msg\n\n";
  }
  print STDERR <<"USAGE";
Usage: $0 --output=<outputfile> --logfile=<logfile> [options]

Possible options are:

  --add=<c>             Add the given directory or JAR file to the
                        front of the classpath and include its content
			list completely; may be used repeatedly,
                        defaults to empty
  --classpath=<c>	Add the given directory or JAR file to the
			front of the classpath; may be used repeatedly,
                        defaults to $classpath
  --extension=<e>	Treat files with extension <e> as JAR file
                        input; may be used repeatedly, defaults to
                        $extensions
  --jar=<j>             Set path of jar binary; default
                        $JAR
  --logfile=<l>		Set logfile to parse; required, may be used
			repeatedly
  --noClassPath         Clean default classpath
  --noExtension         Clean default extension list
  --noPrefix            Clean default prefix list
  --output=<f>		Set output file name; required.
  --prefix=<p>          Ignore prefix <p>; may be used repeatedly,
                        defaults to $prefixes
  --tmpdir=<t>          Set temporary directory to <t>; default $TMPDIR
  --verbose		Turn on verbose mode
USAGE
  exit 1;
}

############################################################################
#
#   This is main()
#
############################################################################

{
  my %o;
  %o = ('add' => [],
	'classpath' => [],
	'logfile' => [],
	'prefix' => [],
	'help' => \&Usage,
	'extension' => [],
	'tmpdir' => $TMPDIR,
	'jar' => $JAR,
	);
  Getopt::Long::GetOptions(\%o, "verbose", "classpath=s@", "logfile=s@",
			   "prefix=s@", "output=s", "extension=s",
			   "noClassPath", "noPrefix", "noExtension",
			   "tmpdir=s", "jar=s", "help", "add=s@");
  unshift(@{$o{'classpath'}}, @{$o{'add'}});
  push(@{$o{'classpath'}}, @CLASSPATH) unless $o{'noClassPath'};
  push(@{$o{'extension'}}, @EXTENSIONS) unless $o{'noExtension'};
  push(@{$o{'prefix'}}, @PREFIXES) unless $o{'noPrefix'};

  die "No JAR executable found in $o{'jar'}" unless -x $o{'jar'};

  my $output = $o{'output'} || Usage("Missing output file name");

  my %classes;
  foreach my $f (@{$o{'logfile'}}) {
    ParseFile(\%o, $f, \%classes);
  }
  foreach my $f (@{$o{'add'}}) {
    AddFile(\%o, $f, \%classes);
  }

  my $dir = TmpDir(\%o);
  foreach my $j (@{$o{'classpath'}}) {
    ExtractJar(\%o, $j, \%classes, $dir);
  }

  while (my($key, $val) = each %classes) {
    print "Warning: Missing class $key\n" if $val;
  }

  my $flags = $o{'verbose'} ? "cvf" : "cf";
  my @cmd = ("\"$o{'jar'}\"", $flags, $o{'output'}, "-C", $dir, ".");
  print join(" ", @cmd);
  system @cmd;
  File::Path::rmtree($dir, 0);
}


__END__

=head1 NAME

BuildAppletJar - Build JAR files for applets


=head1 SYNOPSIS

  BuildAppletJar.pl --output=E<lt>jarfileE<gt> --logfile=E<lt>logfileE<gt>


=head1 DESCRIPTION

This small Perl script parses one or more WWW server log files in
common log file format and attempts to detect class files, property
files and other files requested by applets. For example, if your
applets code base is

	/myapplet

and there is a request for

	/myapplet/mycompany/myclass.class

in the WWW servers log file, then the script assumes, that a file
F<mycompany/myclass.class> should be in the JAR file.


=head1 OPTIONS

=over

=item --add=E<lt>jarE<gt>

The contents of the directory E<lt>jarE<gt> or the JAR file E<lt>jarE<gt>
will be included into the generated JAR file completely. Additionally
the name E<lt>jarE<gt> will be prepended to the class file. See also
--classpath

=item --classpath=E<lt>jarE<gt>

The directory E<lt>jarE<gt> or the JAR file E<lt>jarE<gt> will be
prepended to the class file. Unlike the --add option, the contents
will not necessarily be included into the generated JAR file, only
if they are requested in the WWW servers log file. See also --add
and --noClassPath.

=item --extension=E<lt>.extE<gt>

By default only requests for files with the extensions E<lt>.classE<gt>
and E<lt>.propertiesE<gt> will be notices by the logfile parser. This
option allows to extend the list of extensions. See also --noExtension.

=item --jar=E<lt>jar.exeE<gt>

Sets the path of the JAR binary. By default this will be searched in
the current execution path.

=item --logfile=E<lt>fileE<gt>

Sets the path of a WWW servers log file being parsed. You may use this
option multiple times.

=item --noClassPath

Cleans the default class path. Use --help to display the default
class path. See also --classpath and --add.

=item --noExtension

Cleans the default list of extensions. Use --help to display the
default list. See also --extension.

=item --noPrefix

Cleans the default list of prefixes. Use --help to display the
default list. See also --prefix.

=item --output

Sets the name of the JAR file being generated.

=item --prefix=E<lt>/prefixE<gt>

Sets the URL of your applets document or code base. For example, if your
applets class files are below

 http://www.mycompany.com/myapplet/

then this should be /myapplet/. You may use this option multiple times.
See also --noPrefix.

=item --tmpdir=E<lt>dirE<gt>

Sets the name of a directory being used for temporary files.

=item --verbose

Turns on verbose mode.

=back


=head1 CPAN

This script is submitted to CPAN. The following sections are for
CPAN's automatic maintenance system and you can safely ignore them.

=head2 SCRIPT CATEGORIES

Web

=head2 PREREQUISITES

Archive::Zip

=head2 README

This script is for creating applet JAR files. The typical situation
is that you have some large libraries and know, that only parts
are required.

The idea is that you start working without JAR files, possibly
extracting library classes. The required classes are then determined
by looking into the WWW servers log files.


=head1 AUTHOR

Jochen Wiedmann
Software AG
Jochen.Wiedmann@SoftwareAG.com

