=head1 NAME
 
yahobuilder - yet another homepage builder

=head1 README

Inspired by Zope yahobuilder takes the idea of defining variables
at different levels and substituting the closest one to offline
html preparaion. Yahobuilder includes also a simple upload tool
to a ftp server. Home of Yahobuilder is http://www.gs68.de.

=head1 SYNOPSIS

perl yahobuilder.pl

  -u to upload the site

  -r to erase the target directory

  default is create the offline html

You need to set the variables $g_source_dir (here resides your 
homepage in yahobuilder format) and $g_target_dir (here yahobuilder 
will prepare the html version), as well as the ftp login info
if you intend to use the upload, according your setup.

=head1 DESCRIPTION
 
Yahobuilder takes the idea to define variables in different levels 
(implemented in the directory structure of the source pages) from
Zope and substitute them into the actual pages.

To setup a a site using yahobuilder you write basically simple html
in which you can insert the 

<dtml-var variable_name/>

tag which yahobuilder substitutes with the content of the variable.
There are three ways to define variables:

=over 2

=item * 

files with the extension varname.var will be interpreted as variable
with name varname.

=item * 

short variables can be defined in a file folder.my_hp (in any
directory), this variables must be typed into one line and name 
and content are separated by name~~~content.

=item *
 
there is also a predefined variable navigate_parents that can be used
in conjunction with variables folder_title defined in each directory
to build up a simple navigation structure. See attached example for details
of the usage.

=back


Even the concept of yahobuilder is quite simple it is rather helpful
in achieving a consistant site layout without huge effort. And you
need not to use a complicated html editor. Please see the available
example if you are interested in yahobuilder.  

By using the proper arguments yahobuilder can be also used to
upload your offline prepared html to a ftp server. 

=head1 PREREQUISITES

C<Getopt::Std>

C<Net::FTP>

=head1 COREQUISITES

none

=head1 TODO

Any other good suggestions that people send me!

=head1 BUGS

Probably, but at moment not known.


=head1 AUTHOR

Gerhard Spitzlsperger
gerhard.spitzlsperger@gs68.de
http://www.gs68.de

=head1 SEE ALSO

The source of a older version of the www.gs68.de site (where you 
probably got this file) is available as example. Please be aware that 
some links will not work, because I removed some bigger data files to 
reduce size.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2003, Gerhard Spitzlsperger. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl.

=head1 SCRIPT CATEGORIES

Web

=cut


#!/usr/bin perl -w

use strict;
use Cwd;
use Getopt::Std;
use Net::FTP;
use vars qw( $AUTOLOAD );

#------------------------------------------------------------------------------
# YOU NEED TO SET THESE VARIABLES TO YOUR NEEDS, YOU DON'T NEED
# TO CHANGE SOMETHING BELOW
#
my $g_source_dir = "replace me";
my $g_target_dir = "replace me THIS DIRECTORY IS REASED BY THE -r OPTION ";
my $host = "ftp.....";   # the ftp host for upload
my $login = "......";
my $password = "......";
#------------------------------------------------------------------------------


sub usage
{
  print "Usage $0 [-u] [-r]\n";
  print "  -u to upload the site without local site construction\n";
  print "  -r to remove the target directory\n";
  print "  default is to process the offline html\n\n"; 
}


my $VERSION = 0.05;

my $g_dir_stack = my_directory_stack->new();
my $g_var_stack = my_variable_stack->new( pdir_stack => $g_dir_stack );


print "\n\nnow starting:\n\n\nyahobuilder.pl\n\n\n";

our($opt_r, $opt_u);
getopts('ur');

if( $opt_r )
{
  # erase the target directory
  system("rm -r $g_target_dir/*");
}
elsif( $opt_u )
{
  # upload to ftp host
  &upload();
}
else
{
  chdir($g_source_dir);
  &process_dir($g_source_dir);
}

