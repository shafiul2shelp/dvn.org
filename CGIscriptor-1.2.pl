#! perl 
#
# (configure the first line to contain YOUR path to perl 5.000. 
#  I just added a symbolic link to perl in the working directory, $PWD)
#
# CGIscriptor.pl
# Version 1.200
# 23 March 2000
#
# YOU NEED:
#
# perl 5.0 or higher (see: "http://www.perl.org/")
#                
# Notes:
#  
# This Perl program will run on any WWW server that runs perl scripts,
# just add a line like the following to your srm.conf file 
# (Apache example):
# 
# ScriptAlias /SHTML/ /real-path/CGIscriptor.pl/
# 
# URL's that refer to http://www.your.address/SHTML/... will now be handled 
# by CGIscriptor.pl, which can use a private directory tree (default is the 
# SERVER_ROOT directory tree, but it can be anywhere, see below).
# 
# This file contains all documentation as comments. These comments
# can be removed to speed up loading (e.g., `egrep -v '^#' CGIscriptor.pl` > 
# leanScriptor.pl).
# 
# There is also a possibility to compile (parts of) the code (see 
# "http://users.ox.ac.uk/~mbeattie/perl.html"), but there are better 
# ways to speed things up, like using perlmod.pm (with the Apache server).
# 
# CGIscriptor.pl can be run from the command line as 
# `CGIscriptor.pl <path> <query>`, inside a perl script with 
# 'do CGIscriptor.pl' after setting $ENV{PATH_INFO} and $ENV{QUERY_STRING}, 
# or CGIscriptor.pl can be loaded with 'require "/real-path/CGIscriptor.pl"'. 
# In the latter case, requests are processed by 'Handle_Request();' 
# (again after setting $ENV{PATH_INFO} and $ENV{QUERY_STRING}). 
# 
# Running demo's and more information can be found at 
# http://www.fon.hum.uva.nl/~rob/OSS/OSS.html
#         
# A pocket-size HTTP daemon, CGIservlet.pl, is available from my web site
# that can use CGIscriptor.pl as the base of a µWWW server and demonstrates
# its use.
#
############################################################################
#
# Changes (document ALL changes with date, name and email here):
#
# 10 Mar  2000 - Qualified unconditional removal of '#' that preclude
#                the use of $#foo, i.e., I changed
#                s/[^\\]\#[^\n\f\r]*([\n\f\r])/\1/g
#                to
#                s/[^\\\$]\#[^\n\f\r]*([\n\f\r])/\1/g
# 03 Mar  2000 - Added a '$BlockPathAccess' variable to "hide" 
#				 things like, e.g., CVS information in CVS subtrees
# 10 Feb  2000 - URLencode/URLdecode have been made case-insensitive
# 10 Feb  2000 - Added a BrowseDirs function (CGIscriptor package)
# 01 Feb  2000 - A BinaryMapFile in the ~/ directory has precedence
#                over a "burried" BinaryMapFile.
# 04 Oct  1999 - Added two functions to check file names and email addresses
#                (CGIscriptor::CGIsafeFileName and 
#                 CGIscriptor::CGIsafeEmailAddress)
# 28 Sept 1999 - Corrected bug in sysread call for reading POST method 
#		 to allow LONG posts.
# 28 Sept 1999 - Changed CGIparseValue to handle multipart/form-data.
# 29 July 1999 - Refer to BinaryMapFile from CGIscriptor directory, if
#                this directory exists.
# 07 June 1999 - Limit file-pattern matching to LAST extension
# 04 June 1999 - Default text/html content type is printed only once.
# 18 May  1999 - Bug in replacement of ~/ and ./ removed.
#                (Rob van Son, Rob.van.Son@hum.uva.nl)
# 15 May  1999 - Changed the name of the execute package to CGIexecute.
#                Changed the processing of the Accept and Reject file.
#                Added a full expression evaluation to Access Control.
#                (Rob van Son, Rob.van.Son@hum.uva.nl)
# 27 Apr  1999 - Brought CGIscriptor under the GNU GPL. Made CGIscriptor 
# Version 1.1    a module that can be called with 'require "CGIscriptor.pl"'.
#                Requests are serviced by "Handle_Request()". CGIscriptor 
#                can still be called as a isolated perl script and a shell
#                command. 
#                Changed the "factory default setting" so that it will run
#                from the SERVER_ROOT directory.
#                (Rob van Son, Rob.van.Son@hum.uva.nl)
# 29 Mar  1999 - Remove second debugging STDERR switch. Moved most code
#                to subroutines to change CGIscriptor into a module.
#                Added mapping to process unsupported file types (e.g., binary
#                pictures). See $BinaryMapFile.
#                (Rob van Son, Rob.van.Son@hum.uva.nl)
# 24 Sept 1998 - Changed text of license (Rob van Son, Rob.van.Son@hum.uva.nl)
#                Removed a double setting of filepatterns and maximum query 
#                size. Changed email address. Removed some typos from the
#                comments.
# 02 June 1998 - Bug fixed in URLdecode. Changing the foreach loop variable
#                caused quiting CGIscriptor.(Rob van Son, Rob.van.Son@hum.uva.nl)
# 02 June 1998 - $SS_PUB and $SS_SCRIPT inserted an extra /, removed.
#                (Rob van Son, Rob.van.Son@hum.uva.nl)
# 
#
# Known Bugs:
# 
# 23 Mar 2000
# It is not possible to use operators or variables to construct variable names, 
# e.g., $bar = \@{$foo}; won't work. However, eval('$bar = \@{'.$foo.'};'); 
# will indeed work. If someone could tell me why, I would be obliged.
# 
#
############################################################################
#
# OBLIGATORY USER CONFIGURATION
#
# Configure the directories where all user files can be found (this 
# is the equivalent of the server root directory of a WWW-server).  
# These directories can be located ANYWHERE. For security reasons, it is 
# better to locate them outside the WWW-tree of your HTTP server, unless
# CGIscripter handles ALL requests.
# 
# For convenience, the defaults are set to the root of the WWW server.
# However, this might not be safe!
# 
# ~/ text files
# $YOUR_HTML_FILES = "/usr/pub/WWW/SHTML"; # or SS_PUB as environment var
$YOUR_HTML_FILES = $ENV{'SERVER_ROOT'};     # default is the SERVER_ROOT
#
# ./ script files (recommended to be different from the previous)
# $YOUR_SCRIPTS = "/usr/pub/WWW/scripts";  # or SS_SCRIPT as environment var
$YOUR_SCRIPTS = $YOUR_HTML_FILES;           # This might be a SECURITY RISK
#
# End of obligatory user configuration
# (note: there is more non-essential user configuration below)
#
############################################################################
#
# OPTIONAL USER CONFIGURATION (all values are used CASE INSENSITIVE)
#
# Script content-types: TYPE="Content-type" (user defined mime-type)
$ServerScriptContentType = "text/ssperl"; # Server Side Perl scripts
#
$ShellScriptContentType = "text/osshell"; # OS shell scripts 
#                                         # (Server Side perl ``-execution)
#
# Accessible file patterns, block any request that doesn't match.
# Matches any file with the extension .(s)htm(l) or .xmr (\. is used in regexp)
# Note: $PATH_INFO =~ m@($FilePattern)$@is;
$FilePattern = ".shtml|.htm|.html|.xmr";  
#
# File pattern post-processing
$FilePattern =~ s/([@.])/\\$1/g;  # Convert . and @ to \. and \@
#
# Raw files must contain their own Content-type (xmr < x-multipart-replace). 
# THIS IS A SUBSET OF THE FILES DEFINED IN $FilePattern
$RawFilePattern = ".xmr"; 
#
# Block access to all (sub-) paths and directories that match the following (URL) path
# (is used as die if $BlockPathAccess && $ENV{'PATH_INFO'} =~ m@$BlockPathAccess@; )
$BlockPathAccess = '/CVS/';		# Protect CVS information
#
# Raw File pattern post-processing
$RawFilePattern =~ s/([@.])/\\$1/g;  # Convert . and @ to \. and \@
#
# All (blocked) other file-types can be mapped to a single "binary-file" 
# processor (a kind of pseudo-file path). This can either be an error 
# message (e.g., "illegal file") or contain a script that serves binary 
# files.
# Note: the real file path wil be stored in $ENV{CGI_BINARY_FILE}. 
$BinaryMapFile = "/BinaryMapFile.xmr"; 
# Allow for the addition of a CGIscriptor directory
# Note that a BinaryMapFile in the "~/" directory has precedence
$BinaryMapFile = "/CGIscriptor".$BinaryMapFile 
	if !  -e "$YOUR_HTML_FILES".$BinaryMapFile  
	   && -e "$YOUR_HTML_FILES/CGIscriptor".$BinaryMapFile;
