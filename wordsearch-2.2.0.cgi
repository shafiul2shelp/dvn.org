#!/usr/bin/perl

use Math::Random;

print "Content-Type: text/html\n\n";
# Parse Form Contents

# Determine the form's REQUEST_METHOD (GET or POST) and split the form   #
# fields up into their name-value pairs.  If the REQUEST_METHOD was      #
# not GET or POST, send an error.                                        #
$price=0;

if ($ENV{'REQUEST_METHOD'} eq 'GET') {
   # Split the name-value pairs
   @pairs = split(/&/, $ENV{'QUERY_STRING'});
}
elsif ($ENV{'REQUEST_METHOD'} eq 'POST') {
   # Get the input
   read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});

   # Split the name-value pairs
   @pairs = split(/&/, $buffer);
}
else {
   # user typed it from the terminal mode
   print "bad form method used ($ENV{'REQUEST_METHOD'})\n";
#   exit 0;
};

# random_set_seed
$phrase = localtime();
$phrase = join(",",$phrase,$phrase,$phrase,$phrase,$phrase);
random_set_seed_from_phrase($phrase);

# Version history
# 1.0.0  Original program written, debugged, and tested.
# 1.1.0  Changed the input routine to allow spaces and paragraph style word arrays.  Added
#        unique word detector
# 2.0.0  added the ability to add words to a database of puzzles and then be capable of
#        pulling from that list to generate a random puzzle.
# 2.1.0  made the list more random by sorting out the word lise beforehand and then randomizing
#        the word list so you never know what word was the first word inserted into the list.
# 2.2.0  changed the way the program works by sectionalizing the parts into smaller sections.
$version = "2.2.0";

$title = join(" ", "Wordsearch",$version);


$min = 10;
$max = 99;
$defaultx = 15;
$defaulty = 15;
$width = $defaultx;
$height = $defaulty;
@goodwords = ();
$wordsearchname = "Test Puzzle";

# database file name
$mywordsearchdatabase = "/library/webserver/cgi-executables/private/wordsearch.database";

$printsolution = 1;
$printlinenumbers = 0;
$dosort = 0;
$addwords = 0;
$randompuzzle = 0;

