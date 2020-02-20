#!/usr/bin/perl

#==============================================================================#
my $VERSION = 2.1;
#==============================================================================#

=head1 NAME

ssh2ssl - SSH through SSL proxy tunnel

=head1 DESCRIPTION

Allows you to tunnel an SSH connection through an SSL (https) web proxy.

=head1 USAGE

=head2 Normal Use

Do this if you just need to get through a proxy server. Note that the SSH
protocol negotiation will be unencrypted. A good IDS should catch
this conversation.

You will need to the following to your ~/.ssh/config:

    Host <REMOTE>
        ProxyCommand /path/to/bin/ssh2ssl <PROXY:PORT> %h:%p
        Port 443

You also need to have an sshd running on the far side. Your proxy probably
won't let you use port 22, so run an "sshd -p443" on the <REMOTE> and access
it locally using "ssh <REMOTE>" (the port was set in the config above).      

=head2 Paranoid Use

If you wish to really hide the fact that you are tunnelling SSH, you need to
wrap the SSH protocol negotiation inside real SSL.

You will need to the following to your ~/.ssh/config:

    Host <REMOTE>
        ProxyCommand /path/to/bin/ssh2ssl -ssl <PROXY:PORT> %h:%p
        Port 443

Different from above, you will now need an SSL server (e.g. stunnel 
http://www.stunnel.org/) running on port 443 to decrypt the SSL
stream and pass it to SSH. In stunnel you would do this by running:

	stunnel -d 443 -r 22 -p /etc/httpd/conf/stunnel.pem 

You should specify a PEM certificate. Without one, stunnel will default
to a dummy certificate (which is again something a good IDS should spot).

=head1 TIPS

=head2 DISCONNECTS

Most proxies and some firewalls will disconnect idle sessions, so if your
ssh sessions are being dropped, you have several options. The easiest is
to just leave something like 'top' running in your session while you are not
using it. Similarly you could also tunnel an X application to generate traffic.

However the best way is to add the following to entries into you sshd.config :

	ClientAliveInterval 15
	ClientAliveCountMax 3

These will cause the ssh daemon to check the client is ok, and so creates a
small amount of traffic to keep the session alive.


=head1 PREREQUISITES

This script requires the C<IO::Handle>, C<IO::Socket> and C<IO::Select> modules.
The C<IO::Socket::SSL> module is also recommended.

=head1 COREQUISITES

none

=head1 AUTHOR

Gavin Brock
http://brock-family.org/gavin

=head1 COPYRIGHT

(C) 2004 Gavin Brock - This script is free software; you can
redistribute it and/or modify it under the same terms as Perl
itself.

=head1 README

This script allows you to tunnel an SSH connection through an SSL (https) web proxy.

=head1 CPAN INFO

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

Web
Networking

=cut

#==============================================================================#
# No user servicable parts below
#

use 5.6.0;
use strict;
use warnings;
use IO::Handle;
use IO::Socket;
use IO::Select;

# Check if we want to use ssl
my $ssl = 0;
if ($ARGV[0] eq "-ssl") { $ssl = 1; shift @ARGV }
eval { use IO::Socket::SSL v0.93 } if $ssl;
die $@ if $@;

# Get remote proxy and remote
die "Usage: $0 (-ssl) PROXY:PORT REMOTE:PORT\n" if (my ($proxy,$remote) = @ARGV) != 2;
print STDERR "ssh2ssl: Connecting to [$remote] via [$proxy]\n";

# Set up file handles
my $pxy  = IO::Socket::INET->new($proxy) || die "ssh2ssl: Can't open proxy: $!";
my $sto  = IO::Handle->new_from_fd(fileno(STDOUT),"w");
my $sti  = IO::Handle->new_from_fd(fileno(STDIN), "r");
my $rsel = IO::Select->new($pxy);
my $wsel = IO::Select->new($pxy);

# Now the clever part. We store the subroutines and buffers in the hash part of
# the glob-ref. This gives it a pseudo-object behaviour.

# Initalise buffers
$$pxy->{'wbuf'} = "CONNECT $remote HTTP/1.0\r\n\r\n";
$$sto->{'wbuf'} = "";

sub finished { die "ssh2ssl: Connection closed.\n"; }

# Callbacks for IO r/w
$$pxy->{'can_write'} = sub {
  my $bw = $pxy->syswrite($$pxy->{'wbuf'},length $$pxy->{'wbuf'});
  substr($$pxy->{'wbuf'},0,$bw,'');
  $wsel->remove($pxy) unless length $$pxy->{'wbuf'};
};

$$sto->{'can_write'} = sub {
  my $bw = $sto->syswrite($$sto->{'wbuf'},length $$sto->{'wbuf'});
  substr($$sto->{'wbuf'},0,$bw,'');
  $wsel->remove($sto) unless length $$sto->{'wbuf'};
};

$$sti->{'can_read'} = sub {
  $sti->sysread($$pxy->{'wbuf'},1024,length $$pxy->{'wbuf'}) || finished;
  $wsel->add($pxy);
};

$$pxy->{'can_read'} = sub {
  $pxy->sysread(my $buf,1024) || finished;
  $buf =~ /^HTTP\/1.\d 2\d\d/ || die "ssh2ssl: Proxy said:\n\n",$buf,"\n";
  IO::Socket::SSL->start_SSL($pxy) if $ssl;
  $rsel->add($sti);
  $$pxy->{'can_read'} = sub { # Redefine for 2nd time
    $pxy->sysread($$sto->{'wbuf'},1024,length $$sto->{'wbuf'}) || finished;
    $wsel->add($sto);
  };
};

# Loop forever
while (my ($r,$w) = IO::Select::select($rsel,$wsel)) {
  foreach my $i (@$r) { $$i->{'can_read'}->()  }
  foreach my $o (@$w) { $$o->{'can_write'}->() }
}

#
# That's all folks...
#==============================================================================#