#------------------------------------------------------------------------------
# subroutine definition
#------------------------------------------------------------------------------
sub process_dir
{
    my $dir = shift;
    chdir($dir);

    $g_dir_stack->push( $dir );

    my @files = <*>;
    my @vars = ();    

    # make id variable for folder
    my $v = new my_var(name => 'folder_id', 
		       content => "$dir",
		       mode => 'id');
    push(@vars, $v);

    # now putting file variables on the stack
    foreach my $fname (@files)
    {
	
	# this simple regex delivers the filename without extension
        # as no path can exist
	if( -f $fname && $fname =~ m!(\w+)\.var$!)
	{
	    print "now working on file variable $fname\n";
	    my $v = new my_var(name => $1, 
			       fname => &get_act_source_dir() . "/$fname",
			       mode => 'file');
	    push (@vars, $v);    
	}
	elsif( -f $fname && $fname =~ /\.my_hp$/)
	{
	    print "now working on $fname\n";
	    my @v = &process_my_hp_file( $fname );
	    push (@vars, @v);  
	}
    }

    $g_var_stack->push( \@vars );

    print "the actual directory is: ". $g_dir_stack->get_path(1) . "\n";

    # create corresponding target directory if not existing
    if(! -d  &get_act_target_dir() )
    {
      system("mkdir " . &get_act_target_dir() );
    }

    foreach my $fname (@files)
    { 
        my $ad = getcwd();

	if(-d $fname )
	{
	    print "$fname is a directory\n";

	    print ".. calling print_dir recursively\n";
	    &process_dir($fname);
            $g_dir_stack->pop();
	    chdir(&get_act_source_dir()); # we cannot simply go up because
	                                  # of symlinks.
	    print ".. now we are back to $fname\n"; 
	}
	elsif( -f $fname && $fname =~ /\.html$/)
	{
	    &process_html_file($fname);
	}
	elsif( -f $fname && $fname =~ /\.var$/)
	{
	    # intentionally empty
	}
	elsif( -f $fname && $fname =~ /^\.my_hp$/)
	{
	    # intentionally empty
	}
	elsif( -f $fname && $fname =~ /~$/)
	{
	    # intentionally empty
            # we don't copy backup files
	}
	else
	{
	    #print "$fname is copied unchanged to target directory\n";

	    my $asd = &get_act_source_dir();
	    my $atd = &get_act_target_dir();

            # compare which files are unchanged, we decide
            # based on modification time and file size
 
            my $s_size = (stat("$asd/$fname"))[7];
            my $t_size = (stat("$atd/$fname"))[7];

            my $s_mtime = (stat("$asd/$fname"))[9];
            my $t_mtime = (stat("$atd/$fname"))[9];
 
       
            if( ($s_size != $t_size) || ($s_mtime >= $t_mtime) 
                 || (! -e "$atd/$fname"))
            {
              print " updated file: $asd/$fname \n";
	      system("cp $asd/$fname $atd");
	    }
	  
	}
    }
    
    # remove vars of this dir from stack
    $g_var_stack->pop();
}



sub process_html_file
{
    my $fname = shift;

    my $buf = $g_var_stack->process_file(&get_act_source_dir() . "/$fname");

    my $out_file = &get_act_target_dir() . "/$fname";

    unless( open(FO, "> $out_file") )
    {
	print STDERR "file $out_file cannot be opened\n\n";
	return;
    }

    print FO $buf;

    close(FO);
}

