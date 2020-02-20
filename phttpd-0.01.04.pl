#!/usr/bin/perl
# karakurt - pure perl httpd v0.01.04 (c) mahatma, GPLs

=head1 NAME

phttpd-0.01.04.pl - karakurt, small pure Perl httpd ([x]inetd or standalone).

=head1 DESCRIPTION

Small pure Perl httpd, only Perl CGI, faster Perl CGI execution.
Nice for configuration/single Perl CGI purposes.

=head1 README

karakurt, pure Perl httpd v0.01.04           (c) Dzianis Kahanovich, GPLs

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
Look to %map variable and comments. There are regular expression/substitution.
Also try suexec file mode bits. I think, with mind you may build good security
for YOUR site (I not think that may be used in multi-user mode, but may be yes,
may be no - I trying to care for minimal security in non-cached mode, but not
believe in this).

Virtual hosts: use $ENV{'HTTP_HOST'} in %map target.

Do not put "tar" into %mime - you will get auto-ungzipping in your browser
(encoding). I experienced about "binary/unknown" are good content-type for
all binary downloads and real situations.

Also: while all CGI scripts running via "eval" - all Perl comman dline options
in scripts will be ignored.

May be easy added cool features in daemon (transparent compressing, etc), but
with price of unsimplifying code. Now it is minimal and functional and primary
will be used (by me) in LAN & localhost.

=head1 PREREQUISITES

Perl 5 (tested with 5.8.6 only)

=head1 COREQUISITES

Perl 5, no modules (xinetd). Sockets (for daemon mode only).

=pod OSNAMES

All

=pod SCRIPT CATEGORIES

Web

=cut

my (%OPTIONS,@RANGE);

