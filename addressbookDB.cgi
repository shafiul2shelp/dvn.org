#!/usr/bin/perl

#      addressbook.cgi
#
#      Copyright (c) 2009 Larry Southern
#
#      This program is free software: you can redistribute it and/or modify
#      it under the terms of the GNU General Public License as published by
#      the Free Software Foundation, either version 3 of the License, or
#      (at your option) any later version.
#
#      This program is distributed in the hope that it will be useful,
#      but WITHOUT ANY WARRANTY; without even the implied warranty of
#      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#      GNU General Public License for more details.
#
#      You should have received a copy of the GNU General Public License
#      along with this program.  If not, see <http://www.gnu.org/licenses/>.

#
#
#      This is a cgi/frames representation of addressbook data stored in my local mysql database.
#      The general idea behind this program is to display, add, alter, and delete the addressbook
#      data I have on this database, for personal purposes.


use lib "/home/larry/pm";
use fats_mysql_db_constants;

use DBI();
use CGI (":standard");

my $VERSION = "20090721";

my $dbUser     = $fats_mysql_db_constants::databaseUser;
my $dbPassword = $fats_mysql_db_constants::databasePassword;

my $cgi = CGI->new;
my $dbh = DBI->connect("DBI:mysql:database=addressbook;host=localhost",$dbUser,$dbPassword)
	or die "Couldn't connect to database: " . DBI->errstr;

my $currentScreen;
my $cgiLoc     = "cgi-bin2";
my $scriptName = "addressbook.cgi";

my $nullString          = "NULL";
my $emptyString         = "EMPTY_STRING";

#to create idName of household, from an id
my $houseHoldNameIdExt  = "-givenName-familyName0";

#for sorting routines
my $separator= ":::";

#maximum email or phone entries
my $maxParams = 10;

#length in inputs
my $nameLen = 50;
my $idLen   = 70;

#html get parameters
my $paramString         = "Param";
my $getString           = "Get";
my $stateParam          = ".State";
my $idParam             = ".idParam";
my $idNameParam         = ".idNameParam";
my $familyNameParam     = ".familyNameParam";
my $givenNameParam      = ".givenNameParam";
my $companyNameParam    = ".companyNameParam";
my $birthdayParam       = ".birthdayParam";
my $emailCategoryParam  = ".emailCategoryParam";
my $emailNameParam      = ".emailNameParam";
my $emailIdParam        = ".emailIdParam";
my $phoneCategoryParam  = ".phoneCategoryParam";
my $phoneParam          = ".phoneParam";
my $phoneIdParam        = ".phoneIdParam";

#main panel frames
my $MainFrame           = "MainFrame";
my $SubMainFrame        = "SubMainFrame";
my $TitleBarFrame       = "TitleBarFrame";
my $IdNameFrame         = "IdNameFrame";
my $NameFrame           = "NameFrame";
my $CatFrame            = "CatFrame";
my $BirthdayFrame       = "BirthdayFrame";
my $PhoneFrame          = "PhoneFrame";
my $EmailFrame          = "EmailFrame";
my $AddressFrame        = "AddressFrame";
my $NotesFrame          = "NotesFrame";

#edit states 
my $EditIndividualFrame                 = "EditIndividualFrame";
my $EditIndividualTitle                 = "EditIndividualTitle";
my $EditIndividual                      = "EditIndividual";
my $AddIndividualEmails                 = "AddIndividualEmail";
my $RemoveIndividualEmails              = "RemoveIndividualEmail";
my $AddIndividualPhones                 = "AddIndividualPhone";
my $AddToHouseHold                      = "AddToHousehold";
my $EditHouseHold                       = "EditHousehold";
my $AddHouseHold                        = "Add Household or Company";
my $AddCategory                         = "Add Category";

#frame states 
my $MainFrameTarget      = "MainFrameTarget";
my $IdNameFrameTarget    = "IdNameFrameTarget";
my $SubMainFrameTarget   = "SubMainFrameTarget";
my $NameFrameTarget      = "NameFrameTarget";
my $NameSubFrameTarget   = "NameSubFrameTarget";
my $EditIndividualTarget = "EditIndividualTarget";

#tables from "addressbook"
my $addrtablePrimaryName = "addresstablePrimaryName";
my $addrtableName        = "addresstableName";
my $addrtableNotes       = "addresstableNotes";
my $addrtableAddress     = "addresstableAddress";
my $addrtableTel         = "addresstableTel";
my $addrtableEmail       = "addresstableEmail";
my $addrtableCatTables   = "addresstableCategoryTables";

#fields from tables in "addressbook"
my $idField          = "id";
my $idNameField      = "idName";
my $adrCityField     = "adrCity";
my $adrPostCodeField = "adrPostCode";
my $adrRegionField   = "adrRegion";
my $adrStreetField   = "adrStreet";
my $birthdayField    = "birthday";
my $categoryField    = "category";
my $companyNameField = "companyName";
my $emailField       = "email";
my $emailIdField     = "idEmail";
my $familyNameField  = "familyName";
my $givenNameField   = "givenName";
my $notesField       = "notes";
my $telField         = "tel";
my $telIdField       = "idTel";

#internal hash table for names
my $intNameHashGiven     =  "given";
my $intNameHashFamily    =  "family";
my $intNameHashCompany   =  "company";

#internal hash table for phone numbers
my $intPhoneHashCategory =  "category";
my $intPhoneHashPhone    =  "phone";

#internal hash table for email addresses
my $intEmailHashCategory =  "category";
my $intEmailHashEmail    =  "email";

#internal hash table for addresses "addrHash"
my $intAddressHashCity     =  "city";
my $intAddressHashPostCode =  "postcode";
my $intAddressHashRegion   =  "region";
my $intAddressHashStreet   =  "street";