#
# List of all characters that are allowed in file names and paths. 
# All requests containing illegal characters are blocked. 
# THIS IS A SECURITY FEATURE
# (this is also used to parse filenames in SRC= features, note the 
# '-quotes, they are essential)
$FileAllowedChars = '\w\.\~\*\?\/\:\-\s'; # Covers Unix and Mac
#
# The string used to separate directories in the path 
# (used for ~/ and ./ substitution).  
$DirectorySeparator = '/';                 # Unix
# $DirectorySeparator = ':';                 # Mac
# $DirectorySeparator = '\';                 # MS things ?
# (I haven't actually tested this for non-UNIX OS's)
#
# Maximum size of the Query (number of characters clients can send)
$MaximumQuerySize = 2**17 - 1; # = 2**14 - 1
#
#
# DEBUGGING
#
# Suppress error messages, this can be changed for debugging or error-logging
#open(STDERR, "/dev/null"); # (comment for use in debugging)
#
# If CGIscriptor is used from the command line, the command line 
# arguments are interpreted as the file (1st) and the Query String (rest).
$ENV{'PATH_INFO'} = shift(@ARGV) unless exists($ENV{'PATH_INFO'}); 
$ENV{'QUERY_STRING'} = join("&", @ARGV) unless exists($ENV{'QUERY_STRING'});
#
# End of optional user configuration
# (note: there is more non-essential user configuration below)
#
###############################################################################
#
# Author and Copyright (c):
# Rob van Son, © 1995,1996,1997,1998,1999
# Institute of Phonetic Sciences & IFOTT
# University of Amsterdam
# Herengracht 338
# NL-1016CG Amsterdam, The Netherlands 
# Email: Rob.van.Son@hum.uva.nl
#        rob.van.son@workmail.com
# WWW  : http://www.fon.hum.uva.nl/rob
# mail:  Institute of Phonetic Sciences
#        University of Amsterdam
#        Herengracht 338
#        NL-1016CG Amsterdam
#        The Netherlands
#        tel +31 205252183
#        fax +31 205252197
#
# License for use and disclaimers
#
# CGIscriptor merges plain ASCII HTML files transparantly  
# with CGI variables, PERL code, shell commands, and executable scripts. 
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#
#########################################################################
#
# HYPE
#
# CGIscriptor merges plain ASCII HTML files transparantly and safely 
# with CGI variables, PERL code, shell commands, and executable scripts 
# (on-line and real-time). It combines the "ease of use" of HTML files with 
# the versatillity of specialized scripts and PERL programs. It hides 
# all the specifics and idiosyncrasies of correct output and CGI coding 
# and naming. Scripts do not have to be aware of HTML, HTTP, or CGI 
# conventions just as HTML files can be ignorant of scripts and the 
# associated values. CGIscriptor complies with the W3C HTML 4.0 
# recommendations.
#
# THIS IS HOW IT WORKS
#
# CGIscriptor reads text files from the requested input file (i.e., from
# $YOUR_HTML_FILES$PATH_INFO) and writes them to <STDOUT> (i.e., the client 
# requesting the service) preceded by the obligatory 
# "Content-type: text/html\n\n" string
# (except for "raw" files which supply their own Content-type message).
#
# When CGIscriptor encounters an embedded script, indicated by an HTML4 tag
#
# <SCRIPT TYPE="text/ssperl" [SRC="ScriptSource"]>
# PERL script
# </SCRIPT> 
#
# or
# 
# <SCRIPT TYPE="text/osshell" [SRC="ScriptSource"]>
# OS Shell script
# </SCRIPT> 
# 
# construct (anything between []-brackets is optional), the embedded 
# script is removed and both the contents of the source file (i.e., 
# "do 'ScriptSource'") AND the script are evaluated as a PERL 
# program (i.e., by eval()) or shell script (i.e., by a "safe" version of 
# `Command`, qx). The output of the eval() function takes the place of the 
# original <SCRIPT></SCRIPT> construct in the output string. 
# 
# Example: printing "Hello World"
# <HTML><HEAD><TITLE>Hello World</TITLE>
# <BODY>
# <H1><SCRIPT TYPE="text/ssperl">"Hello World"</SCRIPT></H1>
# </BODY></HTML>
# 
# Save this in a file, hello.html, in the directory you indicated with 
# $YOUR_HTML_FILES and access http://your_server/SHTML/hello.html. 
# This is realy ALL you need to do to get going.
# 
# You can use any values that are delivered in CGI-compliant form (i.e., 
# the "?name=value" type URL additions) transparently as "$name" variables 
# in your scripts IFF you have declared them in a META tag before: e.g.,
# <META CONTENT="text/ssperl; CGI='$name = `default value`' 
# [SRC='ScriptSource']"> 
# After such a META tag, you can use $name as an ordinary PERL variable
# (the ScriptSource file is immediately evaluated with "do 'ScriptSource'"). 
# The CGIscriptor script allows you to write ordinary HTML files which will 
# include dynamic CGI aware (run time) features, such as on-line answers 
# to specific CGI requests, queries, or the results of calculations. 
#
# For example, if you wanted to answer questions of clients, you could write 
# a Perl program called "Answer.pl" with a function "AnswerQuestion()"
# that prints out the answer to requests given as arguments. You then write 
# an HTML page "Respond.html" containing the following fragment:
#
# <center>
# The Answer to your question
# <META CONTENT="text/ssperl; CGI='$Question'">
# <h3><SCRIPT TYPE="text/ssperl">$Question</SCRIPT></h3>
# is 
# <h3><SCRIPT TYPE="text/ssperl" SRC="./PATH/Answer.pl">
#  AnswerQuestion($Question);
# </SCRIPT></h3>
# </center>
# <FORM ACTION=Respond.html METHOD=GET>
# Next question: <INPUT NAME="Question" TYPE=TEXT SIZE=40><br>
# <INPUT TYPE=SUBMIT VALUE="Ask">
# </FORM>
#
# The output could look like the following (in HTML-speak):
# 
# <CENTER>
# The Answer to your question
# <h3>What is the capital of the Netherlands?</h3>
# is
# <h3>Amsterdam</h3>
# </CENTER>
# <FORM ACTION=Respond.html METHOD=GET>
# Next question: <INPUT NAME="Question" TYPE=TEXT SIZE=40><br>
# <INPUT TYPE=SUBMIT VALUE="Ask">
#
# Note that the function "Answer.pl" does know nothing about CGI or HTML,
# it just prints out answers to arguments. Likewise, the text has no 
# provisions for scripts or CGI like constructs. Also, it is completely 
# trivial to extend this "program" to use the "Answer" later in the page 
# to call up other information or pictures/sounds. The final text never 
# shows any cue as to what the original "source" looked like, i.e., 
# where you store your scripts and how they are called.
# 
# There are some extra's. The argument of the files called in a SRC= tag 
# can access the CGI variables declared in the preceding META tag from
# the @ARGV array. Executable files are called as: 
# `file '$ARGV[0]' ... ` (e.g., `Answer.pl \'$Question\'`;)
# The files called from SRC can even be (CGIscriptor) html files which are 
# processed in-line. Furthermore, the SRC= tag can contain a perl block 
# that is evaluated. That is, 
# <META CONTENT="text/ssperl; CGI='$Question' SRC='{$Question}'">
# will result in the evaluation of "print do {$Question};" and the VALUE
# of $Question will be printed. Note that these "SRC-blocks" can be 
# preceded and followed by other file names, but only a single block is 
# allowed in a SRC= tag.
# 
# A user manual follows the HTML 4 and security paragraphs below.
# 
##########################################################################
#
# HTML 4 compliance
# 
# In general, CGIscriptor.pl complies with the HTML 4 recommendations of 
# the W3C. This means that any software to manage Web sites will be able
# to handle CGIscriptor files, as will web agents.
# 
# All script code should be placed between <SCRIPT></SCRIPT> tags, the 
# script type is indicated with TYPE="mime-type", the LANGUAGE
# feature is ignored, and a SRC feature is implemented. All non-Perl 
# attributes are delegated to the CONTENT feature of <META> tags.
# 
# However, the behavior deviates from the W3C recommendations at some 
# points. Most notably:
# 0- The scripts are executed at the server side, invisible to the 
#    client (i.e., the browser)
# 1- The mime-types are personal and idiosyncratic, but can be adapted.
# 2- Code in the body of a <SCRIPT></SCRIPT> tag-pair is still evaluated 
#    when a SRC feature is present.
# 3- The SRC feature reads a list of files.
# 4- The files in a SRC feature are processed according to file type.
# 5- The SRC feature evaluates inline Perl code.
# 6- Processed META tags are removed from the output document.
# 7- All features of the processed META tags, except CONTENT, are ignored 
#    (i.e., deleted from the output).
# 8- META tags can be placed ANYWHERE in the document.
# 9- Through the SRC feature, META tags can have visible output in the 
#    document.
#    
# The reasons for these choices are:
# You can still write completely HTML4 compliant documents. CGIscriptor 
# will not force you to write "deviant" code. However, it allows you to 
# do so (which is, in fact, just as bad). The prime design principle 
# was to allow users to include plain Perl code. The code itself should 
# be "enhancement free". Therefore, extra features were needed to 
# supply easy access to CGI and Web site components. For security 
# reasons these have to be declared explicitly. The SRC feature 
# transparently manages access to external files, especially the safe 
# use of executable files. 
# The META tag handles the declarations of external (CGI) variables.
# EVERYTHING THE META TAG DOES CAN BE DONE INSIDE A <SCRIPT></SCRIPT>
# TAG CONSTRUCT.
# 
# The reason the SRC features (and its Perl code evaluation) were build 
# into the META tag is sheer laziness. This allows more compact 
# documents and easier debugging. The values of the CGI variables can 
# be immediately printed and commands called without having to add 
# another TAG pair.
#
##########################################################################
#
# SECURITY
#
# Your WWW site is a few keystrokes away from a hundred million internet 
# users. A fair percentage of these users knows more about your computer 
# than you do. And some of these just might have bad intentions.
# 
# To ensure uncompromized operation of your server and platform, several 
# features are incorporated in CGIscriptor.pl to enhance security.
# First of all, you should check the source of this program. No security
# measures will help you when you download programs from anonymous sources.
# If you want to use THIS file, please make sure that it is uncompromized.
# The best way to do this is to contact the source and try to determine
# whether s/he is reliable (and accountable).
# 
# BE AWARE THAT ANY PROGRAMMER CAN CHANGE THIS PROGRAM IN SUCH A WAY THAT
# IT WILL SET THE DOORS TO YOUR SYSTEM WIDE OPEN
# 
# I would like to ask any user who finds bugs that could compromise 
# security to report them to me (and any other bug too,
# Email: Rob.van.Son@hum.uva.nl, Rob.van.Son@hum.uva.nl or 
#        rob.van.son@workmail.com).
#
# Security features
#
# 1 Invisibility  
#   The inner workings of the HTML source files are completely hidden  
#   from the client. Only the HTTP header and the ever changing content 
#   of the output distinguish it from the output of a plain, fixed HTML
#   file. Names, structures, and arguments of the "embedded" scripts 
#   are invisible to the client. Error output is suppressed except
#   during debugging (user configurable).
#
# 2 Separate directory trees
#   Directories containing Inline text and script files can reside on
#   separate trees, distinct from those of the HTTP server. This means
#   that NEITHER the text files, NOR the script files can be read by
#   clients other than through CGIscriptor.pl, UNLESS they are 
#   EXPLICITELY made available. 
#
# 3 Requests are NEVER "evaluated"
#   All client supplied values are used as literal values (''-quoted). 
#   Client supplied ''-quotes are ALWAYS removed. Therefore, as long as the 
#   embedded scripts do NOT themselves evaluate these values, clients CANNOT 
#   supply executable commands. Be sure to AVOID scripts like:
#   
#   <META CONTENT="text/ssperl; CGI='$UserValue'">
#   <SCRIPT TYPE="text/ssperl">$dir = `ls -1 $UserValue`;</SCRIPT>
#   
#   These are a recipe for disaster. However, the following quoted
#   form should be save (but is still not adviced):
#   
#   <SCRIPT TYPE="text/ssperl">$dir = `ls -1 \'$UserValue\'`;</SCRIPT>
#   
#   A special function, SAFEqx(), will automatically do exactly this, 
#   e.g., SAFEqx('ls -1 $UserValue') will execute `ls -1 \'$UserValue\'`
#   with $UserValue interpolated. I recommend to use SAFEqx() instead
#   of backticks whenever you can. The OS shell scripts inside
#     
#   <SCRIPT TYPE="text/osshell">ls -1 $UserValue</SCRIPT> 
#   
#   are handeld by SAFEqx and automatically ''-quoted.
#
# 4 Logging of requests
#   All requests can be logged separate from the Host server. The level of
#   detail is user configurable: Including or excluding the actual queries. 
#   This allows for the inspection of (im-) proper use.
#
# 5 Access control: Clients
#   The Remote addresses can be checked against a list of authorized 
#   (i.e., accepted) or non-authorized (i.e., rejected) clients. Both 
#   REMOTE_HOST and REMOTE_ADDR are tested so clients without a proper 
#   HOST name can be (in-) excluded by their IP-address. Client patterns 
#   containing all numbers and dots are considered IP-addresses, all others
#   domain names. No wild-cards or regexp's are allowed, only partial 
#   addresses.
#   Matching of names is done from the back to the front (domain first, 
#   i.e., $REMOTE_HOST =~ /\Q$pattern\E$/is), so including ".edu" will 
#   accept or reject all clients from the domain EDU. Matching of 
#   IP-addresses is done from the front to the back (domain first, i.e., 
#   $REMOTE_ADDR =~ /^\Q$pattern\E/is), so including "128." will (in-) 
#   exclude all clients whose IP-address starts with 128.
#   There are two special symbols: "-" matches HOSTs with no name and "*"
#   matches ALL HOSTS/clients.
#   For those needing more expressional power, lines starting with 
#   "-e" are evaluated by the perl eval() function. E.g., 
#   '-e $REMOTE_HOST =~ /\.edu$/is;' will accept/reject clients from the 
#   domain '.edu'.
#
# 6 Access control: Files
#   In principle, CGIscriptor could read ANY file in the directory 
#   tree as discussed in 1. However, for security reasons this is 
#   restricted to text files. It can be made more restricted by entering 
#   a global file pattern (e.g., ".html"). This is done by default. 
#   For each client requesting access, the file pattern(s) can be made
#   more restrictive than the global pattern by entering client specific
#   file patterns in the Access Control files (see 5).
#   For example: if the ACCEPT file contained the lines
#   *           DEMO
#   .hum.uva.nl LET 
#   145.18.230.     
#   Then all clients could request paths containing "DEMO" or "demo", e.g. 
#   "/my/demo/file.html" ($PATH_INFO =~ /\Q$pattern\E/), Clients from 
#   *.hum.uva.nl could also request paths containing  "LET or "let", e.g. 
#   "/my/let/file.html", and clients from the local cluster 
#   145.18.230.[0-9]+ could access ALL files.
#   Again, for those needing more expressional power, lines starting with 
#   "-e" are evaluated. For instance: 
#   '-e $REMOTE_HOST =~ /\.edu$/is && $PATH_INFO =~ m@/DEMO/@is;' 
#   will accept/reject requests for files from the directory "/demo/" from
#   clients from the domain '.edu'.
#   
# 7 Query length limiting
#   The length of the Query string can be limited. If CONTENT_LENGTH is larger
#   than this limit, the request is rejected. The combined length of the 
#   Query string and the POST input is checked before any processing is done. 
#   This will prevent clients from overloading the scripts.
#   The actual, combined, Query Size is accessible as a variable through 
#   $CGI_Content_Length.
#  
# 8 Illegal filenames, paths, and protected directories
#   One of the primary security concerns in handling CGI-scripts is the
#   use of "funny" characters in the requests that con scripts in executing
#   malicious commands. Examples are inserting ';' or <newline> characters
#   in URL's and filenames, followed by executable commands. A special 
#   variable $FileAllowedChars stores a string of all allowed characters.
#   Any request that translates to a filename with a character OUTSIDE
#   this set will be rejected.
#   In general, all (readable files) in the ServerRoot tree are accessible.
#	This might not be what you want. For instance, your ServerRoot directory
#   might be the working directory of a CVS project and contain sensitive
#   information (e.g., the password to get to the repository). You can block
#   access to these subdirectories by adding the corresponding patterns to
#   the $BlockPathAccess variable. For instance, $BlockPathAccess = '/CVS/'
#   will block any request that contains '/CVS/' or: 
#   die if $BlockPathAccess && $ENV{'PATH_INFO'} =~ m@$BlockPathAccess@;
#   
#
###############################################################################
#
# USER MANUAL (sort of)
#
# CGIscriptor removes embedded scripts, indicated by an HTML 4 type 
# <SCRIPT TYPE='text/ssperl'> </SCRIPT> or <SCRIPT TYPE='text/osshell'> 
# </SCRIPT> constructs. The contents of the directive are executed by 
# the PERL eval() and `` functions (in a separate name space). The 
# result of the eval() function replaces the <SCRIPT> </SCRIPT> construct 
# in the output file. You can use the values that are delivered in 
# CGI-compliant form (i.e., the "?name=value&.." type URL additions) 
# transparently as "$name" variables in your directives after they are 
# defined in a <META> tag. 
# If you define the variable "$CGIscriptorResults" in a <META> tag, all 
# subsequent <SCRIPT> and <META> results (including the defining <META> 
# tag) will also be pushed onto a stack: @CGIscriptorResults. This list 
# behaves like any other, ordinary list and can be manipulated.
#
# Both GET and POST requests are accepted. These two methods are treated
# equal. Variables, i.e., those values that are determined when a file is
# processed, are indicated in the META tag by $<name> or $<name>=<default>
# in which  <name> is the name of the variable and <default> is the value
# used when there is NO current CGI value for <name> (you can use 
# white-spaces in $<name>=<default> but really DO make sure that the 
# default value is followed by white space or is quoted). Names can contain 
# any alphanumeric characters and _ (i.e., names match /[\w]+/).
# If the Content-type: is 'multipart/*', the input is treated as a
# MIME multipart message and automatically delimited. CGI variables get 
# the "raw" (i.e., undecoded) body of the corresponding message part. 
#
# Variables can be CGI variables, i.e., those from the QUERY_STRING, 
# environment variables, e.g., REMOTE_USER, REMOTE_HOST, or REMOTE_ADDR, 
# or predefined values, e.g., CGI_Decoded_QS (The complete, decoded, 
# query string), CGI_Content_Length (the length of the decoded query 
# string), CGI_Year, CGI_Month, CGI_Time, and CGI_Hour (the current 
# date and time).
# 
# All these are available when defined in a META tag. All environment 
# variables are accessible as $ENV{'name'}. So, to access the REMOTE_HOST 
# and the REMOTE_USER, use, e.g.: 
# 
# <SCRIPT TYPE='text/ssperl'>
# ($ENV{'REMOTE_HOST'}||"-")." $ENV{'REMOTE_USER'}"
# </SCRIPT>
# 
# (This will print a "-" if REMOTE_HOST is not known)
# Another way to do this is:
# 
# <META CONTENT="text/ssperl; CGI='$REMOTE_HOST = - $REMOTE_USER'">
# <SCRIPT TYPE='text/ssperl'>"$REMOTE_HOST $REMOTE_USER"</SCRIPT>
# or
# <META CONTENT='text/ssperl; CGI="$REMOTE_HOST = - $REMOTE_USER"
#  SRC={"$REMOTE_HOST $REMOTE_USER\n"}'>
#  
# This is possible because ALL environment variables are available as 
# CGI variables. The environment variables take precedence over CGI 
# names in case of a "name clash". For instance:  
# <META CONTENT="text/ssperl; CGI='$HOME' SRC={$HOME}">
# Will print the current HOME directory (environment) irrespective whether
# there is a CGI variable from the query 
# (e.g., Where do you live? <INPUT TYPE="TEXT" NAME="HOME">)
# THIS IS A SECURITY FEATURE. It prevents clients from changing
# the values of defined environment variables (e.g., by supplying
# a bogus $REMOTE_ADDR). Although $ENV{} is not changed by the META tags, 
# it would make the use of declared variables insecure. You can still 
# access CGI variables after a name clash with 
# CGIscriptor::CGIparseValue(<name>).
# 
# This method of first declaring your environment and CGI variables
# before being able to use them in the scripts might seem somewhat 
# clumsy, but it protects you from inadvertedly printing out the values of 
# system environment variables when their names coincide with those used 
# in the CGI forms. 
# THIS IS A SECURITY FEATURE!
#
#
# NON-HTML CONTENT TYPES
#
# Normally, CGIscriptor prints the standard "Content-type: text/html\n\n"
# message before anything is printed. When this is unwanted, e.g., with
# multipart files, use the $RawFilePattern (see also next item). 
# CGIscriptor will not print a Content-type message for this file type 
# (which must supply its OWN Content-type message). Raw files must still
# conform to the <SCRIPT></SCRIPT> and <META> tag specifications.
# 
# 
# NON-HTML FILES
# 
# CGIscriptor is intended to process HTML files only. You can create 
# documents of any mime-type on-the-fly using "raw" text files, e.g.,   
# with the .xmr extension. However, CGIscriptor will not process binary 
# files of any type, e.g., pictures or sounds. Given the sheer number of 
# formats, I do not have any intention to do so. However, an escape route 
# has been provided. You can construct a genuine raw (.xmr) text file that 
# contains the perl code to service any file type you want. If the 
# $BinaryMapFile variable contains the path to this file (e.g.,
# /BinaryMapFile.xmr), this  file will be called whenever an unsupported
# (non-HTML) file type is  requested. The path to the requested binary
# file is stored in  $ENV('CGI_BINARY_FILE') and can be used like any
# other CGI-variable. Servicing binary files then becomes supplying the
# correct Content-type (e.g., print "Content-type: image/jpeg\n\n";)
# and reading the file and writing it to STDOUT (e.g., using sysread() 
# and syswrite()).
# 
# 
# THE META TAG
# 
# All features of a META tag are ignored, except the 
# CONTENT='text/ssperl; CGI=" ... " [SRC=" ... "]' feature. The string
# inside the quotes following the CONTENT= indication (white-space is
# ignored, "'`-quotes are allowed) MUST start with the CGIscriptor 
# mime-type (here: text/ssperl or text/osshell) and a comma or semicolon. 
# The quoted string following CGI= contains a white-space separated list 
# of declarations of the CGI (and Environment) values and default values 
# used when no CGI values are supplied.
# If the default value is a longer string containing special characters, 
# possibly spanning several lines, the string must be enclosed in quotes. 
# You may use any pair of quotes or brackets from the list '', "", ``, (), 
# [], or {} to distinguish default values. The outermost pair will 
# always be used and any other quotes inside the string are considered 
# to be part of the string value, e.g., 
# $Value = {['this'
# "and" (this)]} 
# will result in $Value getting the default value ['this'
# "and" (this)]
# (NOTE that the newline is part of the default value!).
#
# Internally, for defining and initializing CGI (ENV) values, the META 
# tag uses the function "defineCGIvariable($name, $default)". 
# This function can be used inside scripts as 
# "CGIscriptor::defineCGIvariable($name, $default)".
#
#
# THE MAGIC SOURCE TAG (SRC=) INSIDE META AND SCRIPT TAGS
# 
# The SRC tag accepts a list of filenames separated by "," comma's
# (or ";" semicolons). 
# ALL the variable values defined in the PRECEDING META tag are 
# available in @ARGV as if the file was executed from the command 
# line, in the exact order in which they were declared in the 
# preceding META tag.
# 
# First, a SRC={}-block will be evaluated as if the code inside the 
# block was part of a <SCRIPT></SCRIPT> construct, i.e.,
# "print do { code };'';" or `code` (i.e., SAFEqx('code)). 
# Only a single block is evaluated. Note that this is processed less 
# efficiently than <SCRIPT> </SCRIPT> blocks. Type of evaluation 
# depends on the content-type: Perl for text/ssperl and OS shell for 
# text/osshell.
#
# Second, executable files (i.e., -x filename != 0) are evaluated as:
# print `filename \'$ARGV[0]\' \'$ARGV[1]\' ...`
# That is, you can actually call executables savely from the SRC tag.
# 
# Third, text files that match the file pattern, used by CGIscriptor to
# check whether files should be processed ($FilePattern), are 
# processed in-line (i.e., recursively) by CGIscriptor as if the code
# was inserted in the original source file. Recursions, i.e., calling
# a file inside itself, are blocked. If you need them, you have to code
# them explicitely using "main::ProcessFile($file_path)".
# 
# Fourth, Perl text files (i.e., -T filename != 0) are evaluated as: 
# "do FileName;'';".
# 
# Example:
# The request 
# "http://cgi-bin/Action_Forms.pl/Statistics/Sign_Test.html?positive=8&negative=22
# will result in printing "${SS_PUB}/Statistics/Sign_Test.html"
# With QUERY_STRING = "positive=8&negative=22"
#
# on encountering the lines:
# <META CONTENT="text/osshell; CGI='$positive=11 $negative=3'">
# <b><SCRIPT LANGUAGE=PERL TYPE="text/ssperl" SRC="./Statistics/SignTest.pl">
#  </SCRIPT></b><p>"
#
# This line will be processed as:
# "<b>`${SS_SCRIPT}/Statistics/SignTest.pl '8' '22'`</b><p>"
#
# In which "${SS_SCRIPT}/Statistics/SignTest.pl" is an executable script, 
# This line will end up printed as:
# "<b>p <= 0.0161</b><p>"
#
# Note that the META tag itself will never be printed, and is invisible to 
# the outside world.
# 
# 
# THE CGISCRIPTOR ROOT DIRECTORIES ~/ AND ./
# 
# Inside <SCRIPT></SCRIPT> tags and SRC-features, filepaths starting 
# with "~/" are replaced by "$YOUR_HTML_FILES/", this way files in the 
# public directories can be accessed without direct reference to the 
# actual paths (for security reasons this does NOT work in SRC tags). 
# Filepaths starting with "./" are replaced by "$YOUR_SCRIPTS/" and 
# this should only be used for scripts (this DOES work in SRC tags). 
#
# CGIscriptor.pl will assign the values of $SS_PUB and $SS_SCRIPT
# (i.e., $YOUR_HTML_FILES and $YOUR_SCRIPTS) to the environment variables 
# $SS_PUB and $SS_SCRIPT. These can be accessed by the scripts that are 
# executed.
# Values not preceded by $, ~/, or ./ are used as literals 
#
#
# OS SHELL SCRIPT EVALUATION (CONTENT-TYPE=TEXT/OSSHELL)
#
# OS scripts are executed by a "safe" version of the `` operator (i.e., 
# SAFEqx(), see also below) and any output is printed. CGIscriptor will 
# interpolate the script and replace all user-supplied CGI-variables by 
# their ''-quoted values (actually, all variables defined in META tags are 
# quoted). Other Perl variables are interpolated in a simple fasion, i.e., 
# $scalar by their value, @list by join(' ', @list), and %hash by their 
# name=value pairs. Complex references, e.g., @$variable, are all 
# evaluated in a scalar context. Quotes should be used with care. 
# NOTE: the results of the shell script evaluation will appear in the
# @CGIscriptorResults stack just as any other result.
# All occurrences of $@% that should NOT be interpolated must be 
# preceeded by a "\". Interpolation can be switched off completely by 
# setting $CGIscriptor::NoShellScriptInterpolation = 1
# (set to 0 or undef to switch interpolation on again)
# i.e.,
# <SCRIPT TYPE="text/ssperl">
# $CGIscriptor::NoShellScriptInterpolation = 1;
# </SCRIPT>
#
#
# SHELL SCRIPT PIPING
# 
# If a shell script starts with the UNIX style "#! <shell command> \n"
# line, the rest of the shell script is piped into the indicated command, 
# i.e.,
# open(COMMAND, "| command");print COMMAND $RestOfScript; 
# 
# Execution of shell scripts is under the control of the Perl Script blocks
# in the document. You can switch to a different shell, e.g. tcl, 
# completely by executing the following Perl commands inside your document:
# 
# <SCRIPT TYPE="text/ssperl">
# $main::ShellScriptContentType = "text/ssTcl";     # Yes, you can do this
# CGIscriptor::RedirectShellScript('/usr/bin/tcl'); # Pipe to Tcl
# $CGIscriptor::NoShellScriptInterpolation = 1;
# </SCRIPT>
# 
# After this script is executed, CGIscriptor will parse scripts of
# TYPE="text/ssTcl" and pipe their contents into '|/usr/bin/tcl'
# WITHOUT interpolation (i.e., NO substitution of Perl variables).
# The crucial function is :
# CGIscriptor::RedirectShellScript('/usr/bin/tcl')
# After executing this function, all shell scripts AND all 
# calls to SAFEqx()) are piped into '|/usr/bin/tcl'. If the argument 
# of RedirectShellScript is empty, e.g., '', the original (default) 
# value is reset.
#  
# The standard output, STDOUT, of any pipe is send to the client. 
# Currently, you should be carefull with quotes in such a piped script.
# The results of a pipe is NOT put on the @CGIscriptorResults stack.
# As a result, you do not have access to the output of any piped (#!)
# process! If you want such access, execute 
# <SCRIPT TYPE="text/osshell">echo "script"|command</SCRIPT> 
# or  
# <SCRIPT TYPE="text/ssperl">
# $resultvar = SAFEqx('echo "script"|command');
# </SCRIPT>.
#
# Safety is never complete. Although SAFEqx() prevents some of the 
# most obvious forms of attacks and security slips, it cannot prevent 
# them all. Especially, complex combinations of quotes and intricate 
# variable references cannot be handled safely by SAFEqx. So be on  
# guard.
#
#
# PERL CODE EVALUATION (CONTENT-TYPE=TEXT/SSPERL)
#
# All PERL scripts are evaluated inside a PERL package. This package 
# has a separate name space. This isolated name space protects the 
# CGIscriptor.pl program against interference from user code. However, 
# some variables, e.g., $_, are global and cannot be protected. You are 
# advised NOT to use such global variable names. You CAN write 
# directives that directly access the variables in the main program. 
# You do so at your own risk (there is definitely enough rope available 
# to hang yourself). The behavior of CGIscriptor becomes undefined if 
# you change its private variables during run time. The PERL code 
# directives are used as in: 
# $Result = eval($directive); print $Result;'';
# ($directive contains all text between <SCRIPT></SCRIPT>).
# That is, the <directive> is treated as ''-quoted string and
# the result is treated as a scalar. To prevent the VALUE of the code
# block from appearing on the client's screen, end the directive with 
# ';""</SCRIPT>'. Evaluated directives return the last value, just as 
# eval(), blocks, and subroutines, but only as a scalar.
#
# IMPORTANT: All PERL variables defined are persistent. Each <SCRIPT>
# </SCRIPT> construct is evaluated as a {}-block with associated scope
# (e.g., for "my $var;" declarations). This means that values assigned 
# to a PERL variable can be used throughout the document unless they
# were declared with "my". The following will actually work as intended 
# (note that the ``-quotes in this example are NOT evaluated, but used 
# as simple quotes):
# 
# <META CONTENT="text/ssperl; CGI=`$String='abcdefg'`">
# anything ...
# <SCRIPT TYPE=text/ssperl>@List = split('', $String);</SCRIPT>
# anything ...
# <SCRIPT TYPE=text/ssperl>join(", ", @List[1..$#List]);</SCRIPT>
# 
# The first <SCRIPT TYPE=text/ssperl></SCRIPT> construct will return the 
# value scalar(@List), the second <SCRIPT TYPE=text/ssperl></SCRIPT> 
# construct will print the elements of $String separated by commas, leaving 
# out the first element, i.e., $List[0].
#
#
# USER EXTENSIONS
#
# A CGIscriptor package is attached to the bottom of this file. With
# this package you can personalize your version of CGIscriptor by 
# including often used perl routines. These subroutines can be 
# accessed by prefixing their names with CGIscriptor::, e.g., 
# <SCRIPT LANGUAGE=PERL TYPE=text/ssperl> 
# CGIscriptor::ListDocs("/Books/*") # List all documents in /Books
# </SCRIPT>
# It already contains some useful subroutines for Document Management.
# As it is a separate package, it has its own namespace, isolated from
# both the evaluator and the main program. To access variables from
# the document <SCRIPT></SCRIPT> blocks, use $CGIexecute::<var>. 
# 
# Currently, the following functions are implemented 
# (precede them with CGIscriptor::, see below for more information)
# - SAFEqx ('String') -> result of qx/"String"/ # Safe application of ``-quotes
#   Is used by text/osshell Shell scripts. Protects all CGI 
#   (client-supplied) values with single quotes before executing the 
#   commands (one of the few functions that also works WITHOUT CGIscriptor:: 
#   in front)
# - defineCGIvariable ($name[, $default) -> 0/1 (i.e., failure/success)
#   Is used by the META tag to define and initialize CGI and ENV 
#   name/value pairs. Tries to obtain an initializing value from (in order):
#   $ENV{$name}
#   The Query string
#   The default value given (if any)
#   (one of the few functions that also works WITHOUT CGIscriptor:: 
#   in front)
# - CGIsafeFileName (FileName) -> FileName or ""
#   Check a string against the Allowed File Characters (and ../ /..).
#   Returns an empty string for unsafe filenames.
# - CGIsafeEmailAddress (Email) -> Email or ""
#   Check a string against correct email address pattern.
#   Returns an empty string for unsafe addresses.
# - RedirectShellScript ('CommandString') -> FILEHANDLER or undef
#   Open a named PIPE for SAFEqx to receive ALL shell scripts
# - URLdecode (URL encoded string) -> plain string # Decode URL encoded argument
# - URLencode (plain string) -> URL encoded string # Encode argument as URL code
# - CGIparseValue (ValueName [, URL_encoded_QueryString]) -> Decoded value
#   Extract the value of a CGI variable from the global or a private 
#   URL-encoded query (multipart POST raw, NOT decoded)
# - CGIparseHeader (ValueName [, URL_encoded_QueryString]) -> Header
#   Extract the header of a multipart CGI variable from the global or a private 
#   URL-encoded query ("" when not a multipart variable or absent)
# - CGIparseForm ([URL_encoded_QueryString]) -> Decoded Form
#   Decode the complete global URL-encoded query or a private 
#   URL-encoded query
# - BrowseDirs(RootDirectory [, Pattern, Startdir, CGIname]) # print browsable directories
# - ListDocs(Pattern [,ListType])  # Prints a nested HTML directory listing of 
#   all documents, e.g., ListDocs("/*", "dl");.
# - HTMLdocTree(Pattern [,ListType])  # Prints a nested HTML listing of all 
#   local links starting from a given document, e.g., 
#   HTMLdocTree("/Welcome.html", "dl");
#
#
# THE RESULTS STACK: @CGISCRIPTORRESULTS
# 
# If the pseudo-variable "$CGIscriptorResults" has been defined in a
# META tag, all subsequent SCRIPT and META results are pushed 
# on the @CGIscriptorResults stack. This list is just another
# Perl variable and can be used and manipulated like any other list.
# $CGIscriptorResults[-1] is always the last result.
# This is only of limited use, e.g., to use the results of an OS shell
# script inside a Perl script.
#
#
# USEFULL CGI PREDEFINED VARIABLES (DO NOT ASSIGN TO THESE)
#
# $CGI_HOME - The ServerRoot directory
# $CGI_Decoded_QS - The complete decoded Query String
# $CGI_Content_Length - The ACTUAL length of the Query String
# $CGI_Date - Current date and time
# $CGI_Year $CGI_Month $CGI_Day $CGI_WeekDay - Current Date
# $CGI_Time - Current Time
# $CGI_Hour $CGI_Minutes $CGI_Seconds - Current Time, split
# GMT Date/Time:
# $CGI_GMTYear $CGI_GMTMonth $CGI_GMTDay $CGI_GMTWeekDay $CGI_GMTYearDay 
# $CGI_GMTHour $CGI_GMTMinutes $CGI_GMTSeconds $CGI_GMTisdst
# 
#
# USEFULL CGI ENVIRONMENT VARIABLES
#
# Variables accessible (in APACHE) as $ENV{<name>}
# (see: "http://hoohoo.ncsa.uiuc.edu/cgi/env.html"):
#
# QUERY_STRING - The query part of URL, that is, everything that follows the 
#                question mark.
# PATH_INFO    - Extra path information given after the script name
# PATH_TRANSLATED - Extra pathinfo translated through the rule system. 
#                   (This doesn't always make sense.)
# REMOTE_USER  - If the server supports user authentication, and the script is 
#                protected, this is the username they have authenticated as.
# REMOTE_HOST  - The hostname making the request. If the server does not have 
#                this information, it should set REMOTE_ADDR and leave this unset
# REMOTE_ADDR  - The IP address of the remote host making the request.
# REMOTE_IDENT - If the HTTP server supports RFC 931 identification, then this 
#                variable will be set to the remote user name retrieved from 
#                the server. Usage of this variable should be limited to logging 
#                only. 
# AUTH_TYPE    - If the server supports user authentication, and the script 
#                is protected, this is the protocol-specific authentication 
#                method used to validate the user. 
# CONTENT_TYPE - For queries which have attached information, such as HTTP 
#                POST and PUT, this is the content type of the data.   
# CONTENT_LENGTH - The length of the said content as given by the client.
# SERVER_SOFTWARE - The name and version of the information server software 
#                   answering the request (and running the gateway). 
#                   Format: name/version
# SERVER_NAME  - The server's hostname, DNS alias, or IP address as it 
#                   would appear in self-referencing URLs
# GATEWAY_INTERFACE - The revision of the CGI specification to which this 
#                     server complies. Format: CGI/revision
# SERVER_PROTOCOL - The name and revision of the information protocol this 
#                   request came in with. Format: protocol/revision
# SERVER_PORT  - The port number to which the request was sent.
# REQUEST_METHOD - The method with which the request was made. For HTTP, 
#                  this is "GET", "HEAD", "POST", etc. 
# SCRIPT_NAME  - A virtual path to the script being executed, used for 
#                self-referencing URLs.
# HTTP_ACCEPT  - The MIME types which the client will accept, as given by 
#                HTTP headers. Other protocols may need to get this 
#                information from elsewhere. Each item in this list should 
#                be separated by commas as per the HTTP spec. 
#                Format: type/subtype, type/subtype  
# HTTP_USER_AGENT - The browser the client is using to send the request. 
#                General format: software/version library/version. 
#
#
# NON-UNIX PLATFORMS
# 
# CGIscriptor.pl was mainly developed and tested on UNIX. However, as I 
# coded part of the time on an Apple Macintosh under MacPerl, I made sure
# CGIscriptor did run under MacPerl (with command line options).  But only
# as an independend script, not as part of a HTTP server.
# 
# As far as I have been able to test it, the only change to be made is
# uncommenting the line "$DirectorySeparator = ':';    # Mac" in the
# configuration part (and commenting out the UNIX part). If your server
# does not convert the URL PATH_INFO into MacOS directory paths, you
# must make sure that the line "$file_path =~ s@/@$DirectorySeparator@isg;"
# in the Initialize_output() function is not commented out (it is useless
# under UNIX).
# 
# The same should be possible under Microsoft Windows/NT. However, I 
# have never run CGIscriptor.pl under any of the MS OS's.
#
###############################################################################
#
# SECURITY CONFIGURATION
#
# Special configurations related to SECURITY 
# (i.e., optional, see also environment variables below)
#
# LOGGING
# Log Clients and the requested paths (Redundant when loging Queries)
# 
$ClientLog = "./Client.log"; # (uncomment for use)
#
# Format: Localtime | REMOTE_USER REMOTE_IDENT REMOTE_HOST REMOTE_ADDRESS \
# PATH_INFO CONTENT_LENGTH  (actually, the real query+post length)
#                         
# Log Clients and the queries, the CGIQUERYDECODE is required if you want
# to log queries. If you log Queries, the loging of Clients is redundant
# (note that queries can be quite long, so this might not be a good idea)
# 
#$QueryLog = "./Query.log"; # (uncomment for use)                       
#
# ACCESS CONTROL 
# the Access files should contain Hostnames or IP addresses, 
# i.e. REMOTE_HOST or REMOTE_ADDR, each on a separate line
# optionally followed by one ore more file patterns, e.g., "edu /DEMO". 
# Matching is done "domain first". For example ".edu" matches all 
# clients whose "name" ends in ".edu" or ".EDU". The file pattern 
# "/DEMO" matches all paths that contain the strings "/DEMO" or "/demo" 
# (both matchings are done case-insensitive).
# The name special symbol "-" matches ALL clients who do not supply a 
# REMOTE_HOST name, "*" matches all clients.
# Lines starting with '-e' are evaluated. A non-zero return value indicates 
# a match. You can use $REMOTE_HOST, $REMOTE_ADDR, and $PATH_INFO. These
# lines are evaluated in the program's own name-space. So DO NOT assign to 
# variables.
#
# Accept the following users (remove comment # and adapt filename)
#$CGI_Accept = "~/CGIscriptorAccept.lis"; # (uncomment for use)
#
# Reject requests from the following users (remove comment # and 
# adapt filename, this is only of limited use)
#$CGI_Reject = "~/CGIscriptorReject.lis"; # (uncomment for use)
#
# Empty lines or comment lines starting with '#' are ignored in both 
# $CGI_Accept and $CGI_Reject.
#
# End of security configuration
#
###############################################################################
# 
# PARSING CGI VALUES FROM THE QUERY STRING (USER CONFIGURABLE)
# 
# The CGI parse commands. These commands extract the values of the 
# CGI variables from the URL encoded Query String.
# If you want to use your own CGI decoders, you can call them here 
# instead, using your own PATH and commenting/uncommenting the 
# appropriate lines
# 
# CGI parse command for individual values
sub YOUR_CGIPARSE   # ($Name) -> Decoded value
{ 
    my $Name = shift;
    # Use one of the following by uncommenting
    return CGIscriptor::CGIparseValue($Name);# Defined in CGIscriptor below
    # return `/PATH/cgiparse -value $Name`;  # Shell commands
    # require "/PATH/cgiparse.pl"; return cgivalue($Name); # Library
}
# Complete queries
sub YOUR_CGIQUERYDECODE 
{
    # Use one of the following by uncommenting
    return CGIscriptor::CGIparseForm(); # Defined in CGIscriptor below
    # return `/PATH/cgiparse -form`;   # Shell commands
    # require "/PATH/cgiparse.pl"; return cgiform(); # Library
}
#
# End of CGI parsing configuration
#   
###############################################################################
#
# Initialization Code
# 
#   
sub Initialize_Request
{
    ###############################################################################
    #
    # ENVIRONMENT VARIABLES
    #
    # Use environment variables to configure CGIscriptor on a temporary basis.
    # If you define any of the configurable variables as environment variables, 
    # these are used instead of the "hard coded" values above.
    #
    $SS_PUB = $ENV{'SS_PUB'} || $YOUR_HTML_FILES;
    $SS_SCRIPT = $ENV{'SS_SCRIPT'} || $YOUR_SCRIPTS;
    
    #
    # Substitution strings, these are used internally to handle the
    # directory separator strings, e.g., '~/' -> 'SS_PUB:' (Mac)
    $HOME_SUB = $SS_PUB;
    $SCRIPT_SUB = $SS_SCRIPT;
    
    # Add the directory separator to the "home" directories. 
    # (This is required for ~/ and ./ substitution)
    $HOME_SUB .= $DirectorySeparator if $HOME_SUB;
    $SCRIPT_SUB .= $DirectorySeparator if $SCRIPT_SUB;
    
    $ENV{'PATH_TRANSLATED'} =~ /$ENV{'PATH_INFO'}/is;
    $CGI_HOME = $`;    # Get the SERVER_ROOT directory
    $default_values{'CGI_HOME'} = $CGI_HOME;
    $ENV{'HOME'} = $CGI_HOME;
    # Set SS_PUB and SS_SCRIPT as Environment variables (make them available
    # to the scripts)
    $ENV{'SS_PUB'} = $SS_PUB unless $ENV{'SS_PUB'};
    $ENV{'SS_SCRIPT'} = $SS_SCRIPT unless $ENV{'SS_SCRIPT'};
    #
    $FilePattern = $ENV{'FilePattern'} || $FilePattern;
    $MaximumQuerySize = $ENV{'MaximumQuerySize'} || $MaximumQuerySize;
    $ClientLog = $ENV{'ClientLog'} || $ClientLog;
    $QueryLog = $ENV{'QueryLog'} || $QueryLog;
    $CGI_Accept = $ENV{'CGI_Accept'} || $CGI_Accept;
    $CGI_Reject = $ENV{'CGI_Reject'} || $CGI_Reject;
    #
    # Parse file names
    $CGI_Accept =~ s@^\~/@$HOME_SUB@g if $CGI_Accept;
    $CGI_Reject =~ s@^\~/@$HOME_SUB@g if $CGI_Reject;
    $ClientLog =~ s@^\~/@$HOME_SUB@g if $ClientLog;
    $QueryLog =~ s@^\~/@$HOME_SUB@g if $QueryLog;
    
    $CGI_Accept =~ s@^\./@$SCRIPT_SUB@g if $CGI_Accept;
    $CGI_Reject =~ s@^\./@$SCRIPT_SUB@g if $CGI_Reject;
    $ClientLog =~ s@^\./@$SCRIPT_SUB@g if $ClientLog;
    $QueryLog =~ s@^\./@$SCRIPT_SUB@g if $QueryLog;

    @CGIscriptorResults = ();  # A stack of results
    #
    # end of Environment variables
    #
    #############################################################################
    #
    # Define and Store "standard" values
    #
    # BEFORE doing ANYTHING check the size of Query String
    length($ENV{'QUERY_STRING'}) <= $MaximumQuerySize || die "QUERY TOO LONG\n";
    #
    # The Translated Query String and the Actual length of the (decoded) 
    # Query String
    if($ENV{'QUERY_STRING'})
    { 
	# If this can contain '`"-quotes, be carefull to use it QUOTED
	$default_values{CGI_Decoded_QS} = YOUR_CGIQUERYDECODE();
	$default_values{CGI_Content_Length} = length($default_values{CGI_Decoded_QS});
    };
    #
    # Get the current Date and time and store them as default variables
    #
    # Get Local Time
    $LocalTime = localtime;
    #
    # CGI_Year CGI_Month CGI_Day CGI_WeekDay CGI_Time 
    # CGI_Hour CGI_Minutes CGI_Seconds
    # 
    $default_values{CGI_Date} = $LocalTime;
    ($default_values{CGI_WeekDay}, 
    $default_values{CGI_Month}, 
    $default_values{CGI_Day}, 
    $default_values{CGI_Time}, 
    $default_values{CGI_Year}) = split(' ', $LocalTime);
    ($default_values{CGI_Hour}, 
    $default_values{CGI_Minutes}, 
    $default_values{CGI_Seconds}) = split(':', $default_values{CGI_Time});
    #
    # GMT:
    # CGI_GMTYear CGI_GMTMonth CGI_GMTDay CGI_GMTWeekDay CGI_GMTYearDay 
    # CGI_GMTHour CGI_GMTMinutes CGI_GMTSeconds CGI_GMTisdst
    #
    ($default_values{CGI_GMTSeconds}, 
    $default_values{CGI_GMTMinutes}, 
    $default_values{CGI_GMTHour}, 
    $default_values{CGI_GMTDay}, 
    $default_values{CGI_GMTMonth}, 
    $default_values{CGI_GMTYear}, 
    $default_values{CGI_GMTWeekDay}, 
    $default_values{CGI_GMTYearDay}, 
    $default_values{CGI_GMTisdst}) = gmtime;
    #
}
#
# End of Initialize Request
#
############################################################################
#
# SECURITY: ACCESS CONTROL
#
# Check the credentials of each client (use pattern matching, domain first).
# This subroutine will kill-off (die) the current process whenever access 
# is denied.

