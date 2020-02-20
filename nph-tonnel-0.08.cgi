#!/usr/bin/perl
# tonnel.cgi (CGI tunnel) v0.08 (c) Dzianis Kahanovich (AKA mahatma), 2007
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
# command line: [daemon [<url> [{<n*>]}]|split [client|daemon]]

=head1 NAME

tonnel.cgi v0.08 - tunnel cgi+daemon for remote cgi execution (for CGIProxy).

=head1 DESCRIPTION

CGI/http reverse tunnel. Mainly used for CGIProxy by James Marshall.

=head1 README

todo.

Using to remote exec of CGIProxy (etc?) and browse CGI from
this daemon+CGIproxy. Using only single-direction requests (daemon->http/cgi).
Mainly written to bypass hoster's firewall, denied outgoing connections,
but may be good solution for HA multichannel browsing.

Daemon command line: [daemon [<url> [{<n*>]}]|split [client|daemon]]
- where n* - threads/connects limits (or 0)
- example:
./nph-tonnel.cgi daemon http://www.yoursite./cgi-bin/nph-tonnel.cgi 20 2 3
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
use Socket;
my $split=32768;
my @timeout=(60,1800,180,180); # connect,init,read,write
my $preresolve=0;
my $cgi_proxy="./nph-proxy.cgi";
#$proxy='socks4a://127.0.0.1:9050';
my (@LIM,@CNT,$MR,$CLW,@MW,@CLR);
### client
my $serve="serve";
my $dtype="binary/octet-stream";
my $URL="http://mahatma.eu.by/cgi-bin/nph-tunnel.cgi";
my $temp="/var/tmp";
my $bufsize=1024;
$|=1;
### /daemon
my $fi="$temp/tonnel.fifo";
my $log="$temp/tonnel.log";
my $duplex=1; # independed for cgi & daemon
my $nph=1;
my $pgrp=1;
my ($F,$pid,$ppid,$wr);
### /client

### daemon
goto 'O_'.shift(@ARGV);
O_:
### /daemon

### client
$ENV{QUERY_STRING}=~s/^$serve\=(\-?\d*)$/$pid=abs($ppid=$1)/se;

if(!defined($pid)){
$pid=$$;
$F=openpipe('>>',$fi);
print($F wrx($pid))||&cgidie;
close($F);
push @ff,"$fi.$pid.r";
$F=openpipe('>',"$fi.$pid.r");
while(my ($k,$v)=each %ENV){$v=~tr/\n/ /;print($F "$k: $v\n")||&cgidie}
print($F "\n")||&cgidie;
if(exists($ENV{CONTENT_LENGTH})){
 fcopy($ENV{CONTENT_LENGTH},*STDIN,$F)||&cgidie;
}else{
 fcopy1(*STDIN,$F)||&cgidie;
}
close($F);
push @ff,"$fi.$pid.c";
NEXT:
fcopy1($F=openpipe('<',"$fi.$pid.c"),*STDOUT)||&cgidie;
close($F);
goto NEXT if(-e "$fi.$pid.r");
&cgiend;
}elsif($duplex?$ppid>=0&&!($wr=fork):!$pid){
my $pid1;
$F=openpipe('<',"$fi");
defined($pid1=rdx($F))||&cgidie;
close($F);
$F=openpipe('<',"$fi.$pid1.r");
my ($l,$l1);
while((my $s1=<$F>) ne "\n"){$s.=$s1;$s1=~s/^CONTENT_LENGTH: (\d*)/$l1=$1/se}
$s=wrx($pid1)."$s\n";
$l=$l1+length($s);
print(($nph?$ENV{SERVER_PROTOCOL}:'Status:')." 200 OK\nContent-Length: $l\nContent-Type: $dtype\n\n$s")||&cgiend;
$wr=0;
undef $s;
fcopy($l,$F,*STDOUT)||&cgidie;
close($F);
&cgiend if($duplex||!$pid);
}

cgiend("$fi.$pid.r","$fi.$pid.c") if(!(defined($wr)||print(($nph?$ENV{SERVER_PROTOCOL}:'Status:')." 200 OK\nContent-Length: 0\nContent-Type: $dtype\n\n"))||($pid && $pgrp && getpgrp($pid)==-1));
unlink("$fi.$pid.r") if($ppid>0);
&cgiend if(!-e "$fi.$pid.c");
$F=openpipe('>',"$fi.$pid.c");
if(exists($ENV{CONTENT_LENGTH})){
 fcopy($ENV{CONTENT_LENGTH},*STDIN,$F)||&cgidie;
}else{
 fcopy1(*STDIN,$F)||&cgidie;
}
close($F);
&cgiend;

sub cgiend{
unlink(@ff,@_);
$wr&&waitpid($wr,0);
exit;
}