my %Pages =
(
	$MainFrame                           => \&mainFrame,
	$SubMainFrame                        => \&subMainFrame,
	$TitleBarFrame                       => \&titleBarFrame,
	$IdNameFrame                         => \&idNameFrame,
	$NameFrame                           => \&nameFrame,
	$CatFrame                            => \&catFrame,
	$CatTitle                            => \&catTitle,
	$CatContent                          => \&catContent,
	$BirthdayFrame                       => \&birthdayFrame,
	$BirthdayTitle                       => \&birthdayTitle,
	$BirthdayContent                     => \&birthdayContent,
	$PhoneFrame                          => \&phoneFrame,
	$PhoneTitle                          => \&phoneTitle,
	$PhoneContent                        => \&phoneContent,
	$EmailFrame                          => \&emailFrame,
	$EmailTitle                          => \&emailTitle,
	$EmailContent                        => \&emailContent,
	$AddressFrame                        => \&addressFrame,
	$AddressTitle                        => \&addressTitle,
	$AddressContent                      => \&addressContent,
	$NotesFrame                          => \&notesFrame,
	$NotesTitle                          => \&notesTitle,
	$NotesContent                        => \&notesContent,
	$EditIndividualFrame                 => \&editIndividualFrame,
	$EditIndividualTitle                 => \&editIndividualTitle,
	$EditIndividual                      => \&editIndividual,
	$EditIndividualNames                 => \&editIndividualNames,
	$EditIndividualBirthday              => \&editIndividualBirthday,
	$EditIndividualEmails                => \&editIndividualEmails,
	$AddIndividualEmails                 => \&addIndividualEmail,
	$RemoveIndividualEmails              => \&removeIndividualEmails,
	$EditIndividualPhones                => \&editIndividualPhones,
	$AddIndividualPhones                 => \&addIndividualPhones,
	$EditHouseHold                       => \&editHouseHold,
	$AddToHouseHold                      => \&addToHouseHold,
	$AddHouseHold                        => \&addHouseHold,
	$AddCategory                         => \&addCategory,
);

sub getNamesFromNameId()
{
	(my $inputNameId) = @_;
	chomp($inputNameId);

	my $statement = $dbh->prepare("select ${familyNameField}, ${givenNameField}, ${companyNameField} "
		. "from ${addrtableName} where ${idNameField} = '${inputNameId}'") 
		or die "Couldn't prepare statement: " . $dbh->errstr;

	$statement->execute();
	my @returnVal = $statement->fetchrow_array();

	return @returnVal;
}

sub getBirthdayFromNameId()
{
	(my $inputNameId) = @_;
	chomp($inputNameId);

	my $statement = $dbh->prepare("select ${birthdayField} from ${addrtableName} "
		. "where ${idNameField} = '${inputNameId}'")
		or die "Couldn't prepare statement: " . $dbh->errstr;

	$statement->execute();
	my @returnVal = $statement->fetchrow_array();

	return $returnVal[0];
}

sub getForDisplayFromNameId()
{
	(my $inputNameId) = @_;
	my @result = &getNamesFromNameId($inputNameId);
	return &getDisplay(${result}[0],${result}[1],${result}[2]);
}

sub getDisplay()
{
	($fn,$gn,$cn) = @_;
	my $displayName = "";

	if   ($fn ne $nullString) { $displayName = $fn . ", " . $gn; }
	elsif($gn ne $nullString) { $displayName = $gn; }
	elsif($cn ne $nullString) { $displayName = $cn; }
	else {}

	return $displayName;
}

sub icsort { lc($a) cmp lc($b); }

sub makeMainIdNameHsh
{
	my %mainNamesHash;

	my $statement = $dbh->prepare("select ${familyNameField}, ${givenNameField}, ${companyNameField}, ${idField} "
		. "from ${addrtablePrimaryName}") or die "Couldn't prepare statement: " . $dbh->errstr;
	$statement->execute();
	while (my @result = $statement->fetchrow_array())
	{
		my $idn = ${result}[3];
		$mainNamesHash{$idn} = &getDisplay(${result}[0],${result}[1],${result}[2]);
	}

	return \%mainNamesHash;
}

sub makeMainIdNameScrollContent
{
	my @displayArray;
	my $displayNamesHash = &makeMainIdNameHsh;

	for my $k (sort keys %$displayNamesHash)
	{
		my $s = $$displayNamesHash{$k};
		push(@displayArray,${s} . ${separator} . "<a href=\"/${cgiLoc}/${scriptName}\?${stateParam}=${SubMainFrame}\&${idParam}=${k}\" target=${SubMainFrameTarget}>${s}</a><br>\n");
	}
	return (sort icsort @displayArray);
}

sub makeMainIdNameScroll
{
	my @arrayOutput = &makeMainIdNameScrollContent();
	my @out;

	for my $sortString (@arrayOutput)
	{ 
		($string = $sortString) =~ s/^.*${separator}//;
		push(@out,$string);
	}

	return @out;
}