sub httpd{
# 'id|options mask'=>sub{"[user:group]file"}
# 'id|options mask'=>sub{"file"}
my %map=(
 '00 \.\.'=>sub{"404"},
 '03 /html/(.*)'=>sub{"html/$1"},
# '22xr /usr/portage/distfiles/.*'=>sub{"gcache-0.01.cgi"},
 '44x ..*'=>sub{"404"}
);

my %mime=(
'html'=>'text/html',
'htm'=>'text/html',
'js'=>'text/javascript',
'gif'=>'image/gif',
'jpg'=>'image/jpeg',
'gz'=>'application/x-gzip'
);

my %mime_enc=( # to prevent "content-encoding" just remove real type from mime
'gz'=>'gzip'
);

my $version='0.01.04';
my $server="karakurt";
my $root=substr($0,0,rindex($0,'/'));
my ($content,%contents,%contents_uri,$file,@errors,$mainpid,@guid);

$ENV{'REMOTE_ADDR'}=$ENV{'REMOTE_HOST'};
$ENV{'SERVER_PROTOCOL'}='HTTP/1.0';
$ENV{'SERVER_SOFTWARE'}="$server/$version";
$ENV{'SERVER_SIGNATURE'}="<ADDRESS>$server/$version</ADDRESS>\n";

for(@_){
 if(substr($_,0,1) eq '-'){$OPTIONS{$content=substr($_,1)}=''}
 else{$OPTIONS{$content}.=$OPTIONS{$content}?" $_":$_}
}

END{print "Status: 500\n\nError(s): ".join("<br>",$!,@errors)."<br>While loading: $ENV{'SCRIPT_FILENAME'}<hr>$ENV{'SERVER_SIGNATURE'}" if(tied(*STDOUT)&&$$!=$mainpid)&&!defined($RANGE[4])}
$SIG{__DIE__}=sub{@errors=(@errors,@_)};

chdir($root);

if(exists($OPTIONS{'a'})){
$mainpid=$$;
my @a=split(':',$OPTIONS{'a'},2);
eval <<EOT
use Socket;
socket(SERVER,PF_INET,SOCK_STREAM,getprotobyname('tcp'))&&
setsockopt(SERVER,SOL_SOCKET,SO_REUSEADDR,pack("l",1))&&
bind(SERVER, sockaddr_in(\$a[1]||591,\$a[0]?inet_aton(\$a[0]):INADDR_ANY))&&
listen(SERVER,SOMAXCONN)
EOT
||die "Socket open error: $!\n";
DAEMON:
untie(*STDERR);
untie(*STDOUT);
close(STDERR);
close(STDOUT);
close(STDIN);
while($mainpid==$$){
 close(CLIENT);
 my $a;
 ($ENV{'REMOTE_PORT'},$a)=sockaddr_in(accept(CLIENT,SERVER) or die);
 $ENV{'REMOTE_ADDR'}=inet_ntoa($a);
 ($ENV{'SERVER_PORT'},$a)=sockaddr_in(getsockname(CLIENT));
 $ENV{'SERVER_ADDR'}=inet_ntoa($a);
 last if(exists($OPTIONS{'x'})||exists($OPTIONS{'X'}));
 fork
}
open STDIN,"<&CLIENT" or die;
open STDOUT,">&CLIENT" or die;
open STDERR,">&STDOUT" or die;
}elsif(!exists($OPTIONS{'i'})){
 die "$ENV{'SERVER_SOFTWARE'} pure Perl httpd, (c) Dzianis Kahanovich, 2005-2006, GPLs\n -i - [x]inetd mode (main goal, safe)\n -a [addr][:port] - bind to|\":591\"\n -H - break CGI (HEAD|range)\n -r - accept ranges (experimental)\nStandalone (dangerous!):\n -x - cache CGI (SCRIPT_FILENAME)\n -X - eXtreme cache CGI (REDIRECT_URI, no checking)\n(only Perl CGI supported)\n"
}

@guid=(-1,-1);
tie(*STDERR,'phttpd');
tie(*STDOUT,'phttpd');
@request=split(/[ \n\r]/,<STDIN>);
for(my $s=<STDIN>;defined($s) && $s ne "\n" && $s ne "\r\n";$s=<STDIN>){
 my $x;
 $s=~s/(.*?)\: (.*?)[\r\n]/$x=uc($1);$2/ge;
 if(defined($x)){
  $x=~s/-/_/g;
  $x="HTTP_$x";
  $x=~s/HTTP_CONTENT/CONTENT/g;
  $ENV{$x}=$s
 }
}
$RANGE[3]=~s/bytes\=(.*?)-(.*?)/$RANGE[0]=$1;$RANGE[1]=$2/gse if(defined($RANGE[3]=$ENV{'HTTP_RANGE'}));
$ENV{'REQUEST_METHOD'}=uc($request[0]);
($file,$ENV{'QUERY_STRING'})=split(/\?/,$ENV{'REQUEST_URI'}=$request[1],2);
$file="/$file" if(substr($file,0,1) ne '/');
$file.="\n";
$file=~s/(\/.*?)\/\.\.([\/\n])/$1$2/g;
chomp($file);
$ENV{'REDIRECT_URI'}=$ENV{'SCRIPT_NAME'}=$file||='/';
if(exists($contents_uri{$file})){
 $content=$contents_uri{$file};
 ($content,@guid[0,1])=@$content;
 goto EXEC_CGI
}
for(sort keys %map){
 my @mask=split(/ /,$_,2);
 $content=$file;
 $content=~s/$mask[1]//;
 if($content eq ''){
  undef $content;
  $OPTIONS{$_}='' for(split(//,$mask[0]));
  my $e=$map{$_};
  $file=~s/$mask[1]/&$e/e;
  $file=~s/\[(.*?)\:(.*?)\]/my $g=($2+0 eq $2||$2 eq ''?$2:getgrnam($2));my $u=($1+0 eq $1||$1 eq ''?$1:getpwnam($1)); die "Invalid uid or gid\n" if(!(defined($u)&&defined($g)));@guid=($u,$g);''/e if(substr($file,0,1) eq '[');
  if($$!=$mainpid){
   $)="$guid[1] ".($(=$guid[1]) if($guid[1]!=-1);
   $<=$>=$guid[0] if($guid[0]!=-1)
  }
  $ENV{'SCRIPT_FILENAME'}=$file;
  my @stat;
  my $filetype=-d $file?1:-x$file?2:3;
  if($filetype==2){
   if(exists($contents{$file})){
    @stat=stat($file);
    if($stat[9]==$contents{$file}[12]){
     $content=$contents{$file};
     ($content,@guid[0,1])=@$content;
     goto EXEC_CGI
    }
    delete($contents{$file})
   }
   open FH,"<$file" or die " \n";
   @stat=stat(FH) if(!defined(@stat));
   read FH,$content,$stat[7] or die " \n";
   close FH;
   if(defined($mainpid)){
    $guid[1]=$stat[5] if($stat[2]&02000);
    $guid[0]=$stat[4] if($stat[2]&04000);
    $content=eval "sub \{ $content \};";
    if(exists($OPTIONS{'X'})){
     $contents_uri{$ENV{'REDIRECT_URI'}}=[$content,@guid]
    }elsif(exists($OPTIONS{'x'})){
     $contents{$file}=[$content,@guid,@stat]
    }
  EXEC_CGI:
    if($$==$mainpid){
     fork;
     goto DAEMON if($$==$mainpid)
    }
    $RANGE[2]=$OPTIONS{'r'} if(defined($RANGE[3]));
    $)="$guid[1] ".($(=$guid[1]) if($guid[1]!=-1);
    $<=$>=$guid[0] if($guid[0]!=-1);
    &$content;
    exit
   }
   $RANGE[2]=$OPTIONS{'r'} if(defined($RANGE[3]));
   $)="$stat[5] ".($(=$stat[5]) if($stat[2]&02000);
   $<=$>=$stat[4] if($stat[2]&04000);
   return $content
  }
  if($$==$mainpid){
   fork;
   goto DAEMON if($$==$mainpid)
  }
  $OPTIONS{'H'}=1;
  $RANGE[2]=$RANGE[3];
  if($filetype==1){
   opendir DH,$file or die " \n";
   @stat=stat(DH);
   my $s="Index of $ENV{'REQUEST_URI'}";
   $s="<html><head><title>$s</title></head><body><H1>$s</H1><pre><hr><pre>";
   for(readdir(DH)){
    my @st=stat("$file$_");
    $_=~s/([\x00-\x1f,:\"\'\\])/sprintf('%%%02X',ord($1))/eg;
    $_.='/' if(-d "$file$_");
    $s.="<a href='$_'>$_</a>		".localtime($st[9])."	$st[7]\n"
   }
   $s.="</pre><hr>$ENV{'SERVER_SIGNATURE'}</body></html>";
   close DH;
   print "Last-Modified: ".localtime($stat[9]),"\nContent-type: text/html\nContent-length: ",length($s),"\n\n",$s
  }else{
   open FH,"<$file" or die " \n";
   @stat=stat(FH) if(!defined(@stat));
   my $h="Last-Modified: ".localtime($stat[9])."\n";
   my @x=(split(/\./,$file))[-1,-2];
   my ($t,$enc);
   read(FH,$content,my $cnt=1024>$stat[7]?$stat[7]:1024) or die " \n";
   if(substr($content,0,14) eq '<!DOCTYPE html'){
    $t='text/html'
   }elsif(($enc=$mime_enc{$x[0]}) && substr(",$ENV{'HTTP_ACCEPT_ENCODING'},",",$enc,")>=0 && ($t=$mime{$x[1]})){
    $h.="Content-encoding: $enc\n"
   }
   $t||=$mime{$x[0]}||(-B $file?'binary/unknown':'text/plain');
   print $h,"Content-Length: ",$stat[7],"\nContent-type: $t\n\n",$content;
   while((my $n=$stat[7]-$cnt)>0){
    read(FH,$content,$cnt=+($n>1024?1024:$n)) or die " \n";
    print $content
   }
   close FH
  }
  exit
 }
}
}


{
package phttpd;
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
my ($buf,$pos);
sub TIEHANDLE{bless({})}
sub PRINT{
shift;
my ($b,$l);
if(!defined($RANGE[4])){
($buf,$b)=split(/[\r]{0,}\n[\r]{0,}\n[\r]{0,}/,join('',$buf,@_),2);
if(defined($b)){
 my %hh=('Content-type'=>'text/html','Status'=>200,'Server'=>$ENV{'SERVER_SOFTWARE'},'Date'=>''.localtime(time));
 $_=~s/(.*?)\:[ 	]{1,}(.*)[\r]{0,}/$hh{ucfirst(lc($1))}=$2/e for(split("\n",$buf));
 if(defined($RANGE[2])){
  $RANGE[4]=exists($OPTIONS{'H'})+1;
  my $l='*';
  $hh{'Content-length'}=($RANGE[1]=($l=$hh{'Content-length'})-1)-$RANGE[0]+1 if(exists($hh{'Content-length'}));
  $hh{'Content-range'}="bytes $RANGE[0]-$RANGE[1]/$l";
  $hh{'Status'}=206
 }
 $buf=delete($hh{'Status'});
 $buf="$ENV{'SERVER_PROTOCOL'} $buf $rfc2068_status{$buf}\n";
 while(my ($x,$y)=each %hh){$buf.="$x: $y\n"}
 untie *STDOUT;
 untie *STDERR;
 print $buf,"\n";
 if($ENV{'REQUEST_METHOD'} eq 'HEAD'){
  exit if(exists($OPTIONS{'H'}));
  $RANGE[4]=$RANGE[0]=$RANGE[1]=-1
 }
}
}else{$b=join('',@_)}
$l=length($b);
if($RANGE[1] ne ''){
 if($pos>$RANGE[1]){
  exit if($RANGE[4]==2);
  goto RET
 }elsif((my $n=$pos+$l-1-$RANGE[1])>0){
  substr($b,-$n)='';
  $pos+=$n;
  $l-=$n
 }
}
if((my $n=$RANGE[0]-$pos)>0){
 if($n>$l){$n=$l;$b=''}
 else{substr($b,0,$n,'')}
 $pos+=$n;
 $l-=$n
}
if($l>0){
 if(tied(*STDOUT)){
  untie *STDOUT;
  untie *STDERR
 } 
 print $b;
 $pos+=$l
}
RET:
if(defined($RANGE[4]) && !tied(*STDOUT)){
 tie(*STDERR,'phttpd');
 tie(*STDOUT,'phttpd')
}
1
}
}

eval httpd(@ARGV)