sub Access_Control
{
    # 
    # ACCEPTED CLIENTS
    #
    # Only accept clients which are authorized, reject all unnamed clients
    # if REMOTE_HOST is given.
    # If file patterns are given, check whether the user is authorized for 
    # THIS file.
    if($CGI_Accept)
    { 
	# Use local variables, REMOTE_HOST becomes '-' if undefined
	my $REMOTE_HOST = $ENV{REMOTE_HOST} || '-';
	my $REMOTE_ADDR = $ENV{REMOTE_ADDR};
	my $PATH_INFO = $ENV{'PATH_INFO'};
	
	open(CGI_Accept, "<$CGI_Accept");
	$NoAccess = 1;
	while($NoAccess && <CGI_Accept>)
	{ 
	    next unless /\S/;  # Skip empty lines
	    next if /^\s*\#/;  # Skip comments
	    
	    # Full expressions
	    if(/^\s*-e\s/is)
	    {
		my $Accept = $';  # Get the expression
		$NoAccess &&= eval($Accept);  # evaluate the expresion
	    }
	    else
	    {
		my ($Accept, @FilePatternList) = split;
		if($Accept eq '*'               # Always match
		 ||$REMOTE_HOST =~ /\Q$Accept\E$/is        # REMOTE_HOST matches
		 || (
		 $Accept =~ /^[0-9\.]+$/ 
		 && $REMOTE_ADDR =~ /^\Q$Accept\E/ # IP address matches
		 )
		)
		{ 
		    if($FilePatternList[0])
		    {  
			foreach $Pattern (@FilePatternList)
			{ 
			    # Check whether this patterns is accepted
			    $NoAccess &&= ($PATH_INFO !~ m@\Q$Pattern\E@is);	
			};
		    }
		    else
		    {  
			$NoAccess = 0;   # No file patterns -> Accepted
		    };
		};
	    };
	};
	close(CGI_Accept);
	if($NoAccess){ die "No Access: $PATH_INFO\n";};
    };
    #
    # 
    # REJECTED CLIENTS
    #
    # Reject named clients, accept all unnamed clients
    if($CGI_Reject)
    { 
	# Use local variables, REMOTE_HOST becomes '-' if undefined
	my $REMOTE_HOST = $ENV{'REMOTE_HOST'} || '-';
	my $REMOTE_ADDR = $ENV{'REMOTE_ADDR'};
	my $PATH_INFO = $ENV{'PATH_INFO'};
	
	open(CGI_Reject, "<$CGI_Reject");
	$NoAccess = 0;
	while(!$NoAccess && <CGI_Reject>)
	{ 
	    next unless /\S/;  # Skip empty lines
	    next if /^\s*\#/;     # Skip comments
	    
	    # Full expressions
	    if(/^-e\s/is)
	    {
		my $Reject = $';  # Get the expression
		$NoAccess ||= eval($Reject);  # evaluate the expresion
	    }
	    else
	    {
		my ($Reject, @FilePatternList) = split;
		if($Reject eq '*'                     # Always match
		 ||$REMOTE_HOST =~ /\Q$Reject\E$/is   # REMOTE_HOST matches
		 ||($Reject =~ /^[0-9\.]+$/ 
		 && $REMOTE_ADDR =~ /^\Q$Reject\E/is  # IP address matches
		 )
		)
		{ 
		    if($FilePatternList[0])
		    {  
			foreach $Pattern (@FilePatternList)
			{ 
			    $NoAccess ||= ($PATH_INFO =~ m@\Q$Pattern\E@is);
			};
		    }
		    else
		    {  
			$NoAccess = 1;    # No file patterns -> Rejected
		    };
		};
	    };
	};
	close(CGI_Reject);
	if($NoAccess){ die "Request rejected: $PATH_INFO\n";};
    };
    #
    ############################################################################
    #
    #
    # Get the filename
    #
    # Does the filename contain any illegal characters (e.g., |, >, or <)
    die "Illegal request\n" if $ENV{'PATH_INFO'} =~ /[^$FileAllowedChars]/;
	# Does the pathname contain an illegal (blcoked) "directory"
	die "Illegal request\n" if $BlockPathAccess && $ENV{'PATH_INFO'} =~ m@$BlockPathAccess@;  # Access is blocked
    
    # SECURITY: Is PATH_INFO allowed?
    if($FilePattern && $ENV{'PATH_INFO'} && 
	($ENV{'PATH_INFO'} !~ m@($FilePattern)$@is)) 
    {
	# Unsupported file types can be processed by a special raw-file
	if($BinaryMapFile)
	{
	    $ENV{'CGI_BINARY_FILE'} = $ENV{'PATH_INFO'};
	    $ENV{'PATH_INFO'} = $BinaryMapFile;	    
	}
	else
	{
	    die "Illegal file\n"; 
	};
    };
    
}
#
# End of Security Access Control
# 
#
############################################################################
#
# Start (HTML) output and logging
# (if there are irregularities, it can kill the current process)
#
#
sub Initialize_output
{
    my $file_path = $SS_PUB . $ENV{'PATH_INFO'}; # Construct the REAL file path
    $file_path =~ s/\?.*$//;                  # Remove query
    # This is only necessary if your server does not catch ../ directives
    $file_path !~ m@\.\./@ || die; # SECURITY: Do not allow ../ constructs
    
    # Change URL's into file directory paths (ONLY necessary if your 
    # NON-UNIX OS HTTP server does NOT take care of it).
    $file_path =~ s@/@$DirectorySeparator@isg;
    
    #
    #
    # If POST, Read data from stdin to QUERY_STRING
    if($ENV{'REQUEST_METHOD'} =~ /POST/is)
    {
	# SECURITY: Check size of Query String
	$ENV{'CONTENT_LENGTH'} <= $MaximumQuerySize || die;  # Query too long
	my $QueryRead = 0;
	my $SystemRead = $ENV{'CONTENT_LENGTH'};
	while($SystemRead > 0)
	{
	    $QueryRead = sysread(STDIN, $Post, $SystemRead); # Limit length
	    $ENV{'QUERY_STRING'} .= $Post;
	    $SystemRead -= $QueryRead;
	};
	# Update decoded Query String
	$default_values{CGI_Decoded_QS} = YOUR_CGIQUERYDECODE();
	$default_values{CGI_Content_Length} = 
	length($default_values{CGI_Decoded_QS});
    };
    #
    #
    if($ClientLog)
    {
	open(ClientLog, ">>$ClientLog");
	print ClientLog  "$LocalTime | ",
	($ENV{REMOTE_USER} || "-"), " ",
	($ENV{REMOTE_IDENT} || "-"), " ",
	($ENV{REMOTE_HOST} || "-"), " ",
	$ENV{REMOTE_ADDR}, " ",
	$ENV{PATH_INFO}, " ", 
	($default_values{CGI_Content_Length} || "-"),
	"\n";
	close(ClientLog);
    };
    if($QueryLog)
    {
	open(QueryLog, ">>$QueryLog");
	print QueryLog  "$LocalTime\n", 
	($ENV{REMOTE_USER} || "-"), " ",
	($ENV{REMOTE_IDENT} || "-"), " ",
	($ENV{REMOTE_HOST} || "-"), " ",
	$ENV{REMOTE_ADDR}, ": ",
	$ENV{PATH_INFO}, "\n";
	#
	# Write Query to Log file
	print QueryLog $default_values{CGI_Decoded_QS}, "\n\n";
	close(QueryLog);
    };
    #
    # Return the file path
    return $file_path;
}
#
# End of Initialize output
# 
############################################################################
#
# Now, start with the real work
#
# Process a file
sub ProcessFile  # ($file_path)
{
    my $file_path = shift || return 0;

    # 
    my $FileHandle = "file";
    my $n = 0;
    while(!eof($FileHandle.$n)) {++$n;};
    $FileHandle .= $n;
    #
    # Start HTML output
    # Use the default Content-type if this is NOT a raw file
    unless(($RawFilePattern && $ENV{'PATH_INFO'} =~ m@($RawFilePattern)$@i)
            || $DefaultContentType)
    { 
	print "Content-type: text/html\n";
	print "\n";
	$DefaultContentType = 1;    # Content type has been printed
    };
    #
    # 
    # Open Only PLAIN TEXT files and NO executable files (i.e., scripts). 
    # THIS IS A SECURITY FEATURE!
    if( -e $file_path  && -r _ && -T _ && -f _ && ! (-x _ || -X _) )
    { 
	open($FileHandle, $file_path) || die "<h2>File not found</h2>\n";
	push(@OpenFiles, $file_path);
    }
    else
    { 
	print "<h2>File not found</h2>\n";
	die $file_path;
    };
    #
    $| = 1;    # Flush output buffers
    #
    # 
    # Send file to output
    my $METAarguments = "";  # The CGI arguments from the latest META tag
    my @METAvalues = ();  # The ''-quoted CGI values from the latest META tag
    #
    # Process the requested file
    while (<$FileHandle>)
    {
	# Catch <SCRIPT LANGUAGE="PERL" TYPE="text/ssperl" > directives in $_
	# There can be more than 1 <SCRIPT> or META tags on a line
	while(/\<\s*(SCRIPT|META)\s/is)
	{
	    my $directive = "";
	    # Store rest of line
	    my $Before = $`;
	    my $ScriptTag = $&;
	    my $After = $';
	    my $TagType = $1;
	    # The before part can be send to the output
	    print $Before;
	    # Read complete Tag from after and/or file
	    until($After =~ /([^\\])\>/)
	    { $After .= <$FileHandle>;};
	    
	    if($After =~ /([^\\])\>/)
	    {  
		$ScriptTag .= $`.$&;  # Keep the Script Tag intact
		$After = $';
	    }
	    else
	    {  
		die "Closing > not found";
	    };
	    #
	    # TYPE or NAME?
	    my $TypeName = ($TagType =~ /META/is) ? "CONTENT" : "TYPE";
	    # Parse <SCRIPT> or <META> directive
	    # If NOT (TYPE|CONTENT)="text/ssperl" (i.e., $ServerScriptContentType), 
	    # send the line to the output and go to the next loop
	    $ScriptTag =~ /$TypeName\s*=\s*([\"\']?)\s*([^\1\;\,\>\s]*)\s*[\1]?/is;
	    my $CurrentContentType = $2;
	    unless($CurrentContentType =~ 
	    /$ServerScriptContentType|$ShellScriptContentType/is)
	    {
		print $ScriptTag;
		$_ = $After;
		next;
	    };
	    #
	    # The META TAG, used to define the CGI variables
	    # Extract CGI-variables from 
	    # <META CONTENT="text/ssperl; CGI='' SRC=''"> tags
	    if($TagType =~ /META/is)		   
	    {
		$METAarguments = "";    # Reset the META CGI arguments
		@METAvalues = ();
		my $Meta_CGI = "";
		if($ScriptTag =~ /(CGI)\s*\=\s*(\w+)/is ||
		$ScriptTag =~ /CGI\s*\=\s*([\Q"'`\E])([^\1]*)$1/is)
		{ $Meta_CGI = $2;};
		
		# Process default values of variables ($<name> = 'default value')
		# Allowed quotes are '', "", ``, (), [], and {}
		while($Meta_CGI =~ /(^|[^\\])\$([\w]+)\s*\=\s*\'([^\']*)\'/is ||
		$Meta_CGI =~ /(^|[^\\])\$([\w]+)\s*\=\s*\"([^\"]*)\"/is ||
		$Meta_CGI =~ /(^|[^\\])\$([\w]+)\s*\=\s*\`([^\`]*)\`/is ||
		$Meta_CGI =~ /(^|[^\\])\$([\w]+)\s*\=\s*\(([^\(\)]*)\)/is ||
		$Meta_CGI =~ /(^|[^\\])\$([\w]+)\s*\=\s*\{([^\{\}]*)\}/is ||
		$Meta_CGI =~ /(^|[^\\])\$([\w]+)\s*\=\s*\[([^\[\]]*)\]/is ||
		$Meta_CGI =~ /(^|[^\\])\$([\w]+)\s*\=\s*(\S+)/is ||
		$Meta_CGI =~ /(^|[^\\])\$([\w]+)/is)
		{
		    my $name = $2;		    # The Name
		    my $default = $3;		# The default value
		    #
		    $Meta_CGI = $`.$1.$'; # Reconstruct the directive
		    #
		    # Define CGI (or ENV) variable, initalize it from the
		    # Query string or the default value
		    CGIexecute::defineCGIvariable($name, $default)
		    || die "INVALID CGI name/value pair ($name, $default)\n";
		    
		    # Store the values for internal and later use
		    $METAarguments .= "\$".$name.",";    # A string of CGI variable names
		    push(@METAvalues, "\'${$name}\'"); # ALWAYS add '-quotes around values
		};
		#
		# Construct the @ARGV array. This allows other (SRC=) Perl 
		# scripts to access the CGI arguments defined in the META tag
		chop($METAarguments);
		$directive .= '@ARGV = (' .$METAarguments.");\n" if $METAarguments; 
		$directive .= "'';\n";   # Now any result is not printed
	    };
	    # Extract any source script files and add them in 
	    # front of the directive
	    my $SRCtag = "";
	    if($ScriptTag =~ /SRC\s*=\s*($FileAllowedChars+)\s*/is ||
	    $ScriptTag =~ /SRC\s*=\s*\"([^\"]+)\"/is ||
	    $ScriptTag =~ /SRC\s*=\s*\'([^\']+)\'/is ||
	    $ScriptTag =~ /SRC\s*=\s*\`([^\`]+)\`/is ||
	    $ScriptTag =~ /SRC\s*=\s*(\{[^\}]+\})/is )
	    {
		$SRCtag = "$1;";
		# Expand script filenames "./Script"
		$SRCtag =~ s@([^\w\/\\]|^)\./([^\s\/\@\=])@$1$SCRIPT_SUB/$2@gis;
		#
		# File source tags
		while($SRCtag =~ /\S/is)
		{
		    # {}-blocks are just evaluated by "do"
		    if($SRCtag =~ /[\s\;\,]*\{/is)
		    {
			my $SRCblock = $';
			if($SRCblock =~ /\}[\s\;\,]*([^\}]*)$/is)
			{
			    $SRCblock = $`;
			    $SRCtag = $1.$';
			    if($CurrentContentType =~ /$ShellScriptContentType/is)
			    {
				# Handle ''-quotes inside the script
				$SRCblock =~ s/[\']/\\$&/gis;
				#
				$SRCblock = "SAFEqx(\'".$SRCblock."\')";
			    };		   
			    $directive .= "print do { $SRCblock};'';\n";
			    
			}
			else
			{ die "Closing \} missing\n";};
		    }
		    # Files are prcessed as Text or Executable files
		    elsif($SRCtag =~ /[\s\;\,]*([$FileAllowedChars]+)[\;\,\s]*/is)
		    {
			my $SrcFile = $1;
			$SRCtag = $';
			# 
			# Executable files are executed as 
			# `$SrcFile 'ARGV[0]' 'ARGV[1]'`
			if(-x $SrcFile)
			{
			    $directive .= "print \`$SrcFile @METAvalues\`;'';\n";
			}
			elsif(-T $SrcFile && $SrcFile =~ m@($FilePattern)$@) # A recursion
			{
			    #
			    # Do not process still open files because it can lead
			    # to endless recursions
			    if(grep(/^$SrcFile$/, @OpenFiles))
			    { die "$SrcFile allready opened (endless recursion)\n"};
			    #
			    $directive .= '@ARGV = (' .$METAarguments.");\n" if $METAarguments; 
			    $directive .= "main::ProcessFile(\'$SrcFile\');'';\n";
			}
			elsif(-T $SrcFile) # Textfiles are "do"-ed
			{
			    $directive .= '@ARGV = (' .$METAarguments.");\n" if $METAarguments; 
			    $directive .= "do \'$SrcFile\';'';\n";
			}
			else # This one could not be resolved
			{
			    $directive .= 'print "'.$SrcFile.' cannot be used"'."\n";
			};
		    };
		};
	    };
	    if($ScriptTag =~ /\<\s*SCRIPT\s/is)	# The <SCRIPT> TAG
	    {
		my $EndScriptTag = "";
		#
		# Execute SHELL scripts with SAFEqx()
		if($CurrentContentType =~ /$ShellScriptContentType/is)
		{
		    $directive .= "SAFEqx(\'";
		};		   
		#
		# Extract Program
		while($After !~ /\<\s*\/SCRIPT[^\>]*\>/is && !eof($FileHandle))
		{    $After .= <$FileHandle>};
		if($After =~ /\<\s*\/SCRIPT[^\>]*\>/is)
		{
		    
		    $directive .= $`;
		    $EndScriptTag = $&;
		    $After = $';
		}
		else
		{   
		    die "Missing </SCRIPT> end tag in $ENV{'PATH_INFO'}\n";
		};
		#
		# Remove all comments from Perl scripts 
		# (NOT from OS shell scripts)
		$directive =~ s/[^\\\$]\#[^\n\f\r]*([\n\f\r])/\1/g 
		unless $CurrentContentType =~ /$ShellScriptContentType/i;
		#
		# Convert SCRIPT calls, ./<script>
		$directive =~ s@([\W]|^)\./([\S])@$1$SCRIPT_SUB$2@g;
		#
		# Convert FILE calls, ~/<file>
		$directive =~ s@([\W])\~/([\S])@$1$HOME_SUB$2@g;
		#
		# Execute SHELL scripts with SAFEqx(), closing bracket
		if($CurrentContentType =~ /$ShellScriptContentType/i)
		{
		    # Handle ''-quotes inside the script
		    $directive =~ /SAFEqx\(\'/;
		    $directive = $`.$&;
		    my $Executable = $';
		    $Executable =~ s/[\']/\\$&/gs;
		    #
		    $directive .= $Executable."\');";  # Closing bracket
		};		   
	    };
	    #
	    # EXECUTE the script and print the results
	    #
	    # Use this to debug the program
	    # print STDERR "Directive: \n", $directive, "\n\n";
	    #
	    my $Result = CGIexecute->evaluate($directive); # Evaluate as PERL code
	    $Result =~ s/\n$//g;            # Remove final newline
	    #
	    # Print the Result of evaluating the directive
	    print $Result;
	    #
	    # Store result if wanted, i.e., if $CGIscriptorResults has been
	    # defined in a <META> tag.
	    push(@CGIexecute::CGIscriptorResults, $Result) 
	    if exists($default_values{'CGIscriptorResults'});
	    #
	    # Process the rest of the input line (this could contain 
	    # another directive)
	    $_ = $After;
	};
	print $_;
    };
    close ($FileHandle);
    die "Error in recursion\n" unless pop(@OpenFiles) == $file_path;
}
#   
###############################################################################
#
# Call the whole package
#
sub Handle_Request
{
    my $file_path = "";
    
    # Initialization Code
    Initialize_Request();
    
    # SECURITY: ACCESS CONTROL
    Access_Control();
    
    # Start (HTML) output and logging
    $file_path = Initialize_output();
    
    # Record which files are still open (to avoid endless recursions)
    my @OpenFiles = (); 

    # Record whether the default HTML ContentType has already been printed
    my $DefaultContentType = 0;

    # Process the specified file
    ProcessFile($file_path) if $file_path ne $SS_PUB;
    #
    ""  # SUCCESS
}
#
# Make a single call to handle an (empty) request
Handle_Request();
#
#
# END OF PACKAGE MAIN
#
#
####################################################################################
#
# The CGIEXECUTE PACKAGE
#
####################################################################################
#
# Isolate the evaluation of directives as PERL code from the rest of the program.
# Remember that each package has its own name space. 
# Note that only the FIRST argument of execute->evaluate is actually evaluated,
# all other arguments are accessible inside the first argument as $_[0] to $_[$#_].
#
package CGIexecute;

sub evaluate
{
    my $self = shift;
    my $directive = shift;
    $directive = eval($directive);
    warn $@ if $@;                  # Write an error message to STDERR
    $directive;                     # Return value of directive 
}

#
# defineCGIvariable($name [, $default]) -> 0/1
#
# Define and intialize CGI variables
# Tries (in order) $ENV{$name}, the Query string and the
# default value. 
# Removes all '-quotes etc.
#
sub defineCGIvariable	# ($name [, $default]) -> 0/1
{
    my $name = shift || return 0;		    # The Name
    my $default = shift || "";		# The default value
    # Remove \-quoted characters
    $default =~ s/\\(.)/$1/g;
    # Store default values
    $::default_values{$name} = $default if $default;         

    # Process variables
    my $temp = undef;
    # If there is a user supplied value, it replaces the 
    # default value.
    #
    # Environment values have precedence
    if(exists($ENV{$name}))
    {
	$temp = $ENV{$name};
    }
    # Get name and its value from the query string
    elsif($ENV{QUERY_STRING} =~ /$name/) # $name is in the query string
    { 
	$temp = ::YOUR_CGIPARSE($name);
    }
    # Defined values must exist for security
    elsif(!exists($::default_values{$name}))
    {
	$::default_values{$name} = undef;
    };
    #
    # SECURITY, do not allow '- and `-quotes in 
    # client values. 
    # Remove all existing '-quotes
    $temp =~ s/([\r\f]+\n)/\n/g;                # Only \n is allowed			   
    $temp =~ s/[\']/&#8217;/igs;		# Remove all single quotes
    $temp =~ s/[\`]/&#8216;/igs;		# Remove all backtick quotes
    # If $temp is empty, use the default value (if it exists)
    unless($temp =~ /\S/ || length($temp) > 0)	# I.e., $temp is empty
    {  
	$temp = $::default_values{$name};
	# Remove all existing '-quotes
	$temp =~ s/([\r\f]+\n)/\n/g; # Only \n is allowed			   
	$temp =~ s/[\']/&#8217;/igs;		# Remove all single quotes
	$temp =~ s/[\`]/&#8216;/igs;		# Remove all backtick quotes
    }
    else  # Store current CGI values and remove defaults
    {
	$::default_values{$name} = $temp;
    };
    # Define the CGI variable and its value (in the execute package)
    ${$name} = $temp;

    # return SUCCES
    return 1;
};

#
# SAFEqx('CommandString')
#
# A special function that is a safe alternative to backtick quotes (and qx//)
# with client-supplied CGI values. All CGI variables are surrounded by
# single ''-quotes (except between existing \'\'-quotes, don't try to be
# too smart). All variables are then interpolated. Simple (@) lists are 
# expanded with join(' ', @List), and simple (%) hash tables expanded 
# as a list of "key=value" pairs. Complex variables, e.g., @$var, are
# evaluated in a scalar context (e.g., as scalar(@$var)). All occurrences of
# $@% that should NOT be interpolated must be preceeded by a "\".
# If the first line of the String starts with "#! interpreter", the 
# remainder of the string is piped into interpreter (after interpolation), i.e.,
# open(INTERPRETER, "|interpreter");print INTERPRETER remainder;
# just like in UNIX. There are  some problems with quotes. Be carefull in
# using them. You do not have access to the output of any piped (#!)
# process! If you want such access, execute 
# <SCRIPT TYPE="text/osshell">echo "script"|interpreter</SCRIPT> or  
# <SCRIPT TYPE="text/ssperl">$resultvar = SAFEqx('echo "script"|interpreter');
# </SCRIPT>.
#
# SAFEqx ONLY WORKS WHEN THE STRING ITSELF IS SURROUNDED BY SINGLE QUOTES 
# (SO THAT IT IS NOT INTERPOLATED BEFORE IT CAN BE PROTECTED)
sub SAFEqx   # ('String') -> result of executing qx/"String"/
{
    my $CommandString = shift;
    my $NewCommandString = "";
    #
    # Only interpolate when required (check the On/Off switch)
    unless($CGIscriptor::NoShellScriptInterpolation)
    {
	#
	# Handle existing single quotes around CGI values
	while($CommandString =~ /\'[^\']+\'/s)
	{
	    my $CurrentQuotedString = $&;
	    $NewCommandString .= $`;
	    $CommandString = $';  # The remaining string
	    # Interpolate CGI variables between quotes 
	    # (e.g., '$CGIscriptorResults[-1]')
	    $CurrentQuotedString =~ 
	    s/(^|[^\\])\$((\w*)([\{\[][\$\@\%]?[\:\w\-]+[\}\]])*)/if(exists($main::default_values{$3})){
		"$1".eval("\$$2")}else{"$&"}/egs;
		#
		# Combine result with previous result
		$NewCommandString .= $CurrentQuotedString;
	    };
	    $CommandString = $NewCommandString.$CommandString;
	    #
	    # Select known CGI variables and surround them with single quotes, 
	    # then interpolate all variables
	    $CommandString =~ 
	    s/(^|[^\\])([\$\@\%]+)((\w*)([\{\[][\w\:\$\"\-]+[\}\]])*)/
	    if($2 eq '$' && exists($main::default_values{$4})) 
	    {"$1\'".eval("\$$3")."\'";} 
	    elsif($2 eq '@'){$1.join(' ', @{"$3"});}
	    elsif($2 eq '%'){my $t=$1;map {$t.=" $_=".${"$3"}{$_}}
	    keys(%{"$3"});$t}
	    else{$1.eval("${2}$3");
	}/egs;
	#
	# Remove backslashed [$@%]
	$CommandString =~ s/\\([\$\@\%])/$1/gs;
    };
    #
    # Debugging
    # return $CommandString;
    # 
    # Handle UNIX style "#! shell command\n" constructs as
    # a pipe into the shell command. The output cannot be tapped.
    my $ReturnValue = "";
    if($CommandString =~ /^\s*\#\!([^\f\n\r]+)[\f\n\r]/is)
    {
	my $ShellScripts = $';
	my $ShellCommand = $1;
	open(INTERPRETER, "|$ShellCommand") || die "\'$ShellCommand\' PIPE not opened: &!\n";
	select(INTERPRETER);$| = 1;
	print INTERPRETER $ShellScripts;
	close(INTERPRETER);
	select(STDOUT);$| = 1;
    }
    # Shell scripts which are redirected to an existing named pipe. 
    # The output cannot be tapped.
    elsif($CGIscriptor::ShellScriptPIPE)
    {
	CGIscriptor::printSAFEqxPIPE($CommandString);
    }
    else  # Plain ``-backtick execution
    {
	# Execute the commands
	$ReturnValue = join(" ", qx/$CommandString/);
    };
    return $ReturnValue;
}

####################################################################################
#
# The CGIscriptor PACKAGE
#
####################################################################################
#
# Isolate the evaluation of CGIscriptor functions, i.e., those prefixed with 
# "CGIscriptor::"
#
package CGIscriptor;

#
# The Interpolation On/Off switch
my $NoShellScriptInterpolation = undef;
# The ShellScript redirection pipe
my $ShellScriptPIPE = undef;
#
# Open a named PIPE for SAFEqx to receive ALL shell scripts
sub RedirectShellScript   # ('CommandString')
{
    my $CommandString = shift || undef;
    #
    if($CommandString)
    {
	$ShellScriptPIPE = "ShellScriptNamedPipe";
	open($ShellScriptPIPE, "|$CommandString") 
	|| die "\'|$CommandString\' PIPE open failed: $!\n";
    }
    else
    {
	close($ShellScriptPIPE);		
	$ShellScriptPIPE = undef;
    }
    return $ShellScriptPIPE;
}
#
# Print to redirected shell script pipe
sub printSAFEqxPIPE # ("String") -> print return value
{
    my $String = shift || undef;
    #
    select($ShellScriptPIPE); $| = 1;
    my $returnvalue = print $ShellScriptPIPE ($String);
    select(STDOUT); $| = 1;
    #
    return $returnvalue;
}
#
# a pointer to CGIexecute::SAFEqx
sub SAFEqx   # ('String') -> result of qx/"String"/
{
    my $CommandString = shift;
    return CGIexecute::SAFEqx($CommandString);
}

#
# a pointer to CGIexecute::defineCGIvariable
sub defineCGIvariable   # ($name[, $default]) ->0/1
{
    my $name = shift;
    my $default = shift;
    return CGIexecute::defineCGIvariable($name, $default);
}

#
# Decode URL encoded arguments
sub URLdecode   # (URL encoded input) -> string
{
    my $output = "";
    my $char;
    my $Value;
    foreach $Value (@_)
    {
	my $EncodedValue = $Value; # Do not change the loop variable
	# Convert all "+" to " "
	$EncodedValue =~ s/\+/ /g;
	# Convert all hexadecimal codes (%FF) to their byte values
	while($EncodedValue =~ /\%([0-9A-F]{2})/i)
	{
	    $output .= $`.chr(hex($1));
	    $EncodedValue = $';
	};
	$output .= $EncodedValue;  # The remaining part of $Value
    };
    $output;
};

# Encode arguments as URL codes.
sub URLencode   # (input) -> URL encoded string
{
    my $output = "";
    my $char;
    my $Value;
    foreach $Value (@_)
    {
	my @CharList = split('', $Value);
	foreach $char (@CharList)
	{ 
	    if($char =~ /\s/)
	    {  $output .= "+";}
	    elsif($char =~ /\w/)
	    {  $output .= $char;}
	    else
	    {  
		$output .= uc(sprintf("%%%2.2x", ord($char)));
	    };
	};
    };
    $output;
};

# Extract the value of a CGI variable from the URL-encoded $string
# Also extracts the data blocks from a multipart request. Does NOT
# decode the multipart blocks
sub CGIparseValue    # (ValueName [, URL_encoded_QueryString]) -> Decoded value
{
    my $ValueName = shift;
    my $QueryString = shift || $main::ENV{'QUERY_STRING'};
    my $output = "";
    #
    if($QueryString =~ /(^|\&)$ValueName\=([^\&]*)(\&|$)/)
    {
	$output = URLdecode($2);
    }
    # Get multipart POST or PUT methods
    elsif($main::ENV{'CONTENT_TYPE'} =~ m@(multipart/([\w\-]+)\;\s+boundary\=([\S]+))@i)
    {
        my $MultipartType = $2;
        my $BoundaryString = $3;
        # Remove the boundary-string
        my $temp = $QueryString;
        $temp =~ /^\Q--$BoundaryString\E/m;
        $temp = $';
	#
	# Identify the newline character(s), this is the first character in $temp
        my $NewLine = "\r\n";    # Actually, this IS the correct one
        unless($temp =~ /^(\-\-|\r\n)/)   # However, you never realy can be sure
        {
	    $NewLine = "\n"   if $temp =~ /^([\n])/;      # Single Line Feed
            $NewLine = "\r"   if $temp =~ /^([\r])/;	  # Single Return
	    $NewLine = "\r\n" if $temp =~ /^(\r\n)/;      # Double (CRLF, the correct one)
	    $NewLine = "\n\r" if $temp =~ /^(\n\r)/;      # Double
	};
	#
        # search through all data blocks
        while($temp =~ /^\Q--$BoundaryString\E/m)
        {
            my $DataBlock = $`;
            $temp = $';
	    # Get the empty line after the header
	    $DataBlock =~ /$NewLine$NewLine/;
	    $Header = $`;
	    $output = $';
	    my $Header = $`;
	    $output = $';
	    #
	    # Remove newlines from the header
	    $Header =~ s/$NewLine/ /g;
	    # 
	    # Look whether this block is the one you are looking for
	    # Require the quotes!
            if($Header =~ /name\s*=\s*[\"\']$ValueName[\"\']/m)
            {
		my $i;
		for($i=length($NewLine); $i; --$i) 
		{
		    chop($output);
		};
                # OK, get out
                last;
            };
	    # reinitialize the output
	    $output = "";
        };
    }
    else
    {
	print "ERROR: $ValueName $main::ENV{'CONTENT_TYPE'}\n";
    };
    return $output;
}

sub CGIparseForm    # ([URL_encoded_QueryString]) -> Decoded Form (NO multipart)
{
    my $QueryString = shift || $main::ENV{'QUERY_STRING'};
    my $output = "";
    #
    $QueryString =~ s/\&/\n/g;
    $output = URLdecode($QueryString);
    #
    $output;
}

# Extract the header of a multipart CGI variable from the POST input 
sub CGIparseHeader    # (ValueName [, URL_encoded_QueryString]) -> Decoded value
{
    my $ValueName = shift;
    my $QueryString = shift || $main::ENV{'QUERY_STRING'};
    my $output = "";
    #
    if($main::ENV{'CONTENT_TYPE'} =~ m@(multipart/([\w\-]+)\;\s+boundary\=([\S]+))@i)
    {
        my $MultipartType = $2;
        my $BoundaryString = $3;
        # Remove the boundary-string
        my $temp = $QueryString;
        $temp =~ /^\Q--$BoundaryString\E/m;
        $temp = $';
	#
	# Identify the newline character(s), this is the first character in $temp
        my $NewLine = "\r\n";    # Actually, this IS the correct one
        unless($temp =~ /^(\-\-|\r\n)/)   # However, you never realy can be sure
        {
	    $NewLine = "\n"   if $temp =~ /^([\n])/;      # Single Line Feed
            $NewLine = "\r"   if $temp =~ /^([\r])/;	  # Single Return
	    $NewLine = "\r\n" if $temp =~ /^(\r\n)/;      # Double (CRLF, the correct one)
	    $NewLine = "\n\r" if $temp =~ /^(\n\r)/;      # Double
	};
	#
        # search through all data blocks
        while($temp =~ /^\Q--$BoundaryString\E/m)
        {
            my $DataBlock = $`;
            $temp = $';
	    # Get the empty line after the header
	    $DataBlock =~ /$NewLine$NewLine/;
	    $Header = $`;
	    my $Header = $`;
	    #
	    # Remove newlines from the header
	    $Header =~ s/$NewLine/ /g;
	    # 
	    # Look whether this block is the one you are looking for
	    # Require the quotes!
            if($Header =~ /name\s*=\s*[\"\']$ValueName[\"\']/m)
            {
	        $output = $Header;
                last;
            };
	    # reinitialize the output
	    $output = "";
        };
    };
    return $output;
}

#
# Checking variables for security (e.g., file names and email addresses)
# File names are tested against the $::FileAllowedChars and $::BlockPathAccess variables
sub CGIsafeFileName    # FileName -> FileName or ""
{
    my $FileName = shift || "";
    return "" if $FileName =~ m?[^$::FileAllowedChars]?;
    return "" if $FileName =~ m@\.\.\Q$::DirectorySeparator\E@; # Higher directory not allowed
    return "" if $FileName =~ m@\Q$::DirectorySeparator\E\.\.@; # Higher directory not allowed
	return "" if $::BlockPathAccess && $FileName =~ m@$::BlockPathAccess@;			# Invisible (blocked) file

    return $FileName;
}

sub CGIsafeEmailAddress    # email -> email or ""
{
    my $Email = shift || "";
    return "" unless $Email =~ m?^[\w\.\-]+\@[\w\.\-\:]+$?;
    return $Email;
}


#
# BrowseDirs(RootDirectory [, Pattern, Start])
#
# usage:
# <SCRIPT TYPE='text/ssperl'>
# CGIscriptor::BrowsDirs('Sounds', '\.aifc$', 'Speech', 'DIRECTORY')
# </SCRIPT>
#
# Allows to browse subdirectories. Start should be relative to the RootDirectory,
# e.g., the full path of the directory 'Speech' is '~/Sounds/Speech'.
# Only files which fit /$Pattern/ and directories are displayed. 
# Directories down or up the directory tree are supplied with a
# GET request with the name of the CGI variable in the fourth argument (default
# is 'BROWSEDIRS'). So the correct call for a subdirectory could be:
# CGIscriptor::BrowseDirs('Sounds', '\.aifc$', $DIRECTORY, 'DIRECTORY')
#
sub BrowseDirs			# (RootDirectory [, Pattern, Start, CGIvariable]) -> Print HTML code
{
	my $RootDirectory = shift; # || return 0;
	my $Pattern = shift || '\S';
	my $Start = shift || "";
	my $CGIvariable = shift || "BROWSEDIRS";
	#
	$Start = CGIscriptor::URLdecode($Start);  # Sometimes, too much has been encoded
	$Start =~ s@//+@/@g;
	$Start =~ s@[^/]+/\.\.@@ig;
	$Start =~ s@/\.$@@ig;
	#
	print "<h3>/$RootDirectory/$Start</h3>\n<ul>\n";
	opendir(BROWSE, "$::CGI_HOME/$RootDirectory/$Start") || die "$::CGI_HOME/$RootDirectory/$Start $!";
	my @AllFiles = readdir(BROWSE);
	while(@AllFiles)
	{
		my $file = shift(@AllFiles);
		# Check whether this file should be visible
		next if $::BlockPathAccess && $file =~ m@$::BlockPathAccess@;

		if(-d "$::CGI_HOME/$RootDirectory/$Start/$file")
		{
			my $NewURL = $Start ? "$Start/$file" : $file;
			$NewURL = CGIscriptor::URLencode($NewURL);
			print "<li><a href='?$CGIvariable=$NewURL'>$file</a><br>\n";
		}
		elsif($file =~ /$Pattern/)
		{
			print "<li><a href='/$RootDirectory/$Start/$file'>$file</a><br>\n";
		};
	};
	print "</ul>";
	#
	return 1;
};

#
# ListDocs(Pattern [,ListType])
#
# usage:
# <SCRIPT TYPE=text/ssperl>
# CGIscriptor::ListDocs("/*", "dl");
# </SCRIPT> 
#
# This subroutine is very usefull to manage collections of independent
# documents. The resulting list will display the tree-like directory 
# structure. If this routine is too slow for online use, you can
# store the result and use a link to that stored file. 
#
# List HTML and Text files with title and first header (HTML)
# or filename and first meaningfull line (general text files). 
# The listing starts at the ServerRoot directory. Directories are
# listed recursively.
#
# You can change the list type (default is dl).
# e.g., 
# <dt><a href=<file.html>>title</a>
# <dd>First Header
# <dt><a href=<file.txt>>file.txt</a>
# <dd>First meaningfull line of text
#
sub ListDocs         # ($Pattern [, prefix]) e.g., ("/Books/*", [, "dl"])
{
    my $Pattern = shift;
    $Pattern =~ /\*/;
    my $ListType = shift || "dl";
    my $Prefix = lc($ListType) eq "dl" ? "dt" : "li";
    my $URL_root = "http://$::ENV{'SERVER_NAME'}\:$::ENV{'SERVER_PORT'}";
    my @FileList = glob("$::CGI_HOME$Pattern");
    my ($FileName, $Path, $Link);
    #
    # Print List markers
    print "<$ListType>\n";
    #
    # Glob all files
    File:  foreach $FileName (@FileList)
    {
	    # Check whether this file should be visible
		next if $::BlockPathAccess && $FileName =~ m@$::BlockPathAccess@;

	# Recursively list files in all directories
	if(-d $FileName)
	{
	    $FileName =~ m@([^/]*)$@;
	    my $DirName = $1;
	    print "<$Prefix>$DirName\n";
	    $Pattern =~ m@([^/]*)$@;
	    &ListDocs("$`$DirName/$1", $ListType);
	    next;
	}
	# Use textfiles
	elsif(-T $FileName)
	{
	    open(TextFile, $FileName) || next;
	}
	# Ignore all other file types
	else
	{ next;};
	#
	# Get file path for link
	$FileName =~ /$::CGI_HOME/;
	print "<$Prefix><a href=$URL_root$'>";
	# Initialize all variables
	my $Line = "";
	my $TitleFound = 0;
	my $Caption = "";
	my $Title = "";
	# Read file and step through
	while(<TextFile>)
	{
	    chop $_;
	    $Line = $_;
	    # HTML files
	    if($FileName =~ /\.ht[a-zA-Z]*$/i)
	    {
		# Catch Title
		while(!$Title)
		{  
		    if($Line =~ m@<title>([^<]*)</title>@i) 
		    {  
			$Title = $1;
			$Line = $';
		    }
		    else
		    {  
			$Line .= <TextFile> || goto Print;
			chop $Line;
		    };
		};
		# Catch First Header
		while(!$Caption)
		{  
		    if($Line =~ m@</h1>@i) 
		    {  
			$Caption = $`;
			$Line = $';
			$Caption =~ m@<h1>@i;
			$Caption = $';
			$Line = $`.$Caption.$Line;
		    }
		    else
		    {  
			$Line .= <TextFile> || goto Print;
			chop $Line;
		    };
		};
	    }
	    # Other text files
	    else
	    {
		# Title equals file name
		$FileName =~ /([^\/]+)$/;
		$Title = $1;
		# Catch equals First Meaningfull line
		while(!$Caption)
		{  
		    if($Line =~ /[A-Z]/ && 
		    ($Line =~ /subject|title/i || $Line =~ /^[\w,\.\s\?\:]+$/) 
		    && $Line !~ /Newsgroup/ && $Line !~ /\:\s*$/)
		    {
			$Line =~ s/\<[^\>]+\>//g;             
			$Caption = $Line;
		    }
		    else
		    {
			$Line = <TextFile> || goto Print;
		    };
		};
	    };
	    Print: # Print title and subject
	    print "$Title</a>\n";
	    print "<dd>$Caption\n" if $ListType eq "dl";
	    $TitleFound = 0;
	    $Caption = "";
	    close TextFile;
	    next File;
	};
    };
    # Print Closing List Marker
    print "</$ListType>\n";
    "";   # Empty return value
};

#
# HTMLdocTree(Pattern [,ListType])
#
# usage:
# <SCRIPT TYPE=text/ssperl>
# CGIscriptor::HTMLdocTree("/Welcome.html", "dl");
# </SCRIPT> 
#
# The following subroutine is very usefull for checking large document
# trees. Starting from the root (s), it reads all files and prints out
# a nested list of links to all attached files. Non-existing or misplaced
# files are flagged. This is quite a file-i/o intensive routine
# so you would not like it to be accessible to everyone. If you want to
# use the result, save the whole resulting page to disk and use a link
# to this file. 
#
# HTMLdocTree takes an HTML file or file pattern and constructs nested lists 
# with links to *local* files (i.e., only links to the local server are
# followed). The list entries are the document titles.
# If the list type is <dl>, the first <H1> header is used too.
# For each file matching the pattern, a list is made recursively of all
# HTML documents that are linked from it and are stored in the same directory
# or a sub-directory. Warnings are given for missing files.
# The listing starts for the ServerRoot directory.
# You can change the default list type <dl> (<dl>, <ul>, <ol>).
#
%LinkUsed = ();

sub HTMLdocTree         # ($Pattern [, listtype]) 
# e.g., ("/Welcome.html", [, "ul"])
{
    my $Pattern = shift;
    my $ListType = shift || "dl";
    my $Prefix = lc($ListType) eq "dl" ? "dt" : "li";
    my $URL_root = "http://$::ENV{'SERVER_NAME'}\:$::ENV{'SERVER_PORT'}";
    my ($Filename, $Path, $Link);
    my %LocalLinks = {};
    #
    # Read files (glob them for expansion of wildcards)
    my @FileList = glob("$::CGI_HOME$Pattern");
    foreach $Path (@FileList)
    {
	# Get URL_path
	$Path =~ /$::CGI_HOME/;
	my $URL_path = $';
		# Check whether this file should be visible
		next if $::BlockPathAccess && $URL_path =~ m@$::BlockPathAccess@;

	my $Title = $URL_path;
	my $Caption = "";
	# Current file should not be used again
	++$LinkUsed{$URL_path};
	# Open HTML doc
	unless(open(TextFile, $Path))
	{
	    print "<$Prefix>$Title <blink>(not found)</blink><br>\n";
	    next;
	};
	while(<TextFile>)
	{
	    chop $_;
	    $Line = $_;
	    # Catch Title
	    while($Line =~ m@<title>@i)
	    {  
		if($Line =~ m@<title>([^<]*)</title>@i) 
		{  
		    $Title = $1;
		    $Line = $';
		}
		else
		{  
		    $Line .= <TextFile>;
		    chop $Line;
		};
	    };
	    # Catch First Header
	    while(!$Caption && $Line =~ m@<h1>@i)
	    {  
		if($Line =~ m@</h[1-9]>@i) 
		{  
		    $Caption = $`;
		    $Line = $';
		    $Caption =~ m@<h1>@i;
		    $Caption = $';
		    $Line = $`.$Caption.$Line;
		}
		else
		{  
		    $Line .= <TextFile>;
		    chop $Line;
		};
	    };
	    # Catch and print Links
	    while($Line =~ m@<a href\=([^>]*)>@i)
	    {
		$Link = $1;
		$Line = $';
		# Remove quotes
		$Link =~ s/\"//g;
		# Remove extras
		$Link =~ s/[\#\?].*$//g;
		# Remove Servername
		if($Link =~ m@(http://|^)@i)
		{
		    $Link = $';
		    # Only build tree for current server
		    next unless $Link =~ m@$::ENV{'SERVER_NAME'}|^/@;
		    # Remove server name and port
		    $Link =~ s@^[^\/]*@@g;
		    #
		    # Store the current link
		    next if $LinkUsed{$Link} || $Link eq $URL_path;
		    ++$LinkUsed{$Link};
		    ++$LocalLinks{$Link};
		};
	    };
	};
	close TextFile;
	print "<$Prefix>";
	print "<a href=http://";
	print "$::ENV{'SERVER_NAME'}\:$::ENV{'SERVER_PORT'}$URL_path>";
	print "$Title</a>\n";
	print "<br>$Caption\n" 
	if $Caption && $Caption ne $Title && $ListType =~ /dl/i;
	print "<$ListType>\n";
	foreach $Link (keys(%LocalLinks))
	{
	    &HTMLdocTree($Link, $ListType);
	};
	print "</$ListType>\n";
    };
};
#
# Make require happy
1;

=head1 NAME

CGIscriptor - 

=head1 DESCRIPTION

CGIscriptor.pl is a HTML 4 compliant script/module for integrating HTML, 
CGI, and perl scripts at the server side.  
 
=head1 README

CGIscriptor merges plain ASCII HTML files transparantly and safely 
with CGI variables, PERL code, shell commands, and executable scripts 
(on-line and real-time). It combines the "ease of use" of HTML files with 
the versatillity of specialized scripts and PERL programs. It hides 
all the specifics and idiosyncrasies of correct output and CGI coding 
and naming. Scripts do not have to be aware of HTML, HTTP, or CGI 
conventions just as HTML files can be ignorant of scripts and the 
associated values. CGIscriptor complies with the W3C HTML 4.0 
recommendations.

This Perl program will run on any WWW server that runs perl scripts,
just add a line like the following to your srm.conf file 
(Apache example):

ScriptAlias /SHTML/ /real-path/CGIscriptor.pl/

URL's that refer to http://www.your.address/SHTML/... will now be handled 
by CGIscriptor.pl, which can use a private directory tree (default is the 
SERVER_ROOT directory tree, but it can be anywhere, see below).

=head1 PREREQUISITES


=head1 COREQUISITES


=pod OSNAMES

Unix

=pod SCRIPT CATEGORIES

Servers
CGI
Web

=cut