$debug=0;
$fillspaces = 1;
@chars = (".", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z");
$words = "robert,dell,wordsearch,puzzle,generator,mix,codewarrior,apprentice,duke,nukem,aesopolis,zork";

# these directions are only for internal reference.  the array is never used.
@directions = ("", "up", "right", "down", "left", "upright", "downright", "downleft", "upleft");
#                    1      2        3       4        5           6            7          8

foreach $pair (@pairs) {

   # Split the pair up into individual variables.                       #
   local($name, $value) = split(/=/, $pair);

   # Decode the form encoding on the name and value variables.          #
   # v1.92: remove null bytes                                           #
   $name =~ tr/+/ /;
   $name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
   $name =~ tr/\0//d;

   $value =~ tr/+/ /;
   $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
   $value =~ tr/\0//d;
   $item = 0;

   if ($name eq 'width') {
     $width = $value;
     if (($width < $min) or ($width > $max)) {
       print "Ranges for width and height must be between 10 and 99 inclusive";
       exit 0;
       };
     }
   elsif ($name eq 'height') {
     $height = $value;
     if (($height < $min) or ($height > $max)) {
       print "Ranges for width and height must be between 10 and 99 inclusive";
       exit 0;
       };
     }
   elsif ($name eq 'solution') {
     $printsolution = $value;
     if (($printsolution != 0) and ($printsolution != 1)) {
       $printsolution = 1;
       };
     }
   elsif ($name eq 'linenumber') {
     $printlinenumbers = $value;
     if (($printlinenumbers != 0) and ($printlinenumbers != 1)) {
       $printlinenumbers = 0;
       };
     }
   elsif ($name eq 'dosort') {
     $dosort = $value;
     if (($dosort != 0) and ($dosort != 1)) {
       $dosort = 1;
       };
     }
   elsif ($name eq 'addwords') {
     $addwords = $value;
     if (($addwords != 0) and ($addwords != 1)) {
       $addwords = 0;
       };
     }
   elsif ($name eq 'randompuzzle') {
     $randompuzzle = $value;
     if (($randompuzzle != 0) and ($randompuzzle != 1)) {
       $randompuzzle = 0;
       };
     }
   elsif ($name eq 'name') {
     $wordsearchname = $value;
     $wordsearchname =~ s/,//g;
     $wordsearchname = lc $wordsearchname;
     @temp = split(" ", $wordsearchname);
     $wordsearchname = "";
     foreach $w (@temp) {
       $w = ucfirst $w;
       $l = length $wordsearchname;
       if ($l == 0) {
         $wordsearchname = $w;
         }
       else {
         $wordsearchname = join (" ", $wordsearchname, $w);
         };
       };  
     }
   elsif ($name eq 'words') {
     $words = $value;
     };
   };
$words =~ tr/ /,/;
$words =~ tr/\n/,/;
$words =~ tr/\r/,/;
$words =~ tr/\t/,/;
$words =~ s/\./,/g;
$words =~ s/\'//g;
$words =~ s/\"//g;
$words =~ s/\!//g;
$words =~ s/\_//g;
$words =~ s/\(//g;
$words =~ s/\)//g;
$words =~ s/\://g;
$words =~ s/\-//g;
$words =~ s/\///g;
$words =~ s/\<//g;
$words =~ s/\>//g;
$words =~ s/\=//g;
$words =~ s/\%//g;
$words =~ s/\[//g;
$words =~ s/\]//g;
$words =~ s/\{//g;
$words =~ s/\}//g;
$words =~ s/\#//g;
$words =~ s/\@/at/g;
$words =~ s/\$/,/g;
$words =~ s/0//g;
$words =~ s/1//g;
$words =~ s/2//g;
$words =~ s/3//g;
$words =~ s/4//g;
$words =~ s/5//g;
$words =~ s/6//g;
$words =~ s/7//g;
$words =~ s/8//g;
$words =~ s/9//g;
$words =~ s/\,\,/,/g;
$words =~ s/\,\,/,/g;
$words =~ s/\,\,/,/g;
$words = uc $words;
@wordarray = split(/,/,$words);

&scanforvalidwords;
&createdatabaseline;

#--------- load random puzzle start ---------
if ($randompuzzle == 1) {
  &getrandompuzzle;
  };
#--------- load random puzzle end ---------

#--------- randomize the word list start ---------
# sort out the word list
if ($dosort == 1) {
  &sortwordlist;
  &randomizewordlist;
  };
#--------- randomize the word list end ---------

$matrixsize = $width * $height;
@searcharray = ();
for ($i = 1; $i <= $matrixsize; $i++) {
  $searcharray[$i] = ".";
  };

if ($addwords == 1) {
  open ($datafile, $mywordsearchdatabase);
  @data = <$datafile>;
  close ($datafile);
  $data[$#data + 1] = join("", $words, "\n");
  $mywordsearchdatabase = join("", ">", $mywordsearchdatabase);
  open ($datafile, $mywordsearchdatabase);
  foreach $line (@data) {
    print $datafile $line;
    };
  close ($datafile);
  $title = join ("", "Added puzzle:  ",$wordsearchname);
  &printheader;
  print "<p>Successfully added the following line to the database.</p>\n";
  print "<code>\n";
  print $words,"<br />\n";
  print "</code>";
  }
else {
  # Put the words on the matrix
  $wordcount = 0;
  foreach $w (@wordarray) {
    @where = (1,1,1,0);
    &scanboard($w);
    if ($where[3]<0) {
      }
    else {
      $goodwords[$wordcount] = $w;
      &putword ($w);
      $wordcount = $wordcount + 1;
      };
    };
  @wordarray = @goodwords;

  # sort out the word list
  if ($dosort == 1) {
    sortwordlist;
    };


  # backup the matrix to the solution
  @solution = @searcharray;

  # fill the letters not used with a random number.
  if ($fillspaces == 1) {
    for ($i=0; $i<=$matrixsize; $i++) {
      if ($searcharray[$i] eq ".") {
        $searcharray[$i] = $chars[random_uniform_integer(1,1,26)];
        };
      };
    };
  
  $title = join ("", "Puzzle:  ",$wordsearchname);
  &printheader;
   
  print "<code>\n";
  for ($y = 1; $y <= $height; $y++) {
  #  print "<p class=\"matrix\"> ";
    if ($printlinenumbers == 1) {
      print "0" if ($y < 10);
      print $y,"  ";
      };
    for ($x = 1; $x <= $width; $x++) {
      print &getletter($x,$y)," ";
      };
  #  print "</p>";
    print "<br />\n";
    };
  print "</code>\n";
  print "<hr />\n";
  print "<code>\n";

  $i = 0;
  foreach $w (@wordarray) {
    $i = $i + 1;
    print "0" if ($i<10);
    print $i,") ",$w,"<br />\n";
    };

  print "</code>\n";
  print "<hr />\n";

  # print the solution
  if ($printsolution == 1) {
    @searcharray = @solution;
    for ($i=1; $i<51; $i++) {
      print "<br />\n";
      };
      print "<code>\n";
      for ($y = 1; $y <= $height; $y++) {
        if ($printlinenumbers == 1) {
          print "0" if ($y < 10);
          print $y,"  ";
          };
        for ($x = 1; $x <= $width; $x++) {
          print &getletter($x,$y)," ";
          };
        print "<br />\n";
        };
    print "</code>\n";
    print "<hr />\n";
    print "<code>\n";
    $i = 0;
    foreach $w (@wordarray) {
      $i = $i + 1;
      print "0" if ($i<10);
      print $i,") ",$w,"<br />\n";
      };
    print "</code>\n";
    print "<hr />\n";
    };
  };
&printfooter;

exit 0 ;


sub getrandompuzzle {
  # first thing we do is kill adding words.  no need to re-add the words to the list.
  $addwords = 0;
  
  # now we prepare the arrays to handle the new list
  @wordarray = ();
  
  # read in the data file completely and then decide on what line to display
  open ($datafile, $mywordsearchdatabase);
  @data = <$datafile>;
  close ($datafile);
  $rnd = random_uniform_integer(1, 0, $#data);
  $words = $data[$rnd];
  
  # strip out the return character
  $words =~ s/\n//g;
  $words =~ s/\r//g;

  # Now separate the various values from the incoming line
  @temparray = split(/,/,$words);
  $height = $temparray[0];
  $width = $temparray[1];
  $wordsearchname = $temparray[2];
  for ($i=3; $i<=$#temparray; $i++) {
    $wordarray[$#wordarray + 1] = $temparray[$i];
    };
  @temparray = ();
  };
  
sub scanforvalidwords {
  @validwords = ();
  foreach $w (@wordarray) {
    $alreadyadded = 0;
    for ($i=0; $i<=$#validwords; $i++) {
      if ($w eq $validwords[$i]) {
        $alreadyadded = 1;
        $i = $#validwords;
        };
      };
    if (($alreadyadded == 0) and (length $w > 2)) {
      $validwords[$#validwords + 1] = $w;
      };
    };
  @wordarray = @validwords;
  @validwords = ();
  };
  
sub createdatabaseline {
  $words = "";
  foreach $w (@wordarray) {
    $l = length $words;
    if ($l == 0) {
      $words = $w;
      }
    else {
      $words = join(",",$words,$w);
      };
    $l = length $w;
    if ($l > $height) {
      $height = $l + 1;
      };
    if ($l > $width) {
      $width = $l + 1;
      };
    };
  $words = join(",", $height, $width, $wordsearchname, $words);
  };
  


sub printfooter {
  print "</body>\n";
  print "</html>\n\n";
  };
  
  
sub printheader {
  print "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">\n";
  print "<html>\n";
  print "<head>\n";
  print "  <title> $title </title>\n";
  print "  <meta http-equiv=\"Content-Type\" content=\"text/html; charset=ISO-8859-1\">\n";
  print "  <link type=\"text/css\" rel=\"stylesheet\" href=\"/css/wordsearchstyle.css\">\n";
  print "</head>\n";
  print "\n";
  print "\n";
  print "<body>\n";
  print "<h1>$title</h1>\n";
  print "<h2>PROTOTYPE</h2>\n";
  print "<hr />\n";
  };

sub sortwordlist {
  for ($i=0; $i<$#wordarray; $i++) {
    $testword = $wordarray[$i];
    for ($j=$i; $j<=$#wordarray; $j++) {
      if ($wordarray[$j] lt $testword) {
        $testword = $wordarray[$j];
        $wordarray[$j] = $wordarray[$i];
        $wordarray[$i] = $testword;
        };
      };
    };
  };
  
sub randomizewordlist {
  @temparray = ();
  @filled = ();
  for ($i=0; $i<=$#wordarray; $i++) {
    $filled[$i] = 0;
    };
  for ($i=0; $i<=$#wordarray; $i++) {
    $x = random_uniform_integer(1,0,$#wordarray);
    while ($filled[$x] == 1) {
      $x = random_uniform_integer(1,0,$#wordarray);
      };
    $temparray[$#temparray + 1] = $wordarray[$x];
    $filled[$x] = 1;
    };
  };
  
sub putletter {
  my($xloc, $yloc, $pchar) = @_;
  $pchar = uc $pchar;
  $loc = (($yloc-1)*$width)+$xloc;
  if ($loc > 0) {
    $searcharray[$loc] = $pchar;
    };
  };
  
sub getletter {
  my($xloc, $yloc) = @_;
  $pchar = uc $pchar;
  $loc = (($yloc-1)*$width)+$xloc;
  return $searcharray[$loc];
  };

sub scanboard {
  $where[0] = 1;
  $where[1] = 2;
  $where[2] = 6;
  $where[3] = -1;
  my ($word) = @_;
  local $xpos = 1;
  local $ypos = 1;
  local $count = 0;
  local $wordlength = length($word);
  local $dir = 1;
# these directions are only for internal reference.  the array is never used.
# @directions = ("up", "right", "down", "left", "upright", "downright", "downleft", "upleft");
#                1      2        3       4        5           6            7          8
  $tmp1x = $width  - $wordlength + 1;
  $tmp2y = $height - $wordlength + 1;
  for ($dir = 1; $dir <= 8; $dir++) {

    if ($dir == 1) {
      for ($xpos = 1; $xpos <= $width; $xpos++) {
        for ($ypos = $wordlength; $ypos <= $height; $ypos++) {
          $count = 0;
          $tempx = $xpos + 0;
          $tempy = $ypos + 0;
          for ($i=0; $i<$wordlength; $i++) {
            if (substr($word, $i, 1) eq &getletter($tempx, $tempy)) {
              $count++;
              }
            elsif (&getletter($tempx, $tempy) ne ".") {
              $count = -100;
              };
            $tempy = $tempy - 1;
            };
          if ($count > $where[3]) {
            $where[0] = $xpos;
            $where[1] = $ypos;
            $where[2] = $dir;
            $where[3] = $count;
            }
          elsif ($count == $where[3]) {
            $flip = random_uniform_integer(1,0,10);
            if ($flip < 3) {
              $where[0] = $xpos;
              $where[1] = $ypos;
              $where[2] = $dir;
              $where[3] = $count;
              };
            };
          
          };
        };
      }
    elsif ($dir == 2) {
      for ($xpos = 1; $xpos <= $tmp1x; $xpos++) {
        for ($ypos = 1; $ypos <= $height; $ypos++) {
          $count = 0;
          $tempx = $xpos + 0;
          $tempy = $ypos + 0;
          for ($i=0; $i<$wordlength; $i++) {
            if (substr($word, $i, 1) eq &getletter($tempx, $tempy)) {
              $count++;
              }
            elsif (&getletter($tempx, $tempy) ne ".") {
              $count = -100;
              };
            $tempx = $tempx + 1;
            };
          if ($count > $where[3]) {
            $where[0] = $xpos;
            $where[1] = $ypos;
            $where[2] = $dir;
            $where[3] = $count;
            }
          elsif ($count == $where[3]) {
            $flip = random_uniform_integer(1,0,10);
            if ($flip < 3) {
              $where[0] = $xpos;
              $where[1] = $ypos;
              $where[2] = $dir;
              $where[3] = $count;
              };
            };
          
          };
        };
      }
    elsif ($dir == 3) {
      for ($xpos = 1; $xpos <= $width; $xpos++) {
        for ($ypos = 1; $ypos <= $tmp2y; $ypos++) {
          $count = 0;
          $tempx = $xpos + 0;
          $tempy = $ypos + 0;
          for ($i=0; $i<$wordlength; $i++) {
            if (substr($word, $i, 1) eq &getletter($tempx, $tempy)) {
              $count++;
              }
            elsif (&getletter($tempx, $tempy) ne ".") {
              $count = -100;
              };
            $tempy = $tempy + 1;
            };
          if ($count > $where[3]) {
            $where[0] = $xpos;
            $where[1] = $ypos;
            $where[2] = $dir;
            $where[3] = $count;
            }
          elsif ($count == $where[3]) {
            $flip = random_uniform_integer(1,0,10);
            if ($flip < 3) {
              $where[0] = $xpos;
              $where[1] = $ypos;
              $where[2] = $dir;
              $where[3] = $count;
              };
            };
          
          };
        };
      }
    elsif ($dir == 4) {
      for ($xpos = $wordlength; $xpos <= $width; $xpos++) {
        for ($ypos = 1; $ypos <= $height; $ypos++) {
          $count = 0;
          $tempx = $xpos + 0;
          $tempy = $ypos + 0;
          for ($i=0; $i<$wordlength; $i++) {
            if (substr($word, $i, 1) eq &getletter($tempx, $tempy)) {
              $count++;
              }
            elsif (&getletter($tempx, $tempy) ne ".") {
              $count = -100;
              };
            $tempx = $tempx - 1;
            };
          if ($count > $where[3]) {
            $where[0] = $xpos;
            $where[1] = $ypos;
            $where[2] = $dir;
            $where[3] = $count;
            }
          elsif ($count == $where[3]) {
            $flip = random_uniform_integer(1,0,10);
            if ($flip < 3) {
              $where[0] = $xpos;
              $where[1] = $ypos;
              $where[2] = $dir;
              $where[3] = $count;
              };
            };
          
          };
        };
      }
    elsif ($dir == 5) {
      for ($xpos = 1; $xpos <= $tmp1x; $xpos++) {
        for ($ypos = $wordlength; $ypos <= $height; $ypos++) {
          $count = 0;
          $tempx = $xpos + 0;
          $tempy = $ypos + 0;
          for ($i=0; $i<$wordlength; $i++) {
            if (substr($word, $i, 1) eq &getletter($tempx, $tempy)) {
              $count++;
              }
            elsif (&getletter($tempx, $tempy) ne ".") {
              $count = -100;
              };
            $tempy = $tempy - 1;
            $tempx = $tempx + 1;
            };
          if ($count > $where[3]) {
            $where[0] = $xpos;
            $where[1] = $ypos;
            $where[2] = $dir;
            $where[3] = $count;
            }
          elsif ($count == $where[3]) {
            $flip = random_uniform_integer(1,0,10);
            if ($flip < 3) {
              $where[0] = $xpos;
              $where[1] = $ypos;
              $where[2] = $dir;
              $where[3] = $count;
              };
            };
          
          };
        };
      }
    elsif ($dir == 6) {
      for ($xpos = 1; $xpos <= $tmp1x; $xpos++) {
        for ($ypos = 1; $ypos <= $tmp2y; $ypos++) {
          $count = 0;
          $tempx = $xpos + 0;
          $tempy = $ypos + 0;
          for ($i=0; $i<$wordlength; $i++) {
            if (substr($word, $i, 1) eq &getletter($tempx, $tempy)) {
              $count++;
              }
            elsif (&getletter($tempx, $tempy) ne ".") {
              $count = -100;
              };
            $tempy = $tempy + 1;
            $tempx = $tempx + 1;
            };
          if ($count > $where[3]) {
            $where[0] = $xpos;
            $where[1] = $ypos;
            $where[2] = $dir;
            $where[3] = $count;
            }
          elsif ($count == $where[3]) {
            $flip = random_uniform_integer(1,0,10);
            if ($flip < 3) {
              $where[0] = $xpos;
              $where[1] = $ypos;
              $where[2] = $dir;
              $where[3] = $count;
              };
            };
          
          };
        };
      }
    elsif ($dir == 7) {
      $tmp2 = $height-$wordlength;
      for ($xpos = $wordlength; $xpos <= $width; $xpos++) {
        for ($ypos = 1; $ypos <= $tmp2y; $ypos++) {
          $count = 0;
          $tempx = $xpos + 0;
          $tempy = $ypos + 0;
          for ($i=0; $i<$wordlength; $i++) {
            if (substr($word, $i, 1) eq &getletter($tempx, $tempy)) {
              $count++;
              }
            elsif (&getletter($tempx, $tempy) ne ".") {
              $count = -100;
              };
            $tempy = $tempy + 1;
            $tempx = $tempx - 1;
            };
          if ($count > $where[3]) {
            $where[0] = $xpos;
            $where[1] = $ypos;
            $where[2] = $dir;
            $where[3] = $count;
            }
          elsif ($count == $where[3]) {
            $flip = random_uniform_integer(1,0,10);
            if ($flip < 3) {
              $where[0] = $xpos;
              $where[1] = $ypos;
              $where[2] = $dir;
              $where[3] = $count;
              };
            };
          
          };
        };
      }
    elsif ($dir == 8) {
#      for ($xpos = $wordlength; $xpos <= $width; $xpos++) {
      for ($xpos = $width; $xpos >= $wordlength; $xpos--) {
#        for ($ypos = $wordlength; $ypos <= $height; $ypos++) {
        for ($ypos = $height; $ypos >= $wordlength; $ypos--) {
          $count = 0;
          $tempx = $xpos + 0;
          $tempy = $ypos + 0;
          for ($i=0; $i<$wordlength; $i++) {
            if (substr($word, $i, 1) eq &getletter($tempx, $tempy)) {
              $count++;
              }
            elsif (&getletter($tempx, $tempy) ne ".") {
              $count = -100;
              };
            $tempy = $tempy - 1;
            $tempx = $tempx - 1;
            };
          if ($count > $where[3]) {
            $where[0] = $xpos;
            $where[1] = $ypos;
            $where[2] = $dir;
            $where[3] = $count;
            }
          elsif ($count == $where[3]) {
            $flip = random_uniform_integer(1,0,10);
            if ($flip < 3) {
              $where[0] = $xpos;
              $where[1] = $ypos;
              $where[2] = $dir;
              $where[3] = $count;
              };
            };
          
          };
        };
      };
    };
  };  

sub putword {
#  @where = (1,1,2,0);
  
  my ($word) = @_;
  local $xpos = 1;
  local $ypos = 1;
  local $dir = 1;
  local $wordlength = length($word);
#  &scanboard($word);
  $xpos = $where[0];
  $ypos = $where[1];
  $dir = $where[2];
#  exit 0;
  if ($dir == 1) {
    for ($i=0; $i<$wordlength; $i++) {
      &putletter($xpos, $ypos, substr($word, $i, 1));
      $ypos--;
      };
    }
  elsif ($dir == 2) {
    for ($i=0; $i<$wordlength; $i++) {
      &putletter($xpos, $ypos, substr($word, $i, 1));
      $xpos++;
      };
    }
  elsif ($dir == 3) {
    for ($i=0; $i<$wordlength; $i++) {
      &putletter($xpos, $ypos, substr($word, $i, 1));
      $ypos++;
      };
    }
  elsif ($dir == 4) {
    for ($i=0; $i<$wordlength; $i++) {
      &putletter($xpos, $ypos, substr($word, $i, 1));
      $xpos--;
      };
    }
  elsif ($dir == 5) {
    for ($i=0; $i<$wordlength; $i++) {
      &putletter($xpos, $ypos, substr($word, $i, 1));
      $xpos++;
      $ypos--;
      };
    }
  elsif ($dir == 6) {
    for ($i=0; $i<$wordlength; $i++) {
      &putletter($xpos, $ypos, substr($word, $i, 1));
      $xpos++;
      $ypos++;
      };
    }
  elsif ($dir == 7) {
    for ($i=0; $i<$wordlength; $i++) {
      &putletter($xpos, $ypos, substr($word, $i, 1));
      $xpos--;
      $ypos++;
      };
    }
  elsif ($dir == 8) {
    for ($i=0; $i<$wordlength; $i++) {
      &putletter($xpos, $ypos, substr($word, $i, 1));
      $xpos--;
      $ypos--;
      };
    };
  };




=head1 getlog

This script is almost pure perl (except the random number generator).

=head1 DESCRIPTION

This script creates a word search puzzle with the minimum of a 10 by 10 matrix and a maximum of a 99 by 99 matrix.

=head1 README

This script creates a word search puzzle with the minimum of a 10 by 10 matrix and a maximum of a 99 by 99 matrix.

=head1 INSTRUCTIONS

Your HTML form should include the following variables:

boolean inputs
0 means no (false), 1 means yes (true).
solution     = 0 or 1.  any other value defaults to 1 (print the solution).
linenumber   = 0 or 1.  any other value defaults to 0 (do not print line numbers next to the array).
dosort       = 0 or 1.  any other value defaults to 0 (do not sort out the list of words before printing them).
addwords     = 0 or 1.  any other value defaults to 0 (add word list to the random puzzle generator).
randompuzzle = 0 or 1.  any other value defaults to 0 (get a pre-made puzzle from the list others' sent in).


numeric inputs
height     = 10 to 99.  any other values default to 10 (matrix height).
width      = 10 to 99.  any other values default to 10 (matrix width).

words      = array of words to include in the puzzle.  If a single word is longer than the array height or width, the array is stretched to one larger than the maximum word size.
name       = name of the puzzle

Please see http://robertdell.dyndns.org/sites/wordsearch.shtml for the html and css sheets.

=head1 PREREQUISITES

Math::Random

=head1 COREQUISITES

CGI

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

Web

=cut