sub getDefaultMainIdName
{
	my @arrayOutput = &makeMainIdNameScrollContent();
	my $returnLine = $arrayOutput[0];

	$returnLine =~ s/.*&${idParam}=([^"]*)".*/\1/;
	return $returnLine;
}

sub makeNameScrollContent
{
	(my $inputId) = @_;
	chomp($inputId);

	my @idNameArray;
	my $statement = $dbh->prepare("select ${familyNameField}, ${givenNameField}, ${companyNameField}, ${idField}, "
		. "${idNameField} from ${addrtableName} where ${idField} = " . $dbh->quote(${inputId}))
		or die "Couldn't prepare statement: " . $dbh->errstr;

	$statement->execute();
	while (my @result = $statement->fetchrow_array())
	{
		my $displayName;
		my $fn           = ${result}[0];
		my $gn           = ${result}[1];
		my $cn           = ${result}[2];
		my $idOutput     = ${result}[3];
		my $idNameOutput = ${result}[4];

		if   ($fn ne $nullString) { $displayName = $fn . ", " . $gn; }
		elsif($gn ne $nullString) { $displayName = $gn; }
		elsif($cn ne $nullString) { $displayName = $cn; }
		else {}

		push(@idNameArray,"${displayName}${separator}${idOutput}${separator}${idNameOutput}");
	}

	return (sort icsort @idNameArray);
}

sub getNameScrollDefault
{
	(my $inputId) = @_;
	my @idNameArray = &makeNameScrollContent($inputId);
	my $returnLine = $idNameArray[0];

	$returnLine =~ s/.*${separator}.*${separator}(.*)/\1/;

	return $returnLine;
}

sub makeNameScroll
{
	(my $inputId) = @_;
	my @idNameArray = &makeNameScrollContent($inputId);
	my @stdoutArray;

	for my $nameIdString (sort icsort @idNameArray)
	{
		my(${dn},${ido},${idno}) = split(${separator},$nameIdString);
		push(@stdoutArray,"<a href=\"/${cgiLoc}/${scriptName}\?${stateParam}=${SubMainFrame}\&${idParam}=${ido}\&${idNameParam}=${idno}\" target=${SubMainFrameTarget}>${dn}</a><br>\n");
	}

	return @stdoutArray;
}

sub getAllCat()
{
	my @outputArray;

	my $statement = $dbh->prepare("select ${idField} from ${addrtableCatTables}")
		or die "Couldn't prepare statement: " . $dbh->errstr;
	$statement->execute();

	while (my @result = $statement->fetchrow_array())
	{
		(my $cat) = @result;
		chomp($cat);
		push(@outputArray,$cat);
	}

	return @outputArray;
}

sub makeCatContent
{
	(my $inputId) = @_;
	chomp($inputId);

	my @outputArray;

	my @catArray = &getAllCat();

	for my $c (@catArray)
	{
		my $statement = $dbh->prepare("select ${idField} from ${c} where id = "
			. $dbh->quote(${inputId})) or die "Couldn't prepare statement: " . $dbh->errstr;
		$statement->execute();

		while (my @result = $statement->fetchrow_array())
		{
			(my $idOutput) = @result;
			chomp($idOutput);
			if($idOutput != /^$/) { push (@outputArray,$c); }
		}
	}

	return @outputArray;
}

sub getBirthdayFromNameId()
{
	(my $inputIdName) = @_;

	my $statement = $dbh->prepare("select $birthdayField from $addrtableName where $idNameField = '$inputIdName'")
		or die "Couldn't prepare statement: " . $dbh->errstr;
	$statement->execute();
	my @result = $statement->fetchrow_array();

	return $result[0];
}

sub getEmailListFromNameId()
{
	(my $inputIdName) = @_;
	(my $returnHash) = &getTxtCatListFromNameId($inputIdName, $intEmailHashCategory,$intEmailHashEmail,
		$categoryField, $emailField, $emailIdField, $addrtableEmail);
	return $returnHash;

}

sub getPhoneListFromNameId()
{
	(my $inputIdName) = @_;
	(my $returnHash) = &getTxtCatListFromNameId($inputIdName, $intPhoneHashCategory,$intPhoneHashPhone,
		$categoryField, $telField, $telIdField, $addrtableTel);
	return $returnHash;
}

sub getTxtCatListFromNameId
{
	(my $inputIdName, $intHashCat, $intHashTxt, $catField, $txtField, $idField, $tableName) = @_;
	my %outputHash;

	my $statement = $dbh->prepare("select $catField, $txtField, $idField from $tableName "
		. "where $idNameField = '$inputIdName'") or die "Couldn't prepare statement: " . $dbh->errstr;
	$statement->execute();

	while (my @result = $statement->fetchrow_array())
	{
		my $resultId     = $result[2];
		my %innerHash =
		(
			$intHashCat => $result[0],
			$intHashTxt => $result[1],
		);
		$outputHash{$resultId} = \%innerHash;
	}

	return \%outputHash;
}

sub getAddressListFromId()
{
	(my $inputId) = @_;
	my @outputArray;

	my $statement = $dbh->prepare("select $adrStreetField, $adrCityField, $adrPostCodeField, $adrRegionField "
		. "from $addrtableAddress where $idField = '$inputId'")
		or die "Couldn't prepare statement: " . $dbh->errstr;
	$statement->execute();

	while (my @result = $statement->fetchrow_array())
	{
		my %addrHash =
		(
			$intAddressHashStreet   => $result[0],
			$intAddressHashCity     => $result[1],
			$intAddressHashPostCode => $result[2],
			$intAddressHashRegion   => $result[3]
		);
		push(@outputArray,\%addrHash);
	}

	return @outputArray;
}

sub getNotesFromId()
{
	(my $inputId) = @_;
	my @outputArray;

	my $statement = $dbh->prepare("select $notesField from $addrtableNotes where $idField = '$inputId'")
		or die "Couldn't prepare statement: " . $dbh->errstr;
	$statement->execute();

	while (my @result = $statement->fetchrow_array())
	{
		push(@outputArray,"$result[0]");
	}

	return @outputArray;
}

sub mainFrame()
{
	my $defaultIdParam = &getDefaultMainIdName;
	my $currentId = param($idParam) || $defaultIdParam;

	my $defaultIdName = &getNameScrollDefault($currentId);
	my $currentIdName = param($idNameParam) || $defaultIdName;

	print $cgi->header;
	print ("<FRAMESET COLS=\"20%,*\">\n");
	print ("\t<FRAME SRC=\"/$cgiLoc/$scriptName\?$stateParam=$IdNameFrame\"    NAME=$IdNameFrameTarget  SCROLLING=AUTO>\n");
	print ("\t<FRAME SRC=\"/$cgiLoc/$scriptName\?$stateParam=$SubMainFrame\&${idParam}=${currentId}\&${idNameParam}=${currentIdName}\"  NAME=$SubMainFrameTarget SCROLLING=AUTO>\n");
	print ("\t<NOFRAMES>\n");
	print ("\t\t<H1>ADDRESS BOOK</H1>\n");
	print ("\t\tAddress Book only works with frame support\n");
	print ("\t</NOFRAMES>\n");
	print ("</FRAMESET>\n");
}

sub subMainFrame
{
	my $currentId = param($idParam);
	my $defaultIdName = &getNameScrollDefault($currentId);
	my $currentIdName = param($idNameParam) || $defaultIdName;

	print $cgi->header;
	print ("<FRAMESET ROWS=\"5%,25%,15%,55%\"/>\n");
	print ("\t<FRAMESET COLS=\"100%\"/>\n");
	print ("\t\t<FRAME SRC=\"/$cgiLoc/$scriptName\?$stateParam=$TitleBarFrame\&${idParam}=${currentId}\&${idNameParam}=${currentIdName}\" NAME=$NameSubFrameTarget SCROLLING=NO>\n");
	print ("\t</FRAMESET>\n");
	print ("\t<FRAMESET COLS=\"40%,30%,30%\"/>\n");
	print ("\t\t<FRAME SRC=\"/$cgiLoc/$scriptName\?$stateParam=$NameFrame\&${idParam}=${currentId}\&${idNameParam}=${currentIdName}\" NAME=$NameFrameTarget SCROLLING=AUTO>\n");
	print ("\t\t<FRAME SRC=\"/$cgiLoc/$scriptName\?$stateParam=$CatFrame\&${idParam}=${currentId}\"   NAME=$NameSubFrameTarget SCROLLING=AUTO>\n");
	print ("\t\t<FRAME SRC=\"/$cgiLoc/$scriptName\?$stateParam=$BirthdayFrame\&${idNameParam}=${currentIdName}\" NAME=$NameSubFrameTarget SCROLLING=AUTO>\n");
	print ("\t</FRAMESET>\n");
	print ("\t<FRAMESET COLS=\"50%,50%\"/>\n");
	print ("\t\t<FRAME SRC=\"/$cgiLoc/$scriptName\?$stateParam=$PhoneFrame\&${idNameParam}=${currentIdName}\" NAME=$NameSubFrameTarget SCROLLING=AUTO>\n");
	print ("\t\t<FRAME SRC=\"/$cgiLoc/$scriptName\?$stateParam=$EmailFrame\&${idParam}=${currentId}\&${idNameParam}=${currentIdName}\" NAME=$NameSubFrameTarget SCROLLING=AUTO>\n");
	print ("\t\t</FRAMESET>\n");
	print ("\t\t<FRAMESET COLS=\"50%,50%\"/>\n");
	print ("\t\t\t<FRAME SRC=\"/$cgiLoc/$scriptName\?$stateParam=$AddressFrame\&${idParam}=${currentId}\" NAME=$NameSubFrameTarget SCROLLING=AUTO>\n");
	print ("\t\t\t<FRAME SRC=\"/$cgiLoc/$scriptName\?$stateParam=$NotesFrame\&${idParam}=${currentId}\"   NAME=$NameSubFrameTarget SCROLLING=AUTO>\n");
	print ("\t\t</FRAMESET>\n");
	print ("\t</FRAMESET>\n");
	print ("\t<NOFRAMES>\n");
	print ("\t\t<H1>ADDRESS BOOK</H1>\n");
	print ("\t\tAddress Book only works with frame support\n");
	print ("\t</NOFRAMES>\n");
	print ("</FRAMESET>\n");
}

sub getHouseHoldNameFromId()
{
	(my $inputId) = @_;
	chomp($inputId);
	my $returnVal;

	my $statement = $dbh->prepare("select ${familyNameField}, ${givenNameField}, ${companyNameField}, ${idField} "
		. "from ${addrtablePrimaryName} where ${id} = '$inputId'") 
		or die "Couldn't prepare statement: " . $dbh->errstr;
	$statement->execute();
	my @result = $statement->fetchrow_array();
	$returnVal = &getDisplay(${result}[0],${result}[1],${result}[2]);

	return $returnVal;
}

sub titleBarFrame()
{
	print $cgi->header;
	print $cgi->start_html("titleBar");
	print "<form name=\"input\" action=\"/${cgiLoc}/${scriptName}\" method=\"get\" target=${MainFrameTarget}>\n";
	print "<b>AddressBook</b>\n";
	print "\t<input type=\"submit\" name=\"$stateParam\" value=\"${AddHouseHold}\"\/>\n";
	print "\t<input type=\"submit\" name=\"$stateParam\" value=\"${AddCategory}\"\/>\n";
	print "</form>\n";
	print $cgi->end_html();
}

sub idNameFrame()
{
	my @displayStrings = &makeMainIdNameScroll;
	print $cgi->header;
	print $cgi->start_html("idNames");
	for my $dn (@displayStrings) { print "\t$dn\n"; }
	print $cgi->end_html();
}

sub nameFrame()
{
	my $currentId     = param($idParam);
	my $currentIdName = param($idNameParam);

	my ($currentName)   = &getForDisplayFromNameId($currentIdName);
	my ($houseHoldName) = &getHouseHoldNameFromId($currentId);

	my @idNames = &makeNameScroll($currentId);

	print $cgi->header;
	print $cgi->start_html("idNames");
	print "<form name=\"input\" action=\"/${cgiLoc}/${scriptName}\" method=\"get\" target=_top>\n";
	print "\t<input type=\"hidden\" name=\"$idParam\"      value=\"${currentId}\"\/>";
	print "\t<input type=\"hidden\" name=\"$idNameParam\"  value=\"${currentIdName}\"\/>";
	print "\t<input type=\"hidden\" name=\"$stateParam\"   value=\"${EditIndividualFrame}\"\/>";
	print "\t<center><input type=\"submit\" value=\"Edit Individual: ${currentName}\"\/><\/center>\n";
	print "</form>\n";
	print "<form name=\"input\" action=\"/${cgiLoc}/${scriptName}\" method=\"get\" target=${MainFrameTarget}>\n";
	print "\t<input type=\"hidden\" name=\"$idParam\"      value=\"${currentId}\"\/>";
	print "\t<input type=\"hidden\" name=\"$stateParam\"   value=\"${EditHousehold}\"\/>";
	print "\t<center><input type=\"submit\" value=\"Edit HouseHold or Company: ${houseHoldName}\"\/><\/center>\n";
	print "</form>\n";
	print "<form name=\"input\" action=\"/${cgiLoc}/${scriptName}\" method=\"get\" target=${MainFrameTarget}>\n";
	print "\t<input type=\"hidden\" name=\"$idParam\"      value=\"${currentId}\"\/>";
	print "\t<input type=\"hidden\" name=\"$stateParam\"   value=\"${AddToHouseHold}\"\/>";
	print "\t<center><input type=\"submit\" value=\"Add Person to Household or Company: ${houseHoldName}\"\/><\/center>\n";
	print "</form>\n";
	for my $dn (@idNames) { print "\t$dn\n"; }
	print $cgi->end_html();
}

sub catFrame()
{
	my $currentId     = param($idParam);
	my @catagories    = &makeCatContent($currentId);
	print $cgi->header;
	print $cgi->start_html("catFrame");
	print "<b><center>Categories</center></b>\n";
	for my $c (@catagories) { print "\t$c<br>\n"; }
	print $cgi->end_html();
}

sub birthdayFrame()
{
	my $currentIdName = param($idNameParam);
	my $birthdayText = &getBirthdayFromNameId($currentIdName);
	print $cgi->header;
	print $cgi->start_html("birthdayFrame");
	print "<b><center>Birthday</center></b>\n";
	print "$birthdayText\n";
	print $cgi->end_html();
}

sub phoneFrame()
{
	my $currentIdName = param($idNameParam);
	my ($phoneHash) = &getPhoneListFromNameId($currentIdName);
	print $cgi->header;
	print $cgi->start_html("phoneFrame");
	print "<b><center>Phone Numbers</center></b>\n";
	print "\t<table>\n";
	print "\t\t<tr><td width=\"200\"/><td width=\"200\"/></tr>\n";
	for my $k (keys %$phoneHash) 
	{
		my $innerHash   = $$phoneHash{$k};
		my $catOutput   = $$innerHash{$intPhoneHashCategory};
		my $phoneOutput = $$innerHash{$intPhoneHashPhone};
		my $line;

		if($catOutput ne $nullString) { $line = "<tr><td>$catOutput</td><td>$phoneOutput</td></tr>"; }
		else                          { $line = "<tr><td>$phoneOutput</td></tr>"; }

		print "$line\n";
	}
	print "\t</table>\n";
	print $cgi->end_html();
}

sub emailFrame()
{
	my $currentIdName = param($idNameParam);
	my ($emailHashList) = &getEmailListFromNameId($currentIdName);
	print $cgi->header;
	print $cgi->start_html("emailFrame");
	print "<b><center>Email Addresses</center></b>\n";
	print "\t<table>\n";
	print "\t\t<tr><td width=\"200\"/><td width=\"200\"/></tr>\n";
	for my $hashKeyOfList (sort keys %$emailHashList) 
	{
		my $l = $$emailHashList{$hashKeyOfList};
		my $emailOutput = $$l{$intEmailHashEmail};

		if($emailOutput ne $nullString)
		{
			my $catOutput   = $$l{$intEmailHashCategory};
			my $line;

			if($catOutput ne $nullString) { $line = "<tr><td>$catOutput</td><td>$emailOutput</td></tr>\n"; }
			else                          { $line = "<tr><td>$emailOutput</td></tr>\n"; }

			print "$line\n";
		}

	}
	print "\t</table>\n";
	print $cgi->end_html();
}


sub addressFrame()
{
	my $currentId = param($idParam);
	my @addresses = &getAddressListFromId($currentId);
	print $cgi->header;
	print $cgi->start_html("addressContent");
	print "<b><center>Addresses</center></b>\n";
	for my $a (@addresses)
	{
		print "$$a{$intAddressHashStreet}, $$a{$intAddressHashCity}, "
			. "$$a{$intAddressHashRegion}, $$a{$intAddressHashPostCode}";
	}
	print $cgi->end_html();
}

sub notesFrame()
{
	my $currentId = param($idParam);
	my @notes = &getNotesFromId($currentId);
	print $cgi->header;
	print $cgi->start_html("notesFrame");
	print "<b><center>Notes</center></b>\n";
	for my $n (@notes) { print "$n<br>\n"; }
	print $cgi->end_html();
}

sub editIndividualFrame()
{
	my $currentId = param($idParam);
	my $currentIdName = param($idNameParam);

	print $cgi->header;
	print ("<FRAMESET ROWS=\"10%,90%\" COLS=\"100%\"/>\n");
	print ("\t<FRAME SRC=\"/$cgiLoc/$scriptName\?$stateParam=${EditIndividualTitle}\&${idNameParam}=${currentIdName}\"    NAME=$EditIndividualTarget SCROLLING=AUTO>\n");
	print ("\t<FRAME SRC=\"/$cgiLoc/$scriptName\?$stateParam=${EditIndividual}\&${idParam}=${currentId}\&${idNameParam}=${currentIdName}\" NAME=$EditIndividualTarget SCROLLING=AUTO>\n");
	print ("\t<NOFRAMES>\n");
	print ("\t\t<H1>ADDRESS BOOK</H1>\n");
	print ("\t\tAddress Book only works with frame support\n");
	print ("\t</NOFRAMES>\n");
	print ("</FRAMESET>\n");
}

sub editIndividualTitle
{
	my $currentIdName = param($idNameParam);
	my $displayName = &getForDisplayFromNameId($currentIdName);
	print $cgi->header;
	print $cgi->start_html("editIndividualTitle");
	print "<center><b>Editing $displayName</b></center><br>\n";
	print $cgi->end_html();
}

sub editIndividual
{
	my $currentId      = param($idParam);
	my $currentIdName  = param($idNameParam);

	my @getParams      = $cgi->param();

	#get number and ids of changed birthdays, names, emails and phone numbers
	my %getVarsHash;
	for my $param (@getParams)
	{
		if ($param ne $idParam && $param ne $idNameParam)
		{
			my ($getVar)          = mkGetVarString($param);
			$$getVar              = param($param);
			$getVarsHash{$getVar} = $$getVar;
		}
	}


	my ($getNamesHash) = &mkGetNamesHash(\%getVarsHash);
	my %defaultNames;
	($defaultNames{$intNameHashFamily}, $defaultNames{$intNameHashGiven},
		$defaultNames{$intNameHashCompany}) = &getNamesFromNameId($currentIdName);
	my ($namesHsh) =                  &getNameChanges($currentIdName,$getNamesHash,\%defaultNames);

	my ($defaultBirthday) =           &getBirthdayFromNameId($currentIdName);
	my ($getBirthdayKey)  =           &mkGetVarString($birthdayParam);
	my ($birthday)        =           &getBirthdayChanges($currentIdName,$getVarsHash{$getBirthdayKey},$defaultBirthday);

	my ($getEmailAddressesHash) =     &mkEmailAddressesHash(\%getVarsHash);
	my ($defaultEmailAddressesHash) = &getEmailListFromNameId($currentIdName);
	my ($emailAddressesHash) =        &getEmailChanges($getEmailAddressesHash,$defaultEmailAddressesHash);

	my ($getPhoneNumbersHash)   =     &mkPhoneNumbersHash(\%getVarsHash);
	my ($defaultPhoneNumbersHash) =   &getPhoneListFromNameId($currentIdName);
	my ($phoneNumbersHash) =          &getPhoneChanges($getPhoneNumbersHash,$defaultPhoneNumbersHash);

	##########################
	#names form
	##########################
	print $cgi->header;
	print $cgi->start_html("editIndividual");
	print "<form name=\"text\" action=\"/${cgiLoc}/${scriptName}\" method=\"get\">\n";
	print "\t<input type=\"hidden\" name=\"$idParam\"      value=\"${currentId}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$idNameParam\"  value=\"${currentIdName}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$stateParam\"   value=\"${EditIndividual}\"\n\/>";
	print "\t\t<table>\n";
	print "\t\t<tr><td width=\"200\">Given Name:</td>\n";
	print "\t\t<td width=\"200\"><input type=\"text\" name=\"$givenNameParam\""
		. " value=\"$$namesHsh{$intNameHashGiven}\" size=\"$nameLen\""
	        . " maxlength=\"$maxNameLen\"></td></tr>\n";
	print "\t\t<tr><td>Family Name:</td>\n";
	print "\t\t<td><input type=\"text\" name=\"$familyNameParam\""
		. " value=\"$$namesHsh{$intNameHashFamily}\" size=\"$nameLen\""
	        . " maxlength=\"$maxNameLen\"></td></tr>\n";
	print "\t\t<tr><td>Company Name:</td>\n";
	print "\t\t<td><input type=\"text\" name=\"$companyNameParam\" "
		. " value=\"$$namesHsh{$intNameHashCompany}\" size=\"$nameLen\""
	        . " maxlength=\"$maxNameLen\"></tr></td>";
	print "\t\t</table>\n";
	print "\t<input type=\"submit\" value=\"Submit Name Changes..\">\n";
	print "</form>\n";

	print "<br>\n";

	##########################
	#birthday form
	##########################
	print "<form name=\"text\" action=\"/${cgiLoc}/${scriptName}\" method=\"get\">\n";
	print "\t<input type=\"hidden\" name=\"$idParam\"      value=\"${currentId}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$idNameParam\"  value=\"${currentIdName}\"\/>";
	print "\t<input type=\"hidden\" name=\"$stateParam\"   value=\"${EditIndividual}\"\/>";
	print "\t\t<table>\n";
	print "\t\t<tr><td width=\"200\">Birthday:</td>\n";
	print "\t\t<td width=\"200\"><input type=\"text\" name=\"$birthdayParam\" value=\"$birthday\""
		. " size=\"$nameLen\" maxlength=\"$maxNameLen\"></td>\n";
	print "\t\t</table>\n";
	print "\t<input type=\"submit\" value=\"Submit Birthday Change..\">\n";
	print "</form>\n";

	print "<br>\n";

	##########################
	#email form
	##########################
	my $iterator = 0;
	print "<form name=\"text\" action=\"/${cgiLoc}/${scriptName}\" method=\"get\">\n";
	print "\t<input type=\"hidden\" name=\"$idParam\"      value=\"${currentId}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$idNameParam\"  value=\"${currentIdName}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$stateParam\"   value=\"${EditIndividual}\"\n\/>";
	for my $e_id (keys %$emailAddressesHash)
	{
		my $emailInnerHash = $$emailAddressesHash{$e_id};
		print "\tEmail: \n";
		print "\t<input type=\"hidden\" name=\"${emailIdParam}${iterator}\" value=\"$e_id\">\n";
		print "\t<input type=\"text\" name=\"${emailCategoryParam}${iterator}\""
			. " value=\"$$emailInnerHash{$intEmailHashCategory}\" size=\"$nameLen\" maxlength=\"$maxNameLen\">\n";
		print "\t<input type=\"text\" name=\"${emailNameParam}${iterator}\""
			. " value=\"$$emailInnerHash{$intEmailHashEmail}\" size=\"$nameLen\" maxlength=\"$maxNameLen\">\n";
		print "\t<br>\n";
		$iterator++;
	}
	print "\t<input type=\"submit\" value=\"Submit Email Changes..\">\n";
	print "</form>\n";
	#add new email..
	print "<form name=\"text\" action=\"/${cgiLoc}/${scriptName}\" method=\"get\">\n";
	print "\t<input type=\"hidden\" name=\"$idParam\"      value=\"${currentId}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$idNameParam\"  value=\"${currentIdName}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$stateParam\"   value=\"${AddIndividualEmails}\"\n\/>";
	print "\t<input type=\"submit\" value=\"Add an Email Address..\">\n";
	print "</form>\n";

	#remove email..
	print "<form name=\"text\" action=\"/${cgiLoc}/${scriptName}\" method=\"get\">\n";
	print "\t<input type=\"hidden\" name=\"$idParam\"      value=\"${currentId}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$idNameParam\"  value=\"${currentIdName}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$stateParam\"   value=\"${RemoveIndividualEmails}\"\n\/>";
	print "\t<input type=\"submit\" value=\"Remove an Email Address..\">\n";
	print "</form>\n";
	print "<br>\n";

	##########################
	#phone form
	##########################
	$iterator = 0;
	print "<form name=\"text\" action=\"/${cgiLoc}/${scriptName}\" method=\"get\">\n";
	print "\t<input type=\"hidden\" name=\"$idParam\"      value=\"${currentId}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$idNameParam\"  value=\"${currentIdName}\"\/>";
	print "\t<input type=\"hidden\" name=\"$stateParam\"   value=\"${EditIndividual}\"\/>";
	for my $p_id (keys %$phoneNumbersHash)
	{
		my $phoneInnerHash = $$phoneNumbersHash{$p_id};
		print "Phone Number: ";
		print "<input type=\"hidden\" name=\"${phoneIdParam}${iterator}\" value=\"$p_id\">\n";
		print "<input type=\"text\" name=\"${phoneCategoryParam}${iterator}\""
			. " value=\"$$phoneInnerHash{$intPhoneHashCategory}\" size=\"$nameLen\" maxlength=\"$maxNameLen\">\n";
		print "<input type=\"text\" name=\"${phoneParam}${iterator}\""
			. " value=\"$$phoneInnerHash{$intPhoneHashPhone}\" size=\"$nameLen\" maxlength=\"$maxNameLen\">\n";
		print "<br>\n";
		$iterator++;
	}
	print "\t<input type=\"submit\" value=\"Submit Phone Changes..\">\n";
	print "</form>\n";

	#add new phone..
	print "<form name=\"text\" action=\"/${cgiLoc}/${scriptName}\" method=\"get\">\n";
	print "\t<input type=\"hidden\" name=\"$idParam\"      value=\"${currentId}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$idNameParam\"  value=\"${currentIdName}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$stateParam\"   value=\"${AddPhone}\"\n\/>";
	print "\t<input type=\"submit\" value=\"Add a Phone Number..\">\n";
	print "</form>\n";

	#remove phone..
	print "<form name=\"text\" action=\"/${cgiLoc}/${scriptName}\" method=\"get\">\n";
	print "\t<input type=\"hidden\" name=\"$idParam\"      value=\"${currentId}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$idNameParam\"  value=\"${currentIdName}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$stateParam\"   value=\"${RemovePhone}\"\n\/>";
	print "\t<input type=\"submit\" value=\"Remove a Phone Number..\">\n";
	print "</form>\n";
	print "<br>\n";
	print "<br>\n";

	print "<a href=\"/${cgiLoc}/${scriptName}\?${stateParam}=${MainFrame}\&${idParam}=${currentId}\&${idNameParam}=${currentIdName}\" target=_parent>Go back to addressbook</a><br>\n";
	print $cgi->end_html();
}

sub mkGetVarString
{
	my ($param) = @_;
	my $returnVal;
	($returnVal = $param) =~ s/\.(.*)$paramString/\1$getString/;
	return $returnVal;
}

sub mkGetNamesHash
{
	my ($getVarHash) = @_;
	my %returnHash;

	my ($getGivenName)   = &mkGetVarString($givenNameParam);
	my ($getFamilyName)  = &mkGetVarString($familyNameParam);
	my ($getCompanyName) = &mkGetVarString($companyNameParam);

	for my $k (%$getVarHash)
	{
		if($k eq $getGivenName)        { $returnHash{$intNameHashGiven}   =  $$getVarHash{$k}; }
		elsif($k eq $getFamilyName)  { $returnHash{$intNameHashFamily}  =  $$getVarHash{$k}; }
		elsif($k eq $getCompanyName) { $returnHash{$intNameHashCompany} =  $$getVarHash{$k}; }
		else {}
	}

	return \%returnHash;
}

sub mkEmailAddressesHash
{
	(my $getVarsHash) = @_;
	(my $returnHash) = &mkTxtCatHash($getVarsHash,$emailIdParam,$emailCategoryParam,
		$emailNameParam,$intEmailHashCategory,$intEmailHashEmail);
	return $returnHash;
}

sub mkPhoneNumbersHash
{
	(my $getVarsHash) = @_;
	(my $returnHash) = &mkTxtCatHash($getVarsHash,$phoneIdParam,$phoneCategoryParam,
		$phoneParam,$intPhoneHashCategory,$intPhoneHashPhone);
	return $returnHash;
}

sub mkTxtCatHash
{
	my ($getVarHash,$keyParam,$catParam,$txtParam,$intHashCat,$intHashTxt) = @_;
	my %returnHash;

	my $iterator = 0;
	while ($iterator <= $maxParams)
	{
		my ($getKeyId) = &mkGetVarString($keyParam) . $iterator;

		if(defined $$getVarHash{$getKeyId})
		{
			my $intHashKey = $$getVarHash{$getKeyId};
			my ($getCat)   = &mkGetVarString($catParam) . $iterator;
			my ($getTxt)   = &mkGetVarString($txtParam) . $iterator;

			my %innerHash =
			(
				$intHashCat => $$getVarHash{$getCat},
				$intHashTxt => $$getVarHash{$getTxt},
			);

			$returnHash{$intHashKey} = \%innerHash;
		}

		$iterator++;
	}

	return \%returnHash;
}

sub getNameChanges
{
	my ($inputNameId,$getNamesHsh,$defaultNamesHsh) = @_;
	my %returnHsh = 
	(
		$intNameHashGiven => $$defaultNamesHsh{$intNameHashGiven},
		$intNameHashFamily => $$defaultNamesHsh{$intNameHashFamily},
		$intNameHashCompany => $$defaultNamesHsh{$intNameHashCompany},
	);

	my $change = 0;

	#check if anything has changed
	for my $k (keys %$defaultNamesHsh)
	{
		if($$getNamesHsh{$k} ne "")
		{
			if($$getNamesHsh{$k} ne $$defaultNamesHsh{$k})
			{
				$returnHsh{$k} = $$getNamesHsh{$k};
				$change = 1;
			}
		}
	}

	#if changed make sql alter call
	if($change)
	{
		my $statement = $dbh->prepare("update ${addrtableName} set"
			. " ${familyNameField} = \'$returnHsh{$intNameHashFamily}\',"
			. " ${givenNameField} = \'$returnHsh{$intNameHashGiven}\',"
			. " ${companyNameField} = \'$returnHsh{$intNameHashCompany}\'"
			. " where ${idNameField} = '${inputNameId}'")
			or die "Couldn't prepare statement: " . $dbh->errstr;

		$statement->execute();
	}

	#return either changed hash, or unchanged one
	return \%returnHsh;
}

sub getEmailChanges
{
	my ($getEmailAddressesHash,$defaultEmailAddressesHash) = @_;
	my ($returnHash) = &getTxtCatChanges($getEmailAddressesHash,$defaultEmailAddressesHash,
		$intEmailHashCategory,$intEmailHashEmail,$addrtableEmail,$emailIdField,$categoryField,$emailField);
	return $returnHash;
}

sub getPhoneChanges
{
	my ($getPhoneNumbersHash,$defaultPhoneNumbersHash) = @_;
	my ($returnHash) = &getTxtCatChanges($getPhoneNumbersHash,$defaultPhoneNumbersHash,
		$intPhoneHashCategory,$intPhoneHashPhone,$addrtableTel,$telIdField,$categoryField,$telField);
	return $returnHash;
}

#for phone and email changes
sub getTxtCatChanges
{
	my ($getHash,$defaultHash,$catKey,$txtKey,$tableName,$idField,$catField,$txtField) = @_;
	my $change = 0;
	my %returnHash;

	#compare the hash of hashes to see if anything has changed
	for my $outerKey (keys %$defaultHash)
	{

		my $innerDefaultHash = $$defaultHash{$outerKey};
		#establish the default, then change if warrants

		my %returnInnerHash;
		for my $return_inner_key (%$innerDefaultHash)
		{
			$returnInnerHash{$return_inner_key} = $$innerDefaultHash{$return_inner_key};
		}

		if (defined $$getHash{$outerKey})
		{
			$change = 0;
			$getInnerHash     = $$getHash{$outerKey};

			for my $k (keys %$getInnerHash)
			{
				if($$getInnerHash{$k} ne "" && $$getInnerHash{$k} ne $emptyString)
				{

					if($$getInnerHash{$k} ne $returnInnerHash{$k})
					{
						$change = 1;
						$returnInnerHash{$k} = $$getInnerHash{$k};
					}
				}
			}

			if($change)
			{
				my $statement = $dbh->prepare("update ${tableName} set"
					. " ${catField}           = \'$returnInnerHash{$catKey}\',"
					. " ${txtField}           = \'$returnInnerHash{$txtKey}\'"
					. " where ${idField}      = '${outerKey}'")
					or die "Couldn't prepare statement: " . $dbh->errstr;
	
				$statement->execute();
			}
		}
		$returnHash{$outerKey} = \%returnInnerHash;
	}

	return \%returnHash;
}

sub getBirthdayChanges
{
	my ($inputNameId,$getBirthday,$defaultBirthday) = @_;
	my $returnBVal = $defaultBirthday;
	my $change = 0;

	if ($getBirthday ne "")
	{
		if ($getBirthday ne $defaultBirthday)
		{
			$returnBVal = $getBirthday;
			$change = 1;
		}
	}

	if($change)
	{
		my $statement = $dbh->prepare("update ${addrtableName} set"
			. " ${birthdayField} = \'${returnBVal}\' where"
			. " ${idNameField} = '${inputNameId}'")
			or die "Couldn't prepare statement: " . $dbh->errstr;

		$statement->execute();
	}

	return $returnBVal;
}

sub addIndividualEmail
{
	my $currentIdName    = param($idNameParam);
	my $currentId        = param($idParam);

	my $getEmailName     = param($emailNameParam) || $emptyString;
	my $getCategoryParam = param($emailCategoryParam) || $emptyString;

	if ($getEmailName ne $emptyString)
	{
		&mkNewEmailEntry($currentIdName, $getEmailName, $getCategoryParam);
	}


	print $cgi->header;
	print $cgi->start_html("addIndividualEmail");
	print "<form name=\"text\" action=\"/${cgiLoc}/${scriptName}\" method=\"get\">\n";
	print "\t<input type=\"hidden\" name=\"$idParam\"      value=\"${currentId}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$idNameParam\"  value=\"${currentIdName}\"\n\/>";
	print "\t<input type=\"hidden\" name=\"$stateParam\"   value=\"${AddIndividualEmails}\"\n\/>";
	print "\t<input type=\"text\" name=\"${emailCategoryParam}\""
		. " value=\"$intEmailHashCategory}\" size=\"$nameLen\" maxlength=\"$maxNameLen\">\n";
	print "\t<input type=\"text\" name=\"${emailNameParam}\""
		. " value=\"$$emailInnerHash{$intEmailHashEmail}\" size=\"$nameLen\" maxlength=\"$maxNameLen\">\n";
	print "\t<br>\n";
	print "\t<input type=\"submit\" value=\"Add Email..\">\n";
	print "</form>\n";

	print "<a href=\"/${cgiLoc}/${scriptName}\?${stateParam}=${EditIndividual}\&${idParam}=${currentId}\&${idNameParam}=${currentIdName}\" target=_self>Go back to edit individual</a><br>\n";
	print "<a href=\"/${cgiLoc}/${scriptName}\?${stateParam}=${MainFrame}\&${idParam}=${currentId}\&${idNameParam}=${currentIdName}\" target=_parent>Go back to main addressbook</a><br>\n";
	print $cgi->end_html();
	print $cgi->end_html();
}

sub addIndividualPhone
{
	print $cgi->header;
	print $cgi->start_html("addIndividualPhone");
	print "This is addIndividualPhone\n";
	print "<a href=\"/${cgiLoc}/${scriptName}\?${stateParam}=${EditIndividual}\&${idParam}=${currentId}\&${idNameParam}=${currentIdName}\" target=_self>Go back to edit individual</a><br>\n";
	print "<a href=\"/${cgiLoc}/${scriptName}\?${stateParam}=${MainFrame}\&${idParam}=${currentId}\&${idNameParam}=${currentIdName}\" target=_parent>Go back to main addressbook</a><br>\n";
	print $cgi->end_html();
}

sub addToHouseHold()
{
	my $currentId = param($idParam);
	print $cgi->header;
	print $cgi->start_html("addToHouseHold");
	print "currentId is $currentId<br>\n";
	print "<a href=\"/${cgiLoc}/${scriptName}\?${stateParam}=${MainFrame}\&${idParam}=${currentId}\" target=${MainFrameTarget}>Go back to addressbook</a><br>\n";
	print $cgi->end_html();
}

sub addHouseHold()
{
	print $cgi->header;
	print $cgi->start_html("addHouseHold");
	print "<a href=\"/${cgiLoc}/${scriptName}\?${stateParam}=${MainFrame}\" target=${MainFrameTarget}>Go back to addressbook</a><br>\n";
	print $cgi->end_html();
}

sub addCategory()
{
	print $cgi->header;
	print $cgi->start_html("addCategory");
	print "<a href=\"/${cgiLoc}/${scriptName}\?${stateParam}=${MainFrame}\" target=${MainFrameTarget}>Go back to addressbook</a><br>\n";
	print $cgi->end_html();
}


sub mkEmailIdPatternFromIdName
{
	my ($currentId,$currentIdName) = @_;
	my $email = "email";
	my ($idNameNum) = &getIdNameNum($currentIdName);
	return $currentId . "-" . $email . $idNameNum . "-";
}

sub getUniqIdFromPattern
{
	my ($idPattern,$idField,$tableName) = @_;
	my $returnVal = $emptyString;
	my $iterator = 0;

	while ($iterator <= $maxParams)
	{
		my $idString = $idPattern . $iterator;

		my $statement = $dbh->prepare("select $idField from $tableName "
			. "where $idField = '$idString'");
		$statement->execute();
		my @returnVal = $statement->fetchrow_array();
		my $idVal = $returnVal[0] || $emptyString;

		if ($idVal eq $emptyString)
		{
			$returnVal = $idString;
			last;
		}
		$iterator++;
	}

	return $returnVal;
}

sub mkNewEmailEntry()
{
	my ($currentId, $currentIdName, $emailName, $emailCat) = @_;
	my $idPattern = &mkEmailIdPatternFromIdName($currentId,$currentIdName);
	my ($emailId) = &getUniqIdFromIdName($idPattern, $emailIdField ,$addrtableEmail);

	my $statement = $dbh->prepare("insert into $addrtableEmail \($idField, $idNameField,"
		. " $emailIdField, $emailField, $categoryField\) values ('$currentId','$currentIdName',"
		. " '$emailId', '$emailName','$emailCat')");
}

sub getIdNameNum()
{
	my ($currentIdName) = @_;
	my $returnVal;
	my $familyName = "familyName";
	($returnVal = $currentIdName) =~ s/.*$familyName(\d*)$/\1/;
	return $returnVal;
}


sub main()
{
	$currentScreen = param($stateParam) || $MainFrame;
	die "No screen for $currentScreen" unless $Pages{$currentScreen};

	while (my($screenName, $function) = each %Pages)
	{
		if($screenName eq $currentScreen)
		{
			$function->($screenName);
		}
	}
	exit;
}

&main;

=head1 NAME

addressbook.cgi

=head1 DESCRIPTION

This is a cgi/frames representation of addressbook data stored in my local mysql database.
The general idea behind this program is to display, add, alter, and delete the addressbook
data I have on this database, for personal purposes.

=head1 README

THIS SOFTWARE DOES NOT COME WITH ANY WARRANTY WHATSOEVER. USE AT YOUR OWN RISK.

=head1 COREQUISITES

CGI
DBI
=pod OSNAMES

any

=pod SCRIPT CATEGORIES

Web

=cut
