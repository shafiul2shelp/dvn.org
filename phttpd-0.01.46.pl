#!/usr/bin/perl
# karakurt - pure perl httpd v0.01.46 (c) mahatma, GPLs

=head1 NAME

phttpd-0.01.46.pl - karakurt, small pure Perl httpd ([x]inetd or standalone).

=head1 DESCRIPTION

Small pure Perl httpd, only Perl CGI, faster Perl CGI execution.
Nice for configuration/single Perl CGI purposes.

=head1 README

karakurt, pure Perl httpd v0.01.46           (c) Dzianis Kahanovich, GPLs

This software are with NO WARRANTY!

I wrote it becouse I needs for small, fast, all-in-one httpd/perl, main -
in xinetd. There are my first server sockets programming (daemon/standalone),
then standalone mode are totally experemental, but caching modes are much more
experemental and unsecure and unsafe. Use it only for debugged, verifyed
scripts set. Also eXtreme mode must be not used with wildcard redirections:
every new URI will creating new cache entry. For real tasks even non-cached
mode are fast as perl "eval" method. But if you have commercial ;) heavy-loaded
perl-only site and if my daemon/forking model satisfy you (heh) - you may
trying eXtreme mode. But all software are with NO WARRANTY and all
PROBLEMS ARE YOUR OWN RISC!!

Configuration:
Look to $map variable and comments. There are regular expression/substitution.
Also try suexec file mode bits. I think, with mind you may build good security
for YOUR site (I not think that may be used in multi-user mode, but may be yes,
may be no - I trying to care for minimal security in non-cached mode, but not
believe in this).

Virtual hosts: use $ENV{'HTTP_HOST'} in $map target.

Do not put "tar" into %mime - you will get auto-ungzipping in your browser
(encoding). I experienced about "binary/unknown" are good content-type for
all binary downloads and real situations.

Also: all CGI scripts running via "eval", Perl commandline options are
emulated very relaxed.

May be easy added cool features in daemon (transparent compressing, etc), but
with price of unsimplifying code. Now it is minimal and functional and primary
will be used (by me) in LAN & localhost.

Keep-alive are off by default. Use it with "-t" option only. Mode 2&3 may cause
problems with pipelining, but I am not sure. Mode 3 may be violated by bad
CGI/Content-length. Mode 4 are slow and experemental (unknown Content-length
are buffered). Mode 5 using internally (totally buffered).

"X" and "x" caching on/off in commandline give various multitasking and
security. If "on" - precompile "eval" will work in main process, then fork -
there are slow and unsecure. If "off", but "on" in $map - caching will be
only per-keep-alive (if enabled), but scripts will separated by user:group,
then user may violate only own site.

Commandline examples:
Good server: "--a :80 --m 2 --x --k 3 --t 1"
Secure & light: "--a :80 --m 1 --y --d --t 3"
Secure fast server: "--a :80 --m 5 --y --d --k 3 --t 10 -t1 300" + "x" in $map

Run w/o options for help.

Changes:
0.01.18 - bugfixes, caching now work, keep-alive.
0.01.19 - bugfixes, keep-alive off by default.
0.01.21 - bugfixes... changed command format.
0.01.22 - caching changed (secure per-keep-alive possible).
0.01.24 - security fix.
0.01.25 - fixes, IO.
0.01.26 - repaired "--i", timeouts.
0.01.27 - I/O fixed.
0.01.32 - fixes, log, %map.
0.01.34 - HEAD fix.
0.01.35 - ~ fork modes, log, $map +threads.
0.01.38 - chunked (1.1 ondemand), close+reload on security error, bugfix.
0.01.39 - simple WebDAV RO.
0.01.43 - range bug, "--maxwbuf".
0.01.44 - config loading for preload.
0.01.45 - ipv6, misc fixes.
0.01.46 - rollback experimental.

=head1 PREREQUISITES

Perl 5

=head1 COREQUISITES

Perl 5, no modules.

=pod OSNAMES

All

=pod SCRIPT CATEGORIES

Networking
Web

=cut