sub cgidie{
my $e=shift;
print ($nph?$ENV{SERVER_PROTOCOL}:'Status:')." 500 Internal Server Error\n\n500 Error $e";
cgiend(@_);
}

sub openpipe{
use POSIX qw/mkfifo/;
my $f;
my $n=$_[1];
-e $n||POSIX::mkfifo($n,0700)||-e $n||err("mkfifo $n");
open($f,"$_[0]$n")||err("open $n");
select($f);$|=1;select(STDOUT);
$f
}

sub err{
wlog("Error:",$!,@_);
&cgidie;
}


### daemon

sub fcopy{
my $sz=$_[0];
my ($buf,$n);
for(1..$#_){binmode($_[$_])}
while($sz&&!eof($_[1])){
 $sz-=($n=$sz>$bufsize?$bufsize:$sz);
 defined(my $n=read($_[1],$buf='',$n))||return;
 for(2..$#_){defined(syswrite($_[$_],$buf,$n))||return}
}
1
}

sub fcopy1{
my $buf;
for(@_){binmode($_)}
while(!eof($_[0])){
 defined(my $n=read($_[0],$buf,$bufsize))||return;
 for(1..$#_){defined(syswrite($_[$_],$buf,$n))||return}
 undef $buf;
}
1
}

sub ffread{
my $s;
binmode($_[0]);
while(!eof($_[0])){
 defined(read($_[0],my $s1,$bufsize))||return;
 $s.=$s1
}
$s
}

sub wrx{sprintf("%032d",$_[0])}
sub rdx{defined(read($_[0],my $x,32))||return;$x eq ''?undef:$x+0}

sub wlog{
$log||return;
my $L;
open($L,">>$log");
print $L join(' ',@_)."\n";
close($L);
}
### /client

###########################################################
O_daemon:
$URL=shift(@ARGV)||$URL;
&daemon(@ARGV);

sub parsehost{
my ($h,@hh)=@_;
$h=~s/^(.*?)\:\/\//$hh[0]=lc($1);''/se;
$h=~s/^(.*?)(\/.*$)/$hh[3]=$2;$1/se;
$h=~s/^(.*?)(\:.*$)/$hh[2]=substr($2,1);$1/se;
$hh[4]=sockaddr_in($hh[2],$hh[5]=inet_aton($hh[1])) if($preresolve);
$hh[1]=$h;
@hh
}

sub cgi_proxy{do $cgi_proxy}

sub timeouts{
setsockopt($_[0],SOL_SOCKET,SO_RCVTIMEO,pack('LL',$_[1],0))&&
setsockopt($_[0],SOL_SOCKET,SO_SNDTIMEO,pack('LL',$_[2],0))
}

sub CNT{
defined($LIM[$_[0]])||return;
my $x;
(print($CLW wrx(($_[0]<<1)+($_[1]>0))) &&
defined($x=rdx($CLR[($_[1]>0)+0])))
||($_[1]<0 && exit);
$x
}

sub ex{
for(0..$_[0]){CNT($_,-1)}
for($MR,$CLW,@MW,@CLR){close($_)}
exit
}

sub daemon{
$SIG{CHLD}='IGNORE';
my $s;
my $xsz=length(wrx(0));

open($F,"<$cgi_proxy")||die("Preloading \"$cgi_proxy\"");
eval("*cgi_proxy=sub\{".ffread($F)."\n\};");
close($F);

if($#_!=-1){
 fork&&exit;
 print "$$\n";
 close(STDOUT);close(STDIN);close(STDERR);
}
pipe($MR,$CLW);select($CLW);$|=1;
for(0,1){pipe($CLR[$_],$MW[$_]);select($MW[$_]);$|=1}
select(STDOUT);
my $i;
my @prox=$proxy?parsehost($proxy,'http','127.0.0.1','3128'):();
$prox[0]=lc($prox[0]);
my $hprox=$prox[0] eq 'http'?"\nCache-Control: no-cache\nPragma: no-cache":'';
my @ad=my @h=parsehost($URL,'http','127.0.0.1','80','/');
if($proxy){
 @ad=@prox;
 $h[3]=$url if($prox[0] eq "http");
}

$LIM[0]=0;
for(0..$#_){$_&&($LIM[$_]=$_[$_])}
while(1){
  if(!$CNT[0]){$CNT[0]++;fork||goto CONN}
  my $w=$MW[my $x=($i=rdx($MR))&1];
  $i>>=1;
  if($x){
   $CNT[$i]++;
   $x=$LIM&&$CNT[$i]>$LIM[$i];
  }else{
   $CNT[$i]&&$CNT[$i]--;
   if($x=!$CNT[$i]){
    for(0..$#LIM){if($LIM[$_]&&$CNT[$_]>=$LIM[$_]){$x=0;last}}
    if($x){$CNT[0]++;fork||goto CONN}
   }
  }
  print $w wrx($x+0);
}
CONN:

$pid=0;
my ($header,$content,$IN,$part,$SO,$len,$WR,$WW,$wpid);

if($duplex){
 pipe($WR,$WW);
 select($WW);$|=1;select(STDOUT);
}

CONN1:
if($wpid){
 undef $wpid;
 rdx($WR);
}
close($SO);
if(!$part){for(1..$#LIM){ex($_) if(CNT($_,1)&&!$pid)}}
(socket($SO,PF_INET,SOCK_STREAM,PROTO_TCP)&&
timeouts($SO,$timeout[0],$timeout[0])&&
setsockopt($SO,SOL_SOCKET,SO_REUSEADDR,pack("l",1))) ||ex($#LIM);
select(undef,undef,undef,3) until(connect($SO,defined($ad[4])?$ad[4]:sockaddr_in($ad[2],inet_aton($ad[1]))));
select($SO);$|=1;select(STDOUT);
if($prox[0] eq "socks4a"){
 binmode($SO);
 (print($SO pack("CCnCCCCZ*Z*",4,1,$h[2],0,0,0,1,"T$pid","$h[1]"))&&
 read($SO,$s,8)&&
 substr($s,1,1) eq chr(0x5a))||goto CONN1
}

timeouts($SO,$timeout[1],$timeout[1]);
$part||CNT(1,-1);
if($part||!($duplex && ($wpid=fork))){
 print($SO "POST $h[3]?$serve=$part$pid HTTP/1.1\nHost: $h[1]:$h[2]\nUser-Agent: tonnel.cgi\nContent-Length: ".(length($header)+length($content)+$len)."\nAccept: $dtype\nConnection: close$hprox\n\n$header$content")||goto EX1;
 if(defined($len)){
  fcopy($len,$IN,$SO)||goto EX1;
  close($IN);
 }
 if(defined($wpid)){
 EX1:
  defined($wpid)||goto CONN1;
  close($SO);
  print $WW wrx($$) if(defined($WW));
  exit;
 }
}
undef $header;
undef $content;
my %E1=();
$s=<$SO>.'x';
$s=~s/^HTTP\/\d+\.\d+\s+(\d+)\s+.*$/$1/s;
undef $s if($s ne '200');
CONN2:if(!defined($s)){$part||CNT(2,-1);goto CONN1}
timeouts($SO,$timeout[2],$timeout[3]);
while(!eof($SO) && $s ne ''){
 defined($s=<$SO>)||goto CONN2;
 $s=~s/[\r\n]//gs;
 $s=~s/^(.*?)\: (.*)$/$E1{uc($1)}=$2;'-'/se;
}
goto PART if($part);
CNT(2,-1);
$s=1;
$pid=rdx($SO);
my $n=$ndx;
%ENV=();
while(!eof($SO) && $s ne ''){
 defined($s=<$SO>)||goto CONN1;
 $n+=length($s);
 $s=~s/[\r\n]//gs;
 $s=~s/^(.*?)\: (.*)$/$ENV{$1}=$2;'-'/se;
}
$part||CNT(3,-1);
close($IN);
pipe($IN,my $OUT);
if(!fork){
 *STDIN=$SO;
 select(*STDOUT=$OUT);
 $|=1;
 close($IN);
 $0=$ENV{SCRIPT_NAME};
 #${^TAINT}=1;
 &cgi_proxy;
 close($SO);
 close($OUT);
 exit;
}
close($OUT);
close($REQ);
undef $len;
undef $part;
$s=1;
while(!eof($IN) && $s ne ''){
 defined($s=<$IN>)||goto PART;
 $header.=$s;
 $s=~s/[\r\n]//gs;
 $s=~s/^content-length\: (.*)$/$len=$1/sei;
}
goto CONN1 if(defined($len));
binmode($IN);
PART:
if(!defined(read($IN,$content,$split))||eof($IN)){
 close($IN);
 undef $part;
}else{
 $part='-';
}
goto CONN1;
}
### /daemon

O_split:
print splitme(@ARGV);

sub splitme{;
open($F,"<$0")||&err;
my $s=ffread($F);
my ($s1,$s2,$ss);
for (@_){$s=~s/### $_\n(.*?)### \/$_\n/$s1.=$1;''/gse}

my $n=0;
while($ss ne ''||($ss eq '' && !$n)){
 $ss='';
 $s=~s/^(#.*?\n)/$s2.=($ss=$1);''/gse;
 $s2.=join(' ','#--- ',@_,"only ---#\n") if(!$n++);
}
$s2.$s1
}

