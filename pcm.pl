#!/usr/local/bin/perl

# pcm
# perl cgi mailer
# Chris Josephes 20020322

#
# Frozen Code
# Used in production environment!
#

#
# Security
#

$ENV{PATH}="/usr/bin";

#
# Compiler Directives
#

use strict;

$ENV{PATH}="/usr/bin";

#
# Includes
#

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Net::SMTP;
use File::Basename;

#
# Global Variables
#

use vars qw/$VERSION $Q $ConfigFile $Master $Site @Errors/;

$VERSION=0.93;

$ConfigFile="/etc/pcm.conf";

$Master={};
$Site={};

#
# Subroutines
#

sub smtpError
{
my ($server)=shift;
my ($string);
$string=$server->code()." ".$server->message();
return $string;
}

#
# Read in the configuration file
sub readConfig
{
my ($file,$cfg)=@_;
my ($line,$key,$value);
# Default configuration values
$cfg->{args}={
	"server" => "localhost",
	"serveroverride" => "no",
	"inputlimit" => "10000",
	"inputlimitoverride" => "no",
};
# Open the configuration file and read it
open (F, $file) || return undef;
while ($line=<F>)
{
	next if ($line=~/^#/);
	chop($line);
	($key,$value)=split(/:\s+/,$line);
	($key)=lc($key);
	$cfg->{args}->{$key}=$value;
}
#print("Config data is ",$cfg->{args}->{server},"\n");
close(F);
return;
}

# Read in the template file
sub readTemplate
{
my ($file,$cfg)=@_;
my ($line);
open (F, $file) || return 0;
# Get the template headers
while ($line=<F>)
{
	if ($line=~/X-PCM-/i)
	{
		chop($line);
		my ($key,$value);
		$line=~s/^X-PCM-//i;
		($key,$value)=split(/:\s+/,$line,2);
		$key=~s/\s+$//;
		$key=lc($key);
		$cfg->{args}->{$key}=$value;
	} elsif ($line ne "\n")
	{
		push (@{$cfg->{theaders}},$line);
	} else {
		last;
	}
}
while ($line=<F>)
{
	push(@{$cfg->{tbody}},$line);
}
close(F);
# Add a header for the client IP
push(@{$cfg->{theaders}},"X-PCM-PostingIP:".$Q->remote_addr()."\n");
push(@{$cfg->{theaders}},"X-PCM-ScriptURL:".$Q->url()."\n");
return 1;
}

# A very simple and dirty parser
sub parse
{
my ($obj)=shift;
my ($line,$parsed);
while (@{$obj->{theaders}})
{
	$line=shift(@{$obj->{theaders}});
	# ugly, non-greedy template language match
	if ($line=~/(.*)\[(.*?)\](.*)/)
	{
		push(@{$obj->{output}},$1);
		$parsed=&replace($2,$obj);
		push(@{$obj->{output}},$parsed);
		unshift(@{$obj->{theaders}},$3);
	} else {
		push(@{$obj->{output}},$line);
	}
}
push(@{$obj->{output}},"\n");
while(@{$obj->{tbody}})
{
	$line=shift(@{$obj->{tbody}});
	if ($line=~/(.*)\[(.*?)\](.*)/)
	{
		push(@{$obj->{output}},$1);
		$parsed=&replace($2,$obj);
		push(@{$obj->{output}},$parsed);
		unshift(@{$obj->{tbody}},$3);
	} else {
		push(@{$obj->{output}},$line);
	}
}
return;
}

sub replace
{
my ($var,$template)=@_;
my ($output,$type,$name);
$var=~s/^\s+|\s+$//g;
($type,$name)=split(/:\s*/,$var,2);
#print("PARSING: $var ($type and $name) \n");
if ($type eq "ENV")
{
	$output=$ENV{$name};
} elsif ($type eq "CGI")
{
	$output=$Q->param($name);
} elsif ($type eq "PCM")
{
	if ($name eq "time")
	{
		$output=scalar(localtime(time()));
	} elsif ($name eq "options")
	{
		my ($key);
		$output="\n";
		foreach $key (keys(%{$template->{args}}))
		{
			$output.="$key : $template->{args}->{$key}\n";
		}
		$output.="\n";
	}
} else {
	# We shouldn't arrive here
}
return $output;
}

sub sanitize
{
my ($input)=shift;
my ($output)="";
if ($input =~/([\w\d]+\@[\w\d\.]+[\w\d]+)/)
{
	$output=$1;
}
return $output;
}

# Get the To:, CC:, BCC:, and From: addresses from the template
# The regex tries to match based on locale settings
# and account for usernames without qualified domains
# but probably fails miserably

sub getAddresses
{
my ($obj,$config)=@_;
my ($line,$hdr,$value,@addrs,$address,$limit,$recpcount);
$limit=$obj->{args}->{maxrecipients} || 4;
$recpcount=0;
foreach $line (@{$obj->{output}})
{
	if ($line=~/^From\s*:/i || $line=~/^To\s*:/i 
		|| $line=~/^CC\s*:/i || $line=~/^BCC\s*:/i)
	{
		($hdr,$value)=split(/:\s+/,$line,2);
		#print("<br>The $hdr value is $value<br>\n");
		(@addrs)=split(/,/,$value);
		foreach $address (@addrs)
		{
			$address=sanitize($address);
			if ($address)
			{
				$hdr=lc($hdr);
				if ($hdr eq "from")
				{
					$obj->{args}->{from}=$address;
				} else {
					push(@{$obj->{args}->{to}},$address)
					unless ($recpcount >= $limit);
					$recpcount++;
				}
			} else {
				# Invalid value for sender/recipient
			}
		}
	}
	last if ($line eq "\n");
}
$obj->{args}->{from} = $config->{args}->{defaultfrom} 
	unless ($obj->{args}->{from});
unless ($obj->{args}->{from})
{
	my ($default)=sanitize($config->{args}->{defaultfrom});
	if ($default)
	{
		$obj->{args}->{from}=$default;
	} else {
		$obj->{errormsg}="No sender specified!";
		return 0;
	}
}
unless (@{$obj->{args}->{to}})
{
	$obj->{errormsg}="No recipient(s) specified";
	return 0;
}
return 1;
}

sub sendMail
{
my ($template,$config)=@_;
my ($server,$host,$status,$recp);
$status=1;
return $status if (lc($config->{args}->{nomail}) eq "yes");
if ($config->{args}->{serveroverride} && $template->{args}->{server})
{
	$host=$template->{args}->{server};
} else {
	$host=$config->{args}->{server};
}
#print("Using mail host $host\n");
if ($host)
{
	$server=Net::SMTP->new($host);
	if ($server)
	{
		unless ($server->mail("<".$template->{args}->{from}.">"))
		{
			$template->{errormsg}=smtpError($server);
			return 0;
		}
		foreach $recp (@{$template->{args}->{to}})
		{
			unless ($server->to("<".$recp.">"))
			{
				$template->{errormsg}=smtpError($server);
				return 0;
			}
		}
		unless ($server->data(@{$template->{output}}))
		{
			$template->{errormsg}=smtpError($server);
			return 0;
		}
		$server->quit();
	} else {
		# Couldn't connect to SMTP server
		$template->{errormsg}=
			"Couldn't connect to SMTP server ($host)";
		return 0;
	}
} else {
	$template->{errormsg}="No SMTP server specified";
	return 0;
}
return 1;
}

sub writeFile
{
my ($site)=@_;
my ($file,$status);
$file=$site->{args}->{savefile};
$status=1;
if ($file)
{
	if ($file !~/\//)
	{
		my ($path)=dirname($Q->path_translated());
		$file=$path."/".$file;
	}
	if (open (F, ">>$file"))
	{
		my ($date);
		$date=scalar(localtime(time()));
		if ($site->{args}->{savefilemode} eq "template")
		{
			my ($line,$user);
			$user=$ENV{"LOGNAME"} || $ENV{"USER"} || "nobody";
			print F ("From $user $date\n");
			while(@{$site->{output}})
			{
				$line=shift(@{$site->{output}});
				$line=">".$line if ($line=~/^From/);
				print F $line;
			}
			print F "\n";
		} else {
			my (@list,$p);
			(@list)=$Q->param();
			print F ("START\n");
			print F ("Date: $date\n");
			print F ("PostingIP: ",$Q->remote_addr(),"\n\n");
			foreach $p (@list)
			{
				print F ("|$p:".$Q->param($p),"\n");
			}
			print F ("END\n");
		}
		close(F);
	} else {
		$status=0;
		#print("Error opening file for writing\n");
	}
} else {
	#print("We didn't want to save to a file\n");
	# no file was specified
}
return $status;
}

sub footerOut
{
print <<EOHTML
<hr/>
<p>PCM version $VERSION</p>
EOHTML
;
return;
}

sub endHtml
{
print <<EOHTML
</body>
</html>
EOHTML
;
}

sub startHtml
{
my ($title)=shift;
print <<EOHTML
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3c.org/1999/xhtml" xml:lang="em" lang="en">
<head>
<title>$title</title>
</head>
<body>
<h1>$title</h1>
EOHTML
;
return
}

# Post email/file operations
sub successOut
{
my ($template)=@_;
if ($template->{args}->{"successurl"})
{
	print $Q->header(-location => $template->{args}->{successurl});
	return;
}
print $Q->header();
startHtml("Success");

print <<EOHTML
<p>
The email has been successfully delivered
</p>
EOHTML
;

footerOut() if (lc($template->{args}->{footer}) eq "yes");
endHtml();
return;
}

sub errorOut
{
my ($template)=@_;
my ($field);
if ($template->{args}->{errorurl})
{
	print $Q->header(-location => $template->{args}->{errorurl});
	return;
}
print $Q->header();
startHtml("Missing Field Error");
print <<EOHTML
<p>
The following form fields need to be filled out.
</p>
EOHTML
;
print("<ul>\n");
foreach $field (@{$template->{missing}})
{
	print("<li>$field</li>\n");
}
print("</ul>\n");
footerOut() if (lc($template->{args}->{footer}) eq "yes");
endHtml();
return;
}

sub failureOut
{
my ($template)=@_;
my ($message)=$template->{errormsg};
if ($template->{args}->{failureurl})
{
	print $Q->header(-location => $template->{args}->{failureurl});
	return;
}
print $Q->header();
startHtml("Error");
print <<EOHTML
<p>
The following error(s) were encountered:
</p>
EOHTML
;
print("<ul><li>$message</li></ul>\n");
footerOut() if (lc($template->{args}->{footer}) eq "yes");
endHtml();
return;
}

sub checkForm
{
my ($template,$q)=@_;
my ($status)=1;
if ($template->{args}->{"required"})
{
	$template->{missing}=[];
	my (@req,@param,%match,$item);
	(@req)=split(/,/,$template->{args}->{required});
	(@param)=$q->param();
	foreach $item (@req)
	{
		$match{$item}=0;
	}
	foreach $item (@param)
	{
		$match{$item}=1 if 
			(defined($match{$item}) && $Q->param($item) ne "");
	}
	foreach $item (keys(%match))
	{
		if ($match{$item} != 1)
		{
			push(@{$template->{missing}},$item);
			$status=0;
		}
	}
}
return $status;
}

sub mainflow
{
my ($templateFile,$template,$config,$mailstatus,$formstatus);
$templateFile=$Q->path_translated();
$config={};
$template={};
readConfig($ConfigFile,$config);
unless (readTemplate($templateFile,$template))
{
	$template->{errormsg}="Couldn't open template $templateFile";
	failureOut($template);
	exit 2;
}
parse($template);
unless (getAddresses($template,$config))
{
	failureOut($template);
	exit 2;
}
$formstatus=checkForm($template,$Q);
unless ($formstatus)
{
	errorOut($template);
	exit 2;
}
$mailstatus=sendMail($template,$config);
unless ($mailstatus)
{
	failureOut($template);
	exit 2;
}
unless (writeFile($template))
{
	$template->{errormsg}="Couldn't write to savefile";
}
successOut($template,$mailstatus,$formstatus);
return;
}

#
# Main Program Block
#

# Set up the CGI environment
$CGI::DISABLE_UPLOADS=1;
$CGI::POST_MAX=1024*100;

$Q = CGI->new();

#print $Q->header();

# Main Program Flow
mainflow();


#
# Exit Block
#
exit 0;

#
# Documentation
#

=head1 NAME

pcm -- Perl CGI Mailer

=head1 SYNOPSIS

<form method="post" action="/cgi-bin/pcm/template.txt">

</form>

=head1 ABSTRACT

PCM is a CGI form input mail gateway, designed to address some of the 
limitations or problems with other programs currently available.

=over 4

=item Security

It is believed that input from the Common Gateway Interface should NEVER 
be trusted.  All configuration and email options are setup in a file on 
the local web server that the program has access to.  It does not trust 
form values or HTTP headers as forms of authentication or access control.

=item Flexibility.

Popular options such as "success pages", "required fields", or saving 
copies of the input to a file are supported.

=item SMTP Delivery 

PCM is not dependent on sendmail, qmail, or any command line mail agent.  
However, it does need to be aware of a SMTP host that it can use to send 
outgoing mail from.  That host could be the localhost or a dedicated SMTP 
server.

=item Ease Of Configuration

The source code shouldn't have to be modified to use PCM in your 
environment.  All configuration options and runtime options are set in 
the global configuration file or individual template files.

=item Virtual Hosting

One copy of pcm is needed fon a shared webserver environment.  No per 
site/server configuration is necessary.

=back

=head1 Invocation

The following HTML code is used to call pcm.

<form method=post action="/cgi-bin/pcm/template">

(HTML form)

</form>

The "template" parameter refers to a template file that pcm uses to get
configuration information, and template of the email message to send out.
The web server will look for the template file in the root document 
directory of the server, so you will need to specify the relative path 
for the file if it's located somewhere else.

=head1 Main Configuration File

The global configuration file is /etc/pcm.conf.  
The following options can be set in the file:

=over 4

=item Server: [hostname]

The hostname of the SMTP server to use for sending messages

=item ServerOverride: (yes|no)

Indicates whether or not an SMTP server can be specified in the
template file itself.

=item DefaultFrom: [email-address]

If for some reason, a template doesn't specify a From: header, PCM 
will put the value of this variable in its place.

=back

=head1 Template Configuration File

The template file is a text file that contains the exact message that 
will be piped to the SMTP server through the DATA command.  The 
From:, To:, CC:, and BCC: headers from the message will be scanned and 
the values will be used for the "MAIL FROM" and "RCPT TO" SMTP commands.

Options that change the behavior of PCM are configured as X headers in 
the headers block of the email message.  All PCM options are 
prefixed with "X-PCM-"

=head1 Template PCM Header Options

=over 4

=item X-PCM-SuccessURL: [url]

What webpage to bring up when the form is processed successfully

=item X-PCM-ErrorURL: [url]

What webpage to bring up when there is an error with the form input.

=item X-PCM-FailureURL: [url]

What webpage to bring up when pcm fails (errors incured by parsing 
the template, or by sending the mail message).

=item X-PCM-MaxRecipients: [integer]

If you're brave enough to put form field values in the To:, CC:, or 
BCC: headers, this parameter will let you set a hard limit for all 3.
If that limit is breached, only the recipients up to the limit will 
receive the message.  The default limit is 4.

=item X-PCM-Required: [field1,field2]

What fields in the HTML form are required to have a value.

=item X-PCM-SaveFile: [filename]

What local file should the form data be saved to

=item X-PCM-SaveMode: (template|dump)

Indicates whether the entire template should be saved to the file, or 
a dump of the CGI variables.  If the entire template is saved to the 
file, pcm prepends a "From " line to the output to keep the file 
in the Unix mbox format.

=item X-PCM-Footer: (yes|no)

Should the footer identifying the version of PCM running be added to the 
output? (Not used when a URL is specified for output)

=item X-PCM-NoMail: (yes|no)

If set to "yes", PCM won't send out the email.  This can be useful for 
debugging purposes, or if you just want PCM to only write the data to a 
file.

=item X-PCM-Server: [hostname]

Identifies the SMTP server to use for sending out this message.  This 
option may not be available if ServerOverride is set in the global 
configuration file.

=back

=head1 Template Replacement Commands

The following commands can be used to insert values into the template. 
These values can be substituted in either the headers or the body 
of the message.

=over 4

=item [ENV:(variable)]

Imports an environmental variable.  For example [ENV:FORM_METHOD].

=item [CGI:(variable)]

Imports a CGI variable extracted from the QUERY_STRING.

=item [PCM:(command)]

Supports simple commands for additional functionality.

=item [PCM:time]

Returns the current time the template was parsed.

=back

=head1 SECURITY ISSUES

=over 4

=item Protect your template files

If possible, configure your web server, so it won't send out the raw 
template file.  It may leak security information that would be valuable 
to anyone who tries to abuse the PCM program.

=item If substituting the To: header, set the MaxRecipients to 1.

If you're only sending the form to one recipient, and that recpient 
can be changed through the HTML form itself, set the MaxRecipients 
value to 1 in order to limit the potential for abuse.

=item Check abuse through the PCM headers

PCM adds the following headers to all emails it sends out.

X-PCM-PostingIP

Client IP that accessed the instance of pcm.

X-PCM-ScriptURL

The full URL of the pcm script.

=back

=over 4

=head1 GETADDRESSES

The getAddresses routine is used to grab valid email addresses from the 
template from the From/To/CC/BCC header lines.

PCM uses the following regular expression to grab email addresses.

=item ([\w\d]+\@[\w\d\.]+[\w\d]+)

As such, it will require that a fully qualified email address is always 
passed in the template.  It will also make sure it grabs the address when 
using special lines that include the gecos field or full name of the 
sender/recipient.

=item ([\w\d]+(\@[\w\d\.]+[\w\d]+)?)

This is an alternative form of the expression used.

This will work in cases where you may want to use an unqualified address 
(root/postmaster), but it could fail in cases where a quoted name is 
used on the same line.

During the SMTP sending, the addresses are enclosed in < > signs.

=head1 TODO

=item mod_perl

Make sure the code works well in mod_perl environments

=item input limit

Let the server or user override the $CGI::POST_MAX value?

=item code cleanup

The code is really ugly in some places.  Needs work.

=item success/failure templates

Consider a template system for the success or failure pages?

=back

=head1 AUTHOR

Chris Josephes, chrisj@onvoy.com

=head1 PREREQUISITES

This module requires the modules, C<Net::SMTP>, C<CGI>, C<CGI::Carp>, and 
C<File::Basename>.

=head1 SCRIPT CATEGORIES

This script may be found in CPAN scripts area in the C<CGI> and C<Web> 
categories.
