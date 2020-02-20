#!/usr/bin/perl -w

use strict;
use vars qw ($VERSION $found $url $title $To);

$VERSION = '1.03';

# $wait is the number of down notices you'll allow before freaking out.  
# Running at 1 usually produces a couple false alarms per week.  2 is recommended.
my $wait = 2;

# $From is who you want these to be sent from?
# Leave blank to default to /etc/HOSTNAME.
# my $From = DISPLAY NAME <email address>
# my $From = "MYCOMPUTER <root\@my.domain.com>";

# Add as many websites as you like here using multiple &whatsup subroutines.
# ('URL', 'Title', 'To an email address, To another email address')                           
#&whatsup('http://my.domain.com/index.html','MY WEBSITE','email@domain.com,email@mydomain.com,pageme@domain.com');
&whatsup('http://www.s1te.com/index.html','S1TE.COM','BarracodE@s1te.com');

exit;

sub whatsup
{
	$found = 0;
	$url = shift;
	$title = shift;
	$To = shift;

	# Check if it's up.
	#open (PIPE, "/usr/bin/lynx -source $url|") || die "Can't open /usr/bin/lynx: $!\n";
	open (PIPE, "/usr/bin/lynx -source $url|");
	while (<PIPE>)
	{
   	$found = 1 if ($_ =~ /IMUP/);
	}
	close PIPE;

	# Use IPC::ShareLite shared memory for easy access to DB info.
	use IPC::ShareLite;
	my $share = new IPC::ShareLite( -key 		=> "$title",
											  -create	=> 'yes',
											  -destroy	=> 'no',
											  -size		=> 25 );
	my $count = $share->fetch;
	$count++;	

	if (!$found)
	{
		my $result = $share->store("$count");

		# Send email after $wait number of down notices.
		&email('DOWN') if ($wait == $count);

		# Debug.
		#print "$title is DOWN (found=$found, count=$count, wait=$wait)\n";
		#print "I'm sending DOWN email now for $title.\n" if ($wait == $count);
	}
	else	
	{
		my $result = $share->store("0");

		# Send email if we're past the $wait period.
		&email('UP') if ($count > $wait);

		# Debug.
		#print "$title is UP (found=$found, count=$count, wait=$wait)\n";
		#print "I'm sending UP email now for $title.\n" if ($count > $wait);
	}
}

sub email
{
	my $what = shift;
	open(MAIL, "|/usr/sbin/sendmail -t") || die "Can't open /usr/sbin/sendmail: $!\n";

	print MAIL "To: $To\n";
	print MAIL "From: $From\n";
	print MAIL "Subject: $title IS $what!!!!\n\n";
	print MAIL "$url\n";

	close MAIL;
}

__END__

=head1 NAME

	whatsup.pl $VERSION.  Verify's your websites are running.

=head1 README

	Verify your websites are running from multiple servers,
	inside and outside your firewall.  Notify you when they go
	down.

=head1 DESCRIPTION

	Checks each webpage for an <IMUP> tag every (cron).
	It let's you know when you're down, & when you're back up.
	Recommended to run (cron) every minute.

	Compared to watchdog, this was designed to be executed on multiple servers.
	Apache Restart logic has NOT been added (if Apache happens to go down,
	there are usually bigger problems than simply restarting the webserver).

	Current logic is to watch every webserver from every other webserver.
	It's recommended you run this outside your firewall as well.   Find a partner
	to cross watch websites, much like secondary DNS logic.

	If your websites are ever unreachable, page/email every admin so they can
	jump on a terminal and get it back up.

=head1 SYNOPSIS

	Add <IMUP> to the bottom of any webpage you'd like to monitor.

	Run this from your cron:

	* * * * * /home/httpd/cgi-bin/whatsup-1.XX.pl > /dev/null 2>&1

	$wait is the number of down notices you'll allow before freaking out.
	Running at 1 usually produces a couple false alarms per week.  2 is recommended.

	$From is who you want these to be sent from?
	Leave blank to default to /etc/HOSTNAME.
	$From = DISPLAY NAME <email address>

	&whatsup('URL', 'Title', 'To an email address, To another email address');

	URL is obvious.
	Title what webpage you're monitoring (My Dog Skip, My Flower Shop).
	To: email address are comma dilimited.  Add as many admins here as you like.

	It's recommended you find a paging service you can send an email to which will
	in turn page you immediately.

	Uncomment the Debug lines to see what's going on.  Comment them out again when
	things are running smoothly.

=head1 AUTHOR

   Charles Day
   BarracodE@CPAN.org
   http://www.s1te.com

=pod SCRIPT CATEGORIES

Web

=pod PREREQUISITES

IPC::ShareLite

=cut