sub process_my_hp_file
{
    my $fname = shift;
    my @vars = ();

    unless( open(FH, "$fname") )
    {
	print STDERR "file $fname cannot be opened\n\n";
	return;
    }

    while( my $line = <FH> )
    {
        chomp $line;

	if( $line =~ /~~~/ )
	{
	    my $t = $';
	    my $v = new my_var(name => $`, 
			       content => $t,
			       mode => 'folder_title');
            #' just not to confuse sytay highlighting of emacs
	    push(@vars, $v);        
	}
    }


    # clean up and return
    close(FH);
    return @vars;
}


sub get_act_source_dir
{
    return $g_source_dir . $g_dir_stack->get_path(1);
}

sub get_act_target_dir
{
    return $g_target_dir . $g_dir_stack->get_path(1);
}

#------------------------------------------------------------------------------
# subroutines for upload
#------------------------------------------------------------------------------
sub upload
{
  my $ftp = Net::FTP->new($host);
  $ftp->login($login, $password);

  if( !defined $ftp )
  {
     print "could not login ... exiting\n";
     exit( -1);
  }

  &upload_dir($g_target_dir, $ftp);

  $ftp->quit;
}

sub upload_dir
{
    my $dir = shift;
    my $ftp = shift;
   
    chdir($dir);

    $g_dir_stack->push( $dir );

    my @files = <*>;
    
    print "the actual directory is: ". $g_dir_stack->get_path(1) . "\n";
    
    foreach my $fname (@files)
    { 
        my $ad = getcwd();

	if(-d $fname )
	{
	    print "$fname is a directory\n";

            my $e = $ftp->cwd( $g_dir_stack->get_path(1) . "/$fname" );
            print "e $e\n";


            # if the directory doesn't exist make it 
            if( ! $e )  
            {  
	      print "create " . $g_dir_stack->get_path(1) ."\n";
              $ftp->mkdir( $g_dir_stack->get_path(1). "/$fname")    
	    }

	    print ".. calling upload_dir recursively\n";

	    &upload_dir($fname, $ftp);
            $g_dir_stack->pop();
	    chdir(&get_act_target_dir()); # we cannot simply go up because
	                                  # of symlinks.
	    print ".. now we are back to $fname\n"; 
	}
	else
	{
	    my $asd = &get_act_target_dir();
	  
            # compare which files are unchanged, we decide
            # based on modification time 
            my $s_mtime = (stat("$asd/$fname"))[9];
       
            # this is the required filename on the server 
            my $temp = $g_dir_stack->get_path(1);
              
            print " $temp/$fname \n";  

            my $f_mtime = $ftp->mdtm("$temp/$fname");
            
            if( $s_mtime >= $f_mtime )
            {
              print " updated file: $asd/$fname \n";
	      my $t = $ftp->put( "$asd/$fname",  "$temp/$fname");
              print "  to $t \n\n";
	    }
	}
    }
}

#------------------------------------------------------------------------------
# Package Definition
#------------------------------------------------------------------------------

package my_var;

use strict;
use vars qw( $AUTOLOAD );
use Carp;

BEGIN
{
    my %_attr_data = ( _content   => [undef, 'read/write'],
		       _fname     => ['', 'read'] ,
		       _mode      => ['file', 'read'] ,
		       _name      => ['', 'read'] ,
		       _type      => ['scalar', 'read/write']
		       );

    my $_count = 0;

    sub _accessible
    {
	my ($self, $attr, $mode ) = @_;
	return $_attr_data{$attr}[1] =~ /$mode/;
    }
 
    sub _default_for
    {
	my ($self, $attr ) = @_;
	return $_attr_data{$attr}[0];
    }

    sub _standard_keys
    {
	return  keys %_attr_data;
    }

    sub get_count
    {
	return $_count;
    }

    sub _incr_count { ++$_count }
    sub _decr_count { --$_count }

}

sub new
{
    my ($class, %arg ) = @_;
    my $self = bless {}, $class;

    foreach my $attr_name ($self->_standard_keys() )
    {
	$attr_name =~ /^_(.*)/;
	my $arg_name = $1;

	if( exists $arg{$arg_name} )
	{
	    $self->{$attr_name} = $arg{$arg_name};
	}
	else
	{
	    $self->{$attr_name} = $self->_default_for($attr_name);
	}
    }

    $self->_incr_count();

    return $self;
}
	    

sub DESTROY
{
    $_[0]->_decr_count();
}

sub AUTOLOAD
{
    no strict "refs";

    my ($self, $new_value) = @_;

    # was it get....?
    if( $AUTOLOAD =~ /.*::get(_\w+)/  && $self->_accessible( $1, 'read'))
    {
	my $attr_name = $1;

	*{$AUTOLOAD} = sub { return $_[0]->{$attr_name} };
	return $self->{$attr_name};
    }

    # was it set....?
    if( $AUTOLOAD =~ /.*::set(_\w+)/  && $self->_accessible( $1, 'write'))
    {
	my $attr_name = $1;

	*{$AUTOLOAD} = sub { $_[0]->{$attr_name} = $_[1]; return; };
	$self->{$attr_name} = $new_value;
	return;
    }  
    
    # seems to be a failure
    croak "no such method: $AUTOLOAD";
}

#------------------------------------------------------------------------------


package my_directory_stack;

use strict;
use vars qw( $AUTOLOAD );
use Carp;

BEGIN
{
    my %_attr_data = ( _stack   => [undef, 'read']
		     );

    my $_count = 0;

    sub _accessible
    {
	my ($self, $attr, $mode ) = @_;
	return $_attr_data{$attr}[1] =~ /$mode/;
    }
 
    sub _default_for
    {
	my ($self, $attr ) = @_;
	return $_attr_data{$attr}[0];
    }

    sub _standard_keys
    {
	return  keys %_attr_data;
    }

    sub get_count
    {
	return $_count;
    }

    sub _incr_count { ++$_count }
    sub _decr_count { --$_count }

}

sub new
{
    my ($class, %arg ) = @_;
    my $self = bless {}, $class;

    # initialization of attributes
    foreach my $attr_name ($self->_standard_keys() )
    {
	$attr_name =~ /^_(.*)/;
	my $arg_name = $1;

	if( exists $arg{$arg_name} )
	{
	    $self->{$attr_name} = $arg{$arg_name};
	}
	else
	{
	    $self->{$attr_name} = $self->_default_for($attr_name);
	}
    }

    # count instances
    $self->_incr_count();

    # initially the stack is an empty list
    $self->{'_stack'} = [];

    return $self;
}
	

sub get_path
{
    my $self = shift;
    my $level = shift || 1;
    my $max = shift || $#{$self->{'_stack'}};

    my $r = '';

    for(my $i=abs($level); $i <= $max; $i++)
    {
	$r .= '/' . $self->{'_stack'}->[$i];
    }

    $r =~ s!/!! if( $level < 0 );

    return $r;
}

sub push
{
    my $self = shift;
    my $t = shift;

    push(@{$self->{'_stack'}}, $t);
}

sub pop
{
    my $self = shift;
 
    return pop(@{$self->{'_stack'}});
}

sub DESTROY
{
    $_[0]->_decr_count();
}

sub AUTOLOAD
{
    no strict "refs";

    my ($self, $new_value) = @_;

    # was it get....?
    if( $AUTOLOAD =~ /.*::get(_\w+)/  && $self->_accessible( $1, 'read'))
    {
	my $attr_name = $1;

	*{$AUTOLOAD} = sub { return $_[0]->{$attr_name} };
	return $self->{$attr_name};
    }

    # was it set....?
    if( $AUTOLOAD =~ /.*::set(_\w+)/  && $self->_accessible( $1, 'write'))
    {
	my $attr_name = $1;

	*{$AUTOLOAD} = sub { $_[0]->{$attr_name} = $_[1]; return; };
	$self->{$attr_name} = $new_value;
	return;
    }  
    
    # seems to be a failure
    croak "no such method: $AUTOLOAD";
}

#------------------------------------------------------------------------------
package my_variable_stack;

use strict;
use vars qw( $AUTOLOAD );
use Carp;

BEGIN
{
    my %_attr_data = ( _stack   => [undef, 'read'],
		       _pdir_stack   => [undef, 'read/write'],
		     );

    my $_count = 0;

    sub _accessible
    {
	my ($self, $attr, $mode ) = @_;
	return $_attr_data{$attr}[1] =~ /$mode/;
    }
 
    sub _default_for
    {
	my ($self, $attr ) = @_;
	return $_attr_data{$attr}[0];
    }

    sub _standard_keys
    {
	return  keys %_attr_data;
    }

    sub get_count
    {
	return $_count;
    }

    sub _incr_count { ++$_count }
    sub _decr_count { --$_count }

}

sub new
{
    my ($class, %arg ) = @_;
    my $self = bless {}, $class;

    # initialization of attributes
    foreach my $attr_name ($self->_standard_keys() )
    {
	$attr_name =~ /^_(.*)/;
	my $arg_name = $1;

	if( exists $arg{$arg_name} )
	{
	    $self->{$attr_name} = $arg{$arg_name};
	}
	else
	{
	    $self->{$attr_name} = $self->_default_for($attr_name);
	}
    }

    # count instances
    $self->_incr_count();

    # initially the stack is an empty list
    $self->{'_stack'} = [];

    return $self;
}
	
sub push
{
    my $self = shift;
    my $t = shift;

    push(@{$self->{'_stack'}}, $t);
}

sub pop
{
    my $self = shift;
 
    return pop(@{$self->{'_stack'}});
}

sub lookup_variable
{
    my $self = shift;
    my $name = shift;

    my $result; 
    my $i; 

    

    # check some standard variables
    if( $name eq 'navigate_parents' )
    {
	print "navigate ....\n";
	$result = '<a href="/index.html">Home</a>';	

	for($i=1; $i <= $#{$self->{'_stack'}}; $i++)
	{   
	    my @vars = @{$self->{'_stack'}->[$i]};

	    my $t;
	    foreach my $j (@vars)
	    {
		if('folder_title' eq $j->get_name() )
		{
		    $t =  $j->get_content();
		    last;
		} 
	    }  

	    if( !defined $t )
	    {
		foreach my $j (@vars)
		{
		    if('folder_id' eq $j->get_name() )
		    {
		       $t =  $j->get_content();
		    }   
		}
	    }
	    
	    # read the directory stack until the relevant level
	    $result .= ' &gt;  <a href="' . 
                        $self->{'_pdir_stack'}->get_path(1, $i) .
			'/index.html"> ' . $t . '</a>';

	}
	print $result;
    }

    # check the stack
    $i=$#{$self->{'_stack'}};
    while( $i >= 0 && !defined $result)
    {
	my @vars = @{$self->{'_stack'}->[$i]};

	for( my $j=0; $j <= $#vars; $j++)
	{
	    if($name eq $vars[$j]->get_name() )
	    {
		if( defined $vars[$j]->get_content() )
		{
		    $result = $vars[$j]->get_content();
		} 
		elsif( $vars[$j]->get_mode() eq 'file' ) 
		{
		    # content of file variables will be never set
                    # because some variables which are called inside
                    # might depend on the directory
		    $result = $self->process_file( $vars[$j]->get_fname() );
		}
		else
		{
		    print STDERR "VARIABLE $name not " .
                                 "defined in this context!\n";
		    exit(1);
		}
	    }
	}
	$i--;
    }

    if( !defined $result )
    {
	print STDERR "VARIABLE $name not " .
	    "defined in this context!\n";
	exit(1);
    }
    print "now looking up: $name, ok\n";
    #print "result:\n$result\n\n!!!!continue"; <STDIN>;

    return $result;
}

sub process_file
{
    my $self = shift;
    my $fname = shift;

    my $buf = '';

    unless( open(FH, $fname) )
    {
	print STDERR "file $fname cannot be opened\n\n";
	return;
    }

    my @lines = <FH>;

    while( @lines )
    {
	my $line = shift @lines;
	
	# ? is necessary to force non greedy matching
	if( $line =~ m!<dtml-var\s+(.*?)\s*/>! )
	{
	    my $var = $1;
 
	    my $t = $self->lookup_variable($var);
	    
	    $line = '';
	    $line .= $` if defined $`;
	    $line .= $t;

	    # must be parsed again
	    unshift(@lines, $') if defined $';
	}

	$buf .= $line;
    }

    close(FH);

    return $buf;
}

sub print_var_stack
{
    my $self;

    my $i=$#{$self->{'_stack'}};

    print "var stack (len: $i)\n";
    while(  $i >= 0 )
    {
	my @vars = @{$self->{'_stack'}->[$i]};

	print "level $i:\n";
	for( my $j=0; $j <= $#vars; $j++)
	{
	    print  '  ' . $vars[$j]->get_name() . 
		          $vars[$j]->get_fname() ."\n"; 
	}
	print "\n";
	$i--;
    }
}

sub DESTROY
{
    $_[0]->_decr_count();
}

sub AUTOLOAD
{
    no strict "refs";

    my ($self, $new_value) = @_;

    # was it get....?
    if( $AUTOLOAD =~ /.*::get(_\w+)/  && $self->_accessible( $1, 'read'))
    {
	my $attr_name = $1;

	*{$AUTOLOAD} = sub { return $_[0]->{$attr_name} };
	return $self->{$attr_name};
    }

    # was it set....?
    if( $AUTOLOAD =~ /.*::set(_\w+)/  && $self->_accessible( $1, 'write'))
    {
	my $attr_name = $1;

	*{$AUTOLOAD} = sub { $_[0]->{$attr_name} = $_[1]; return; };
	$self->{$attr_name} = $new_value;
	return;
    }  
    
    # seems to be a failure
    croak "no such method: $AUTOLOAD";
}


1;