{
package phttpd;
sub xeval{eval $_[0]};

my $map=[sub{"$ENV{REMOTE_ADDR},$ENV{SERVER_ADDR}"},[
# ['127\.0\.0\.1\,127\.0\.0\.1','ph-setup.cgi'],
 ['..*',[sub{$_[0]},[
  ['\.\.',sub{"404"}],
#  ['/usr/portage/distfiles/.*',sub{"gcache-0.01.cgi",{'x'=>1}}],
#  ['/usr/portage/(.*)',sub{"/usr/portage/$1",{'nocgi'=>1}}],
#  ['/~(.*?)(/.*)',sub{"/home/$1/public_html$2",{'user'=>$1,'group'=>'users'}}],
#  ['/(.*)',sub{"$ENV{'DOCUMENT_ROOT'}/$1",{'x'=>1}}],
  ['/(.*)',sub{"html/$1"}],
  ['..*','404',{'x'=>1}]
 ]]]
]];

sub translate{
my ($x1,$x2)=@{$_[0]};
$x1=&$x1($_[1]) if(ref($x1) eq 'CODE');
for(@{$x2}){
 my ($y1,$y2)=@$_;
 my $x=$x1;
 $y1=&$y1($_[1]) if(ref($y1) eq 'CODE');
 $x=~s/$y1//;
 $x1=~s/$y1/return ($x=ref($y2)) eq 'ARRAY'?translate($y2,$_[1]):$x eq 'CODE'?&$y2($_[1]):@$_[1,2]/e if($x eq '')
}
}

sub _read{
 open(my $F,$_[0])||return;
 my $s;
 if(my $l=$_[1]||-s $F){
  read($F,$s,$l);
 }else{
  while(defined(my $x=<$F>)){$s.=$x};
 }
 close($F);
 $s;
}

# 'Host' => sub{}, may be used for clustering
my %domain=(
# 'www.domain.com'=>sub{cluster('.domain.com')},
 ''=>sub{1,"Status: 400\n\nerror"} # rfc
);

# single-host cluster (no vhosting)
# remember first used IP in cookie and redirect here later
sub cluster{
my $cookie="karakurtCluster";
my $ip=$ENV{'SERVER_ADDR'};
my $l=length($cookie)+1;
my $h;
for(split(/;[ ]*/,$ENV{'HTTP_COOKIE'})){$h=substr($_,$l) if(substr($_,0,$l) eq "$cookie=")}
return if($ip eq $h);
return 1,"Status: 300\nLocation: http://$h$ENV{REQUEST_URI}\n\n" if($h);
0,$l="Set-cookie: $cookie=$ip".($_[0]?"; domain=$_[0]":'')."\n"
}

my (%OPTIONS,@RANGE,@errors,$ERROR,$CHUNKED,$mainpid,$SERVER,$IN,$OUT,$vec_in,$vec_out,$rbufsize,$wbufsize,$maxwbufsize,$filebuf,$log,$a);
my $tid='';
# RANGE: 0-1 2=keep-alive 3=range requested 4=range proceed('2'=break) 5=break
#  6-done 7-timeout 8-timeout/r 9-timeout/w 10-timeout/init
#  11-timeout/read/var 12-buf/limit

my %rfc2068_status=(
100=>'Continue',
101=>'Switching Protocols',
200=>'OK',
201=>'Created',
202=>'Accepted',
203=>'Non-Authoritative Information',
204=>'No Content',
205=>'Reset Content',
206=>'Partial Content',
	207=>'Multi-Status',
300=>'Multiple Choices',
301=>'Moved Permanently',
302=>'Moved Temporarily',
303=>'See Other',
304=>'Not Modified',
305=>'Use Proxy',
400=>'Bad Request',
401=>'Unauthorized',
402=>'Payment Required',
403=>'Forbidden',
404=>'Not Found',
405=>'Method Not Allowed',
406=>'Not Acceptable',
407=>'Proxy Authentication Required',
408=>'Request Time-out',
409=>'Conflict',
410=>'Gone',
411=>'Length Required',
412=>'Precondition Failed',
413=>'Request Entity Too Large',
414=>'Request-URI Too Large',
415=>'Unsupported Media Type',
500=>'Internal Server Error',
501=>'Not Implemented',
502=>'Bad Gateway',
503=>'Service Unavailable',
504=>'Gateway Time-out',
505=>'HTTP Version not supported'
);

my ($rpos,$pos,$buf);
my ($MSG_PEEK,$MSG_DONTWAIT,$PF_INET,$PF_INET6,$SOCK_STREAM,$PROTO_TCP,$SOL_SOCKET,$SO_REUSEADDR,$SOMAXCONN,$SO_ERROR,$SO_SNDBUF,$SO_RCVBUF,$INADDR_ANY,$IN6ADDR_ANY,$SO_LINGER,$SO_KEEPALIVE)=(2,64,2,10,1,6,1,2,512,4,7,8,pack('x4'),pack('x16'),13,9);

my $ID='karakurt/0.01.46';

%ENV=(
'PATH'=>$ENV{'PATH'},
#'REMOTE_ADDR'=>$ENV{'REMOTE_HOST'},
'DOCUMENT_ROOT'=>substr($0,0,rindex($0,'/')),
'GATEWAY_INTERFACE'=>'CGI/1.1',
'SERVER_PROTOCOL'=>'HTTP/1.0',
'SERVER_SOFTWARE'=>"$ID perl/$] $^O",
'SERVER_SIGNATURE'=>"<ADDRESS>$ID</ADDRESS>\n"
);

my %mime=(
'html'=>'text/html',
'htm'=>'text/html',
'js'=>'text/javascript',
'gif'=>'image/gif',
'jpg'=>'image/jpeg',
'gz'=>'application/x-gzip',
'xml'=>'application/xml'
);

my %mime_enc=( # to prevent "content-encoding" just remove real type from mime
'gz'=>'gzip'
);

my %opt=(
 '0'=>sub{"\$\/=".oct($_[0])},
 'C'=>sub{'${^WIDE_SYSTEM_CALLS}=1'},
 'e'=>sub{"eval(\"$_[0]\")"},
 'i'=>sub{"\$\^I=\"$_[0]\""},
 'I'=>sub{'push @INC,\"'.$_[0].'"'},
 't'=>sub{'${^TAINT}=1'}, #warn
 'T'=>sub{'${^TAINT}=1'}, #fatal
 'W'=>sub{'$^W=1'},
 'X'=>sub{'$^W=0'}
);

my %methods=('GET'=>1,'POST'=>1,'HEAD'=>2, 'OPTIONS'=>2, 'PROPFIND'=>1);

sub httpd{

if(defined($_[0])){
 $tid=threads->self;
 $tid->detach;
 $tid=$tid->tid.".";
 *ex=*_end;
 goto "TH$_[0]";
}

my ($content,%contents,%URIs,@guid,%options,$conf);
my @saveguid=($>,$));

for(@ARGV){
 if(substr($_,0,2) eq '--'){$OPTIONS{$content=substr($_,2)}=''}
 else{$OPTIONS{$content}.=$OPTIONS{$content}?" $_":$_}
}
chdir($ENV{'DOCUMENT_ROOT'});
eval _read($OPTIONS{'c'}) if($conf=-M $OPTIONS{'c'});

eval q(
 use threads;
 $tid=".";
 *xfork=sub {"$tid$$" eq $mainpid||return;threads->new(\&httpd,@_)->detach;1}
) if(exists($OPTIONS{'th'}));

&socklib if(exists($OPTIONS{'l'})||exists($OPTIONS{'6'}));
if(exists($OPTIONS{'L'})){
 open $log,">>$OPTIONS{'L'}";
 select($log); $|=1; select(STDOUT);
}
if(exists($OPTIONS{'a'})){
my @ad=split(/:/,$OPTIONS{'a'},3);
for(0,\&socklib){
 $_&&&$_;
 socket($SERVER,$PF_INET,$SOCK_STREAM,$PROTO_TCP)&&
 setsockopt($SERVER,$SOL_SOCKET,$SO_REUSEADDR,pack('l',1))&&
 (defined($OPTIONS{'tw'})?setsockopt($SERVER,$SOL_SOCKET,$SO_LINGER,pack('LL',1,$OPTIONS{'tw'})):1)&&
 bind($SERVER, sockaddr_in($ad[1]||591,$ad[0]?inet_aton($ad[0]):$INADDR_ANY))&&
 listen($SERVER,$ad[2]||$SOMAXCONN)&&
 goto SERV_OK
}
die "Socket open error: $!\n";
SERV_OK:
sockinit($SERVER);
close(STDERR);
close(STDOUT);
close(STDIN);
exists($OPTIONS{'d'})&&fork&&exit;
preforker($OPTIONS{'z'});
fork||last for(2..$OPTIONS{'m'});
DAEMON:
($>,$))=@saveguid;
$SIG{CHLD}='IGNORE';
while(1){
 close($IN);
 $mainpid||="$tid$$";
 $a=accept($IN,$SERVER) or die;
 if(exists($OPTIONS{'c'})&&$conf!=(my $x=-M $OPTIONS{'c'})){$conf=$x;eval _read($OPTIONS{'c'})}
 last if(exists($OPTIONS{'x'})||exists($OPTIONS{'X'})||!&xfork(0))
}
TH0:
$OUT=$IN
}elsif(exists($OPTIONS{'i'})){
 $OUT=*STDOUT;
 $a=getpeername($IN=*STDIN);
 sockinit($IN)
}else{
 exit print qq($ID pure Perl httpd, (c) Dzianis Kahanovich, 2005-2010, GPLs
--i - [x]inetd mode (main goal, safe)
--a [addr][:port[:queue]] - bind to|":591:512"
--H - break CGI (HEAD|range)
--c [file] - load config
--k [n] - keep-alive 0-5: none|HTTP/1.0|smart|smart+CGI|smart+buff|buff_CGI
--x - cache CGI (SCRIPT_FILENAME -> precompile)
--X - eXtreme cache CGI (SCRIPT_NAME -> SCRIPT_FILENAME)
--t|t0|t1|tw|tr [n] - timeouts (default|start|alive|write|read)
--rbuf|wbuf [n] - buffers size
--maxwbuf [n] - enable auto-shrink wbuf
--l large code (may be safe)
--L [file] - log to
--nocgi - disable CGI
--b [n] - buffer limit (CGI_buff & request, average)
Standalone:
--m [n] - listeners|1
--y - inversed fork
--d - detach
--z [n] - fixed prefork
--th - use threads (heavy experemental)
--6 - ipv6
(only Perl CGI supported)
)
}
($ENV{'REMOTE_PORT'},$a)=sockaddr_in($a);
$ENV{'REMOTE_ADDR'}=inet_ntoa($a);
($ENV{'SERVER_PORT'},$a)=sockaddr_in(getsockname($IN));
$ENV{'SERVER_ADDR'}=inet_ntoa($a);
vec($vec_in='',fileno($IN),1)=1;
$vec_out=$vec_in;
#vec($vec_out='',fileno($OUT),1)=1;
$filebuf=$wbufsize>>1;
$RANGE[10]=$OPTIONS{'t0'};
tie(*STDIN,'phttpd');
tie(*STDERR=*STDOUT,'phttpd');
my %ENV0=%ENV;
ALIVE:
%ENV=%ENV0;
my ($mode,$file,@stat,@err)=(0);
%options=%OPTIONS;
@RANGE=('','',$OPTIONS{'k'},0,0,0,0,$OPTIONS{'t'},$OPTIONS{'tr'},$OPTIONS{'tw'},$OPTIONS{'t1'},$RANGE[10],$OPTIONS{'b'},0);
for(8..11){$RANGE[$_]||=$RANGE[7]}
($rpos,$pos,$buf)=(0,0,'');
my @request=split(/[ \n\r]+/,<STDIN>,4);
@RANGE[11,13]=@RANGE[8,12];
$ENV{'SERVER_PROTOCOL'}=substr($content=$request[2],5,5,'')<1.1||$RANGE[2]==1?'HTTP/1.0':'HTTP/1.1';
if($content ne 'HTTP/'){@err=(400,$request[2]);goto ERR}
if(!$methods{$ENV{'REQUEST_METHOD'}=$request[0]}){@err=(405,$request[0]);goto ERR}
($file,$ENV{'QUERY_STRING'})=(split(/\?/,$file=$ENV{'REQUEST_URI'}=$request[1],2),'');
for(my $s=<STDIN>;defined($s) && $s ne "\n" && $s ne "\r\n";$s=<STDIN>){$s=~s/(.*?)\: (.*?)[\r\n]/my $x=$1;$x=~tr\/-a-z\/_A-Z\/;$ENV{substr($x,0,7) eq 'CONTENT'?$x:"HTTP_$x"}=$2/ge}
if($_=$domain{"$ENV{'HTTP_HOST'}"}){
 @err=&$_;
 $content=$err[1];
 goto STD if($err[0]);
 print $content
}
$RANGE[12]=0;
$RANGE[3]=~s/bytes\=([0-9]*)-([0-9]*)/@RANGE[0,1]=($1,$2);1/gse if($RANGE[3]=$ENV{'HTTP_RANGE'});
$file="/$file" if(substr($file,0,1) ne '/');
$file.="\n";
$file=~s/(\/.*?)\/\.\.([\/\n])/$1$2/g;
chomp($file);
$ENV{'REDIRECT_URI'}=$ENV{'SCRIPT_NAME'}=$file||='/';
goto (MAP_OK,EXEC_CGI)[$mode=((($content,@stat)=@{$contents{$file=$content}})!=0)] if(($content,@guid)=@{$URIs{$file}});
my $u;
($file,$u)=translate($map,$file);
goto E404 if(!defined($file));
while(my ($k,$v)=each %$u){if($v eq '!'){delete($options{$k})}else{$options{$k}=$v}}
for(0,1){defined($guid[$_]=defined($u=$options{('user','group')[$_]})&&$u ne ''?$u+0 eq $u?$u:$_?getgrnam($u):getpwnam($u):-1)||goto ESEC};
MAP_OK:
 if($guid[1]!=-1){
  $)="$guid[1] $guid[1]";
  if($) ne "$guid[1] $guid[1]"){
  ESEC:
   wlog('Security->reload');
   $RANGE[2]=0;
   $content="Status: 302\nLocation: $ENV{'REQUEST_URI'}\n\nSecurity error, close/reload.";
   goto STD;
  ESEC2:
   $RANGE[2]=0;
   @err=(500,"Security error");
   goto ERR
  }
 }
 if($guid[0]!=-1){
  $>=$guid[0];
  goto ESEC if($> ne $guid[0]);
 }
 @stat=stat($file);
 if(-d _){
  &xfork(1) && goto DAEMON; TH1:
  my $s=$ENV{'REQUEST_URI'};
  if(substr($s,-1) ne '/'){
   print "Status: 301\nLocation: $s/\n\n";
   goto &ex
  }
  opendir FH,$file or goto ERR;
  if($ENV{'REQUEST_METHOD'} eq 'PROPFIND'){
   # todo: chunked input
   my ($i,$j);
   for($i=$ENV{'CONTENT_LENGTH'}; $i>0; $i-=$j){
    $j=read(STDIN,$s,$filebuf<$i?$filebuf:$i) || last;
   }
   $RANGE[2]=0 if($RANGE[2]<4); # davfs2 chunked bug?
   $s= "Status: 207\nContent-type: text/xml\nLast-Modified: ".gmtime($stat[9]).'

<?xml version="1.0" encoding="utf-8" ?><D:multistatus xmlns:D="DAV:">';
   for(readdir(FH)){
    my @st=stat("$file$_");
    $_=~s/([\x00-\x1f,:\"\'\\])/sprintf('%%%02X',ord($1))/eg;
    $s.=qq(<D:response xmlns:lp1="DAV:"><D:href>$_</D:href><D:propstat><D:prop>
	<lp1:resourcetype).((-d _)?'><D:collection/></lp1:resourcetype>':'/>').'
	<D:getlastmodified>'.gmtime($st[9])."</D:getlastmodified>
	<D:getcontentlength>$st[7]</D:getcontentlength>
</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>
";
    if(length($s)>$filebuf){
     print $s or goto ERR;$s='';
     last if($RANGE[1]==-1)
    }
   }
   close FH;
   print $s.'</D:multistatus>' or goto ERR;
  }else{
  $s="Index of $s";
  $s="Last-Modified: ".gmtime($stat[9])."\nContent-type: text/html\n\n<html><head><title>$s</title></head><body><H1>$s</H1><pre><hr><pre>";
  for(readdir(FH)){
   my @st=stat("$file$_");
   $_=~s/([\x00-\x1f,:\"\'\\])/sprintf('%%%02X',ord($1))/eg;
   $_.='/' if(-d _);
   $s.="<a href='$_'>$_</a>		".localtime($st[9])."	$st[7]\n";
   if(length($s)>$filebuf){
    print $s or goto ERR;$s='';
    last if($RANGE[1]==-1)
   }
  }
  close FH;
  print "$s</pre><hr>$ENV{'SERVER_SIGNATURE'}</body></html>" or goto ERR;
  }
  wlog('dir')
 }elsif(-x _ &&!exists($options{'nocgi'})){
  if(($content,my @s)=@{$contents{$file}}){
   goto EXEC_CGI if($mode=($stat[9]==$s[9]));
   delete($contents{$file})
  }
  open FH,"<$file" or goto ERR;
  read(FH,$content,$stat[7]) or goto ERR;
  close FH;
  $content=~s/#\![ 	]*(.*?)\n/my $x;for(split(\/[ 	]\/,$1)){if(substr($_,0,1) eq '-' && defined(my $o=$opt{substr($_,1,1)})){$x.=&$o(quotemeta(substr($_,2))).';'}};"$x\n"/gse if(substr($content,0,2) eq '#!');  
  $URIs{$ENV{'SCRIPT_NAME'}}=[$file,@guid] if(exists($options{'X'}));
  $contents{$file}=[$content=xeval("sub \{ $content\n\};"),@stat] if(($mode=exists($options{'x'})&&(exists($OPTIONS{'x'})||2))==1);
 EXEC_CGI:
  &xfork(2) && goto DAEMON; TH2:
  wlog('CGI');
  for(\&CGI::initialize_globals){defined(&$_)&&&$_}
  $guid[1]=$stat[5] if($stat[2]&02000);
  $guid[0]=$stat[4] if($stat[2]&04000);
  chown @guid,$out;
  close($SERVER);
  $saveguid[1]=$(=$)="$guid[1] $guid[1]" if($guid[1]!=-1);
  $saveguid[0]=$<=$>=$guid[0] if($guid[0]!=-1);
  $RANGE[5]=exists($options{'H'});
  $RANGE[2]=0 if($RANGE[2]<3);
  @ARGV=();
  $0=$PROGRAM_NAME=$ENV{'SCRIPT_FILENAME'}=$file;
  $contents{$file}=[$content=xeval("sub \{ $content\n\};"),@stat] if($mode==2);
  die $@ if($@);
  return $mode,$content if($RANGE[2]<3&&!$tid); # ?
  $mode?&$content:xeval($content);
  $^W=0;
  die $@ if($@);
 }elsif(-e _){
  &xfork(3) && goto DAEMON; TH3:
  open FH,"<$file" or goto ERR;
  $RANGE[2]=3 if($RANGE[2]>3);
  my $l=$stat[7];
  my $h="Last-Modified: ".gmtime($stat[9])."\nContent-Length: $l\n";
  my @x=(split(/\./,$file))[-1,-2];
  my ($t,$enc,$n);
  read(FH,$content,$n=$l<1024?$l:1024) or goto ERR;
  if(substr($content,0,14) eq '<!DOCTYPE html'){
   $t='text/html'
  }elsif(($enc=$mime_enc{$x[0]}) && substr(",$ENV{'HTTP_ACCEPT_ENCODING'},",",$enc,")>=0 && ($t=$mime{$x[1]})){
   $h.="Content-encoding: $enc\n"
  }
  if($RANGE[3]){
   seek(FH,$pos,0) or goto ERR if($pos=$RANGE[0]);
   $n=length($content=substr($content,$pos,$RANGE[1] ne ''?($l=$RANGE[1]+1-$pos):($l-=$pos)))
  }
  $t||=$mime{$x[0]}||(-B _?'binary/unknown':'text/plain');
  $h.="Content-type: $t\n\n";
  print $h,$content or goto ERR;
  if($RANGE[1]!=-1){
   while($l-=$n){
    read(FH,$content,$n=$l<$filebuf?$l:$filebuf) or goto ERR;
    print_($content) or goto ERR
   }
  }
  close FH;
  wlog('file');
 }else{
E404:
  @err=(404,$file);
ERR:
  wlog('ERROR:',@err);
  if(!$err[1]){
   &xfork(4) && goto DAEMON; TH4:
   die " \n"
  }
  $content="Status: $err[0]\n\n$err[0] $rfc2068_status{$err[0]}: '$err[1]'";
STD:
  &xfork(5) && goto DAEMON; TH5:
  @RANGE[3,6]=(0,1);
  print $content
 }
 print_("0\n\n") if($CHUNKED);
 if($RANGE[2]==5){
  $RANGE[6]=1;
  print ''
 }
 goto &ex if(!$RANGE[2]);
 $OPTIONS{'t'}=abs($RANGE[10]) if($OPTIONS{'t'}>abs($RANGE[10]));
 ($>,$))=@saveguid;
 goto (ALIVE,ESEC)[$> ne $saveguid[0] || $) ne $saveguid[1]]
}

sub TIEHANDLE{bless({})}

sub SEEK{
 $rpos=$pos=0 if(!$_[2]);
 $buf='' if(!($rpos=$pos+=$_[1]))
}

sub PRINT{
shift;
my ($b,$l,$ll,$n,$h0);
if($RANGE[2]==5){
 if((!$RANGE[6])&&!($RANGE[13]&&length($buf)>$RANGE[13])){
  $buf.=join('',@_);
  return 1
 }
 $RANGE[2]=3
}
if($RANGE[4]){$ll=length($b=join('',@_))}
else{
($buf,$b)=split(/[\r]*\n[\r]*\n[\r]*/,join('',$buf,@_),2);
if(defined($b)){
 $ll=length($b);
 if($RANGE[2]){
  $l=lc($ENV{'HTTP_CONNECTION'}||'');
  $h0=$ENV{'SERVER_PROTOCOL'} lt 'HTTP/1.1';
  $RANGE[2]=0 if($l eq 'close'||($h0&&$l ne 'keep-alive'));
 }
 my %hh=('Content-type'=>'text/html','Status'=>200,'Server'=>$ENV{'SERVER_SOFTWARE'},'Date'=>''.gmtime($time=time));
 $_=~s/(.*?)\:[ 	]+(.*)[\r]*/$hh{ucfirst(lc($1))}=$2/e for(split(/\n/,$buf));
 if($ENV{'REQUEST_METHOD'} eq 'OPTIONS'){
  $l=$hh{'Content-length'}=0;
  $hh{'DAV'}=1;
 }elsif(exists($hh{'Content-length'})){
  $l=$hh{'Content-length'}
 }elsif($RANGE[6]){
  $hh{'Content-length'}=$l=$ll
 }elsif($RANGE[2]==4){
   $buf.="\n\n$b";
   $RANGE[2]=5;
   return 1
 }else{
  $RANGE[2]=0 if($h0);
  $l='*'
 }
 if(lc($hh{'Connection'}||=$RANGE[2]?'keep-alive':'close') eq 'close'){
  $RANGE[2]=0
 }elsif($RANGE[10] && (my $x=$ENV{'HTTP_KEEP_ALIVE'})){
  if($RANGE[10]>$x){$RANGE[10]=$x}
  elsif($RANGE[10]!=$x){$hh{'Keep-alive'}||="timeout=$RANGE[10]"}
 } 
 if($RANGE[3] && !exists($hh{'Content-range'})){
  $RANGE[4]=$RANGE[5]+1;
  $hh{'Content-length'}=(($l<=$RANGE[1]||$RANGE[1] eq '')?$RANGE[1]=$l-1:$RANGE[1])+1-$RANGE[0] if($l ne '*');
  $hh{'Content-range'}="bytes $RANGE[0]-$RANGE[1]/$l";
  $hh{'Status'}=206
 }
 if($CHUNKED=($RANGE[2]&&!exists($hh{'Content-length'}))){
  if(exists($hh{'Transfer-encoding'})){
   $hh{'Transfer-encoding'}.=',chunked'
  }else{
   $hh{'Transfer-encoding'}='chunked'
  }
 }
 $buf=delete($hh{'Status'});
 $buf="$ENV{'SERVER_PROTOCOL'} $buf $rfc2068_status{$buf}\n";
# $buf.="$_: ".($ENV{$_}=$hh{$_})."\n" for(keys %hh);
 $buf.="$_: $hh{$_}\n" for(keys %hh);
 $buf.="\n";
 $RANGE[4]=1;
 if($methods{$ENV{'REQUEST_METHOD'}} == 2){
  if($RANGE[5]){
  EX:
   print_($buf) if($buf);
   exit
  }
  @RANGE[0,1]=(-1,-1)
 }
}else{return 1}
}
if($RANGE[1] ne ''){
 if($pos>$RANGE[1]){
  goto EX if($RANGE[4]==2);
  $pos+=$ll;
  $l=$buf&&print_($buf);
  $buf='';
  return $l
 }elsif(($n=$pos+$ll-1-$RANGE[1])>0){
  substr($b,-$n)=''
 }
}
substr($b,0,$n,'') if(($n=$RANGE[0]-$pos)>0);
$pos+=$ll;
$b=sprintf("%x\n%s\n",$ll,$b) if($CHUNKED&&($ll-=$n));
if($buf){
 $b=$buf.$b;
 $buf=''
}
print_($b)
}


sub print_{
for(my ($i,$n,$l)=(0,0,length($_[0]));$l>$i;$i+=$n){
 select(undef,my $y=$vec_out,undef,$RANGE[9])&&
 ($n=send($OUT,substr($_[0],$i,$wbufsize),$wbufsize,$MSG_DONTWAIT))
 ||return 0;
 if($maxwbufsize && (my $wb=$wbufsize-$n)>0 && (my $wb1=$l-$i-$n)>0){
  $wb=$wb1 if($wb1<$wb);
   if(($wb+=unpack('L',getsockopt($OUT,$SOL_SOCKET,$SO_SNDBUF)))<=$maxwbufsize){
    setsockopt($OUT,$SOL_SOCKET,$SO_SNDBUF,pack('L',$wb>>1));
   }
 }
}
1
}

#sub print_{syswrite($OUT,$_[0])}

sub OPEN{open($OUT,$_[1],$_[2]);tie($_[0]=$IN=$OUT,'phttpd')}
sub WRITE{PRINT($_[0],substr($_[1],0,$_[2]))}
sub PRINTF{PRINT(shift,sprintf(shift,@_))}
sub CLOSE{untie $IN;close($IN)}
sub GETC{READ($_[0],my $x,1);$x}
sub READ{
my($i,$s,$n,$cnt)=(0,$_[1]='',$_[2],0);
while($n>0&&select($i=$vec_in,undef,undef,$RANGE[11])){
 recv($IN,$s='',$n,$MSG_DONTWAIT);
 $cnt+=($i=length($s)||last);
 $_[1].=$s;
 $n-=$i
}
$cnt
}
sub READLINE{
my($y,$s,$b,$i);
while(select($y=$vec_in,undef,undef,$RANGE[11])){
 recv($IN,$s='',$rbufsize,$MSG_PEEK);
 recv($IN,$s,($i=index($s,"\n")+1)||length($s)||last,$MSG_DONTWAIT);
 $b.=$s;
 die "Request too large (>$RANGE[12])\n" if($RANGE[12]&&($rpos+=$i)>$RANGE[12]);
 $i&&return $b
}
undef
}

sub sockinit{
for(0,\&socklib){$_&&&$_;setsockopt($_[0],$SOL_SOCKET,$SO_KEEPALIVE,pack('L',$OPTIONS{'k'}!=0))&&last}
if($rbufsize=$OPTIONS{'rbuf'}){setsockopt($_[0],$SOL_SOCKET,$SO_RCVBUF,pack('L',$rbufsize>>1))
}else{$rbufsize=unpack 'L',getsockopt($_[0],$SOL_SOCKET,$SO_RCVBUF)}
if($wbufsize=$OPTIONS{'wbuf'}){setsockopt($_[0],$SOL_SOCKET,$SO_SNDBUF,pack('L',$wbufsize>>1))
}else{$wbufsize=unpack 'L',getsockopt($_[0],$SOL_SOCKET,$SO_SNDBUF)}
$maxwbufsize=$OPTIONS{'maxwbuf'};
}

sub socklib{
if(\&sockaddr_in ne \&Socket::sockaddr_in){
 undef *sockaddr_in; undef *inet_aton; undef *inet_ntoa
}
eval q(use Socket qw(:all);
 ($MSG_PEEK,$MSG_DONTWAIT,$PF_INET,$SOCK_STREAM,$SOL_SOCKET,$SO_REUSEADDR,$SOMAXCONN,$SO_ERROR,$SO_SNDBUF,$SO_RCVBUF,$INADDR_ANY,$SO_LINGER,$SO_KEEPALIVE)=
 (MSG_PEEK,MSG_DONTWAIT,PF_INET,SOCK_STREAM,SOL_SOCKET,SO_REUSEADDR,SOMAXCONN,SO_ERROR,SO_SNDBUF,SO_RCVBUF,INADDR_ANY,SO_LINGER,SO_KEEPALIVE);
 if(exists($OPTIONS{'6'})){
  ($IN6ADDR_ANY,$PF_INET6)=(IN6ADDR_ANY,PF_INET6);
 }else{
  $PROTO_TCP=getprotobyname('tcp');
 }
);
($PF_INET,$INADDR_ANY,$PROTO_TCP,*sockaddr_in,*inet_aton,*inet_ntoa)=($PF_INET6,$IN6ADDR_ANY,0,*sockaddr_in6,sub{inet_pton($PF_INET,$_[0])},sub{inet_ntop($PF_INET,$_[0])}) if(exists($OPTIONS{'6'}));
}

sub sockaddr_in{$#_>0?pack 'Sna4x8',2,@_:(unpack 'Sna4x8',$_[0])[1,2]}
sub inet_aton{pack 'C4',split(/\./,$_[0])}
sub inet_ntoa{join('.',unpack('C4',$_[0]))}

sub xfork{$$==$mainpid&&(exists($OPTIONS{'y'})?!($mainpid=fork):fork)}

sub preforker{
my $n=shift||return;
$mainpid="$tid$$";
while(1){
 for(1..$n){fork||return}
 while(wait()!=-1){fork||return}
}
}

sub end{
 $^W=0;
 if(@errors){
  (@RANGE[2,3,6],$buf)=(0,0,1,'');
  print STDERR "Status: 500\n\nError(s):<pre>".join("\n",@errors)."</pre>While loading: $ENV{'SCRIPT_NAME'}<hr>$ENV{'SERVER_SIGNATURE'}"
 }
 if($log){for(@errors,$ERROR,$@){$_&&wlog('ERROR:',"<$_>")}}
 close($IN);
 close($OUT);
 close($SERVER);
 close($log);
}
sub wlog{defined($log)&&print $log join(' ',"$tid$$/$mainpid",@_,map($ENV{$_},'REMOTE_ADDR','REQUEST_METHOD','HTTP_HOST','REQUEST_URI'))."\n"}
# $! lost
sub _end{$ERROR=$!;goto &end}
sub ex{$ERROR=$!;exit}
$SIG{__DIE__}=sub{push @errors,@_;&ex};
END{&end}
}

my ($mode,$content)=phttpd::httpd();
$mode?&$content:eval $content