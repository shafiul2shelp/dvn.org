#!/usr/bin/perl
# tonnel.cgi (CGI tunnel) v0.001 (c) Dzianis Kahanovich (AKA mahatma), 2007
##############################################################################
# License: Anarchy.
# 
# Âñå ñòèõèéíûå (âêëþ÷àÿ ñîöèàëüíûå (âêëþ÷àÿ þðèäè÷åñêèå, ìîðàëüíûå è ò.ä.))
# àñïåêòû ñóùåñòâîâàíèÿ è èñïîëüçîâàíèÿ äàííîãî êîäà ÿâëÿþòñÿ ôîðñ-ìàæîðíûìè
# îáñòîÿòåëüñòâàìè è àâòîðà íå èíòåðåñóþò.
# 
# Money are welcome.
# 
# (c) mahatma, 29.09.2006
##############################################################################
# command line: [daemon [<n>]|split [client|daemon]]

=head1 NAME

tonnel.cgi - tunnel cgi+daemon for remote cgi execution (for CGIProxy)

=head1 DESCRIPTION

CGI/http reverse tunnel. Mainly used for CGIProxy by James Marshall.

=head1 README

todo.

Command line: [daemon [<n>]|split [client|daemon]]
James Marshall's CGIProxy: http://www.jmarshall.com/tools/cgiproxy/
Tested with CGIProxy 2.1beta15

=head1 PREREQUISITES

Perl 5

=head1 COREQUISITES

Perl 5, Socket, POSIX

=pod OSNAMES

All

=pod SCRIPT CATEGORIES

Networking
Web

=cut

### daemon
### client
my $serve="serve";
my $temp="/var/tmp";
my $dtype="binary/octet-stream";
my $URL="http://mahatma.eu.by/cgi-bin/nph-tunnel.cgi";
my $cgi_proxy="./nph-proxy.cgi";
my $split=64*1024;
my $bufsize=1024;
$|=1;
### /daemon
my $F;
my $pid;
my $ppid;
my $fi="$temp/tonnel.fifo";
my $duplex=1;
### /client

### daemon
$ARGV[0]&&goto "O_$ARGV[0]";
### /daemon

### client
$ENV{QUERY_STRING}=~s/^$serve\=(\-?\d*)$/$pid=abs($ppid=$1)/se;

if(!defined($pid)){
$pid=$$;
$F=openpipe(">$fi");
print $F wrx($pid);
close($F);
$F=openpipe(">$fi.$pid.r");
while(my ($k,$v)=each %ENV){$v=~s/\n/ /gs;print $F "$k: $v\n"}
print $F "\n";
if(exists($ENV{CONTENT_LENGTH})){
 fcopy($ENV{CONTENT_LENGTH},*STDIN,$F);
}else{
 fcopy1(*STDIN,$F);
}
close($F);
wlog("ccc");
NEXT:
fcopy1($F=openpipe("<$fi.$pid.c"),*STDOUT);
close($F);
goto NEXT if(-e "$fi.$pid.r");
unlink("$fi.$pid.c","$fi.$pid.r");
exit;
}elsif(!($pid>0 && $duplex)){ ###
my $pid1;
#if($pid && !fork){close(openpipe(">$fi"));exit}
#PID1:
$F=openpipe("<$fi");
#$pid1=eof($F)?0:rdx($F);
$pid1=rdx($F);
close($F);
#goto PID1 if(!($pid || $pid1));
#if($pid1){
$F=openpipe("<$fi.$pid1.r");
my $s=wrx($pid1).ffread($F);
$l=length($s);
print "Content-Length: $l\nContent-Type: $dtype\n\n$s";
undef $s;
close($F);
$pid||exit;
#}
}

unlink("$fi.$pid.r") if($ppid>0);
$F=openpipe(">$fi.$pid.c",1);
if(exists($ENV{CONTENT_LENGTH})){
 fcopy($ENV{CONTENT_LENGTH},*STDIN,$F);
}else{
 fcopy1(*STDIN,$F);
}
close($F);

sub openpipe{
use POSIX;
my $f;
my $n=$_[0];
my $n1=$n;
$n1=~s/^[\>\<]*//gs;
if(!-e $n1){
 if($_[1]){
  open($f,substr($_[0],0,1)+"/dev/null");
  return $f
 }
 POSIX::mkfifo($n1,0700)||-e $n1 ||err("mkfifo $n1");
}
open($f,$n)||err("open $n");
select($f);$|=1;select(STDOUT);
$f
}

### daemon

exit;

sub err{
for(*STDERR,*STDOUT){print $_ "Content-Type: text/plain\n\n",join("\n","Error:",$!,@_,"")}
wlog("Error:",$!,@_);
die "$!\n";
}

sub fcopy{
my $sz=$_[0];
my ($buf,$n);
while($sz&&!eof($_[1])){
 $sz-=($n=$sz>$bufsize?$bufsize:$sz);
 my $n=read($_[1],$buf='',$n);
 for(2..$#_){syswrite($_[$_],$buf,$n)}
}
1
}

sub fcopy1{
#(*R,*W)=@_;return print W <R>;
my $buf;
while(!eof($_[0])){
 my $n=read($_[0],$buf,$bufsize);
 for(1..$#_){syswrite($_[$_],$buf,$n)}
 undef $buf;
}
1
}

sub ffread{
my $s;
while(!eof($_[0])){
 read($_[0],my $s1,$bufsize);
 $s.=$s1
}
#my $f=$_[0];while(defined(my $s1=<$f>)){$s.=$s1}
$s
}

sub wrx{sprintf("%032d",$_[0])}
sub rdx{read($_[0],my $x,32);$x+0}

sub wlog{
my $L;
open($L,">>$temp/tonnel.log");
print $L join(' ',@_)."\n";
close($L);
}
### /client

###########################################################
O_daemon: &daemon;

sub parsehost{
my ($h,@hh)=@_;
$h=~s/^(.*?)\:\/\//$hh[0]=lc($1);''/se;
$h=~s/^(.*?)(\/.*$)/$hh[3]=$2;$1/se;
$h=~s/^(.*?)(\:.*$)/$hh[2]=substr($2,1);$1/se;
$hh[1]=$h;
@hh
}

sub conn{
use Socket;
my @ad=my @h=parsehost($_[0],'','127.0.0.1','80','/');
my $SO;
#if($proxy){
# @ad=parsehost($proxy,'','127.0.0.1','3128');
# $h[3]=$_[0];
#}
socket($SO,PF_INET,SOCK_STREAM,PROTO_TCP)&&
setsockopt($SO,SOL_SOCKET,SO_SNDTIMEO,pack('LL',30*60,0))&&
setsockopt($SO,SOL_SOCKET,SO_RCVTIMEO,pack('LL',30*60,0))&&
setsockopt($SO,SOL_SOCKET,SO_REUSEADDR,pack("l",1))&&
connect($SO, sockaddr_in($ad[2],inet_aton($ad[1])))&&goto OK;
return;
OK:
select($SO);$|=1;select(STDOUT);
print $SO "POST $h[3] HTTP/1.1\nHost: $h[1]:$h[2]\nUser-Agent: tonnel.cgi\nContent-Length: ".length($_[1])."\nAccept: $dtype\nConnection: close\n\n$_[1]";
$SO
}

sub cgi_proxy{do $cgi_proxy}

sub daemon{
$SIG{CHLD}='IGNORE';
my $xsz=length(wrx(0));

open($F,"<$cgi_proxy")||err("Preloading \"$cgi_proxy\"");
eval("*cgi_proxy=sub\{".ffread($F)."\n\};");
close($F);

print "Daemon\n";
if($ARGV[1]){
 close(STDOUT);
 close(STDIN);
 close(STDERR);
 for(1..$ARGV[1]){($pid=fork)||last}
 $pid&&exit;
}

$pid=0;
my $content;


my $IN;
my $part;

while(1){
my $SO=conn("$URL?$serve=$part$pid",$content)||&err("Connecting");
goto PART if($part);
my %E1=();
my $s=1;
while((!eof($SO)) && $s ne ''){
 $s=<$SO>;
 $s=~s/[\r\n]//gs;
 $s=~s/(.*)\: (.*)[\n\r]*/$E1{uc($1)}=$2;'-'/se;
}

read($SO,$s,$E1{'CONTENT-LENGTH'});
close($SO);
(my $h,$s)=split(/\r*\n\r*\r*\n\r*/,$s,2);
$pid=substr($h,0,$xsz,'')+0;
pipe(STDIN,STDOUT);
pipe($IN,my $OUT);
if(!fork){
 select(*STDOUT=$OUT);
 %ENV=();
 $h.="\n";
 $h=~s/(.*?)\:\s?(.*?)[\n\r]/$ENV{$1}=$2;''/gse;
 undef $h;
 undef $s;
 close($IN);
 #${^TAINT}=1;
 &cgi_proxy;
 close($OUT);
 exit;
}
select STDOUT;
print $s;
close($OUT);
close($REQ);
PART:
undef $content;
read($IN,$content,$split);
if(eof($IN)){
 close($IN);
 undef $part;
}else{
 $part='-';
}
}

exit;
}
### /daemon

O_split:
shift @ARGV;
print splitme(@ARGV);
exit;

sub splitme{;
open($F,"<$0")||&err;
my $s=ffread($F);
my ($s1,$s2);
for (@_){$s=~s/### $_\n(.*?)### \/$_\n/$s1.=$1;''/gse}

my $n=0;
while($s2!=''||($s2=='' && !$n)){
 $s=~s/^(#.*?\n)/$s2.=$1;''/gse;
 $s2.=join(' ','#--- ',@_,"only ---#\n") if(!$n++);
}
$s2.$s1
}
