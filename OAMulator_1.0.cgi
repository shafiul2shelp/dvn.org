#!/usr/bin/perl -w

# OAMulator.cgi: OAM emulator and OAMPL compiler
#
# Copyright (C) 2001-2004 Filippo Menczer, University of Iowa, and Indiana University
#
#    OAMulator is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    OAMulator is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with OAMulator; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

$|=1;
use strict;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw(:standard);
use Fcntl;

# Globals to deal with LOOP-END and IF-ENDIF statements
my (@loopstack, @ifstack);
# Maxumum running time parameters (helps detect endless loops in &execute)
my $maxTime = 10; # seconds
# OAMulator home
my $homeURL = 'http://informatics.indiana.edu/fil/OAM/';
# Installation place and date (if defined, will be used by &mycounter)
my $install = 'at IU since August 2003'; # may replace with undef or something like 'at PLACE since DATE'
# Background color
my $bg_color = 'FFFFCC'; # IUB yellow; '669999' for Iowa green

# CGI FORM
sub cgiform ($$$$) {
	my ($oampl, $oam, $input, $output) = @_;
	print start_form(-action=>"$0"); # this makes it work under the suEXEC wrapper
	print p(submit('Submit','Example'), submit('Submit','Compile'), 
		popup_menu('trace_option', ['No Register Trace','Fetch Trace','Execute Trace','Increment Trace']),
		checkbox('Show Memory'), submit('Submit','Execute'), submit('Submit','Clear'));
	print table(
		Tr({-align=>'CENTER'},
			th('OAMPL Source Code'),
			th('OAM Assembly Code')
		),
		Tr({-align=>'CENTER'},
			td(textarea(-override=>1, -name=>'oampl', -default=>$oampl, -rows=>10, -columns=>50)),
			td(textarea(-override=>1, -name=>'oam', -default=>$oam, -rows=>10, -columns=>50))
		),
		Tr({-align=>'CENTER'},
			th('Input (one per line)'),
			th('Output (trace and memory)')
		),
		Tr({-align=>'CENTER'},
			td(textarea(-override=>1, -name=>'input', -default=>$input, -rows=>10, -columns=>50)),
			td(textarea(-override=>1, -name=>'output', -default=>$output, -rows=>10, -columns=>50))
		)
	);
	print end_form();
}

# COMPILE
sub compile ($) {
	my @source = split(/\n/, $_[0]);
	my @memory;
	my %value;
	my @stmts = qw(write read assign loop end if endif);
	my $stmtchoice = join("|", @stmts);
	my $line = 0;
	for (@source) {
		$line++;
		/^\s*(.*?)\s*($|;)/; # yank spaces and comments
		$_ = $1;
		if (/^($stmtchoice)(?:$|\s+(.*)$)/i) {
			my $oamref = parse_oampl($1, $2, \@memory, \%value);
			return("Syntax", $line, '') unless (defined $oamref);
			push @memory, @$oamref;
		} else {
			return("Syntax", $line, '');
		}
	}
	return ("LOOP without END", $line, '') if @loopstack;
	return ("IF without ENDIF", $line, '') if @ifstack;
	push @memory, "HLT";
	addcomments(\@memory); # add addresses
	return (undef, undef, join("\n", @memory));
}

# PARSE OAMPL INTRUCTION
# return ref to array of OAM stmts or undef if syntax error
sub parse_oampl ($$\@\%) {
	my ($opcode, $arg, $memref, $valref) = @_;
	my $offset = scalar(@$memref); # will start at PC=1
	my @oam;
	if ($opcode =~ /^read$/i) { 
		# READ
		return undef unless ($arg =~ /^[a-z]\w*$/i);
		$offset++;
		push @oam, "LDA 0", @{lvalue($arg, $offset, $valref)};
	} elsif ($opcode =~ /^write$/i) { 
		# WRITE
		my $oamref = rvalue($arg, $offset, $valref);
		return undef unless (defined $oamref);
		push @oam, @$oamref, "STA 0";
	} elsif ($opcode =~ /^assign$/i) { 
		# ASSIGN
		return undef unless ($arg =~ /^([a-z]\w*)\s+(.*)$/i);
		my ($arg1, $arg2) = ($1, $2);
		my $oamref = rvalue($arg2, $offset, $valref);
		return undef unless (defined $oamref);
		$offset += scalar(@$oamref);
		push @oam, @$oamref;
		push @oam, @{lvalue($arg1, $offset, $valref)};
	} elsif ($opcode =~ /^loop$/i) { 
		# LOOP
		my $oamref = rvalue($arg, $offset, $valref);
		return undef unless (defined $oamref);
		$offset += scalar(@$oamref);
		push @oam, @$oamref;
		# remember address with BR placeholder to be filled at END
		push @loopstack, $offset + 1;
		$offset += 2;
		push @oam, "BR _", "NOOP", "STA $offset"; 
	} elsif ($opcode =~ /^end$/i) { 
		# END
		# retrieve location of BR placeholder and fix it
		$offset += 2;
		my $placeholder = pop @loopstack; 
		return undef unless defined $placeholder;
		$memref->[$placeholder - 1] = "BR $offset"; # will start at PC=1
		$offset = $placeholder + 1;
		push @oam, "LDA $offset", "DEC", "BRP $offset";
	} elsif ($opcode =~ /^if$/i) { 
		# IF
		my $oamref = rvalue($arg, $offset, $valref);
		return undef unless (defined $oamref);
		$offset += scalar(@$oamref);
		push @oam, @$oamref;
		# remember address with BRZ placeholder to be filled at ENDIF
		push @ifstack, $offset + 1;
		push @oam, "BRZ _"; 
	} elsif ($opcode =~ /^endif$/i) { 
		# ENDIF
		# retrieve location of BRZ placeholder and fix it
		my $placeholder = pop @ifstack;
		return undef unless defined $placeholder;
		$memref->[$placeholder - 1] = "BRZ $offset"; # will start at PC=1
	} else { 
		# error
		return undef;
	}
	return \@oam;
}

# RESOLVE EXPRESSIONS to ACC
# NB: we are making the simplifying assumption that 
#     expressions can have at most 1 level of nesting 
#     -- this weakens the language a bit!
# NB: strings are not allowed as operands
# return ref to array of OAM stmts or undef if syntax error
sub expression ($$$$) {
	my ($operator, $operands, $offset, $valref) = @_;
	my @oam;
	my %opcode = (
		'+' => 'ADD',
		'-' => 'SUB',
		'*' => 'MLT',
		'/' => 'DIV'
	);
	my $oamref;
	if ($operands =~ /^
			(-?\d+|[a-z]\w*|\([^\(\)]*\))
			\s+
			(-?\d+|[a-z]\w*|\([^\(\)]*\))
			$/ix) { # 2 operands (invert to handle /,- correctly)
		my ($op1, $op2) = ($1, $2);
		# place second operand in ACC
		$oamref = rvalue($op2, $offset, $valref);
		return undef unless (defined $oamref);
		$offset += scalar(@$oamref);
		push @oam, @$oamref;
		# store intermediate result (inefficient if this was already stored!)
		$offset += 3;
		push @oam, "STA $offset", "BR $offset", "NOOP";
		# place first operand in ACC
		$oamref = rvalue($op1, $offset, $valref);
		return undef unless (defined $oamref);
		push @oam, @$oamref;
		# place result in ACC
		push @oam, $opcode{"$operator"} . " $offset";
	} elsif ($operator eq '-' && $operands =~ 
			/^(-?\d+|[a-z]\w*|\([^\(\)]*\))$/i) { # 1 operand
		# place operand in ACC
		$oamref = rvalue($1, $offset, $valref);
		return undef unless (defined $oamref);
		push @oam, @$oamref;
		# place negated result in ACC
		push @oam, "NEG";
	} else { # error
		return undef;
	}
	return \@oam;
}

# RESOLVE RVALUE (const | var | expression) to ACC
# return ref to array of OAM stmts or undef if syntax error
sub rvalue ($$\%) {
	my ($arg, $offset, $valref) = @_;
	my @oam;
	if ($arg =~ /^("[^"]*"|-?\d+)$/) { # const
		push @oam, "SET $arg";
	} elsif ($arg =~ /^[a-z]\w*$/i) { # var
		return undef unless (exists $valref->{$arg});
		push @oam, "LDA $valref->{$arg}";
	} elsif ($arg =~ /^\(\s*([\+\-\*\/])\s+(.+?)\s*\)$/) { # expr
		my $oamref = expression($1, $2, $offset, $valref);
		return undef unless (defined $oamref);
		push @oam, @$oamref;
	} else { # error
		return undef;
	}
	return \@oam;
}

# STORE LVALUE USING SYMBOL LOOKUP TABLE
# return ref to array of OAM stmts
sub lvalue ($$\%) {
	my ($arg, $offset, $valref) = @_;
	my @oam;
	if (exists $valref->{$arg}) {
		push @oam, "STA $valref->{$arg}";
	} else {
		$offset += 3;
		$valref->{$arg} = $offset;
		push @oam, "STA $offset", "BR $offset", "NOOP";
	}
	return \@oam;
}

# EXECUTE
sub execute ($$$$) {
	my @memory = split(/\n/, shift(@_));
	unshift @memory, ''; # load code at PC = 1
	my @input = split(/\n/, shift(@_)); # input can be undef!
	my ($output, $trace) = ('', '');
	my $clock = 0;
	my $error = undef;
	my $tr_opt = shift;
	my $show_mem = shift;
	my ($PC, $ACC, $IR, $AR, $B) = (1, '?', '?', '?', '?');
	until (defined $error) {
		$clock++;
		# FETCH
		$AR = $PC;
		$memory[$AR] =~ /^\s*(.*?)\s*(;|$)/; # yank spaces and comments
		$memory[$AR] = $1;
		$IR = $1;
		$trace .= "CLOCK=[$clock]\tPC=[$PC]\n\t\t\tIR=[$IR]\n\t\t\tAR=[$AR]\n\t\t\tAC=[$ACC]\n\t\t\t B=[$B]\n" if ($tr_opt eq 'Fetch Trace');
		# EXECUTE
		if ($IR =~ /^ADD\s+(\d+)$/i) {
			if ($1 < 1) {
				$error = "Illigal address $1 (PC=$PC)";
				next;
			} 
			$AR = $1;
			$B = $memory[$AR];
			$ACC += $B;
		} elsif ($IR =~ /^SUB\s+(\d+)$/i) {
			if ($1 < 1) {
				$error = "Illigal address $1 (PC=$PC)";
				next;
			} 
			$AR = $1;
			$B = $memory[$AR];
			$ACC -= $B;
		} elsif ($IR =~ /^MLT\s+(\d+)$/i) {
			if ($1 < 1) {
				$error = "Illigal address $1 (PC=$PC)";
				next;
			} 
			$AR = $1;
			$B = $memory[$AR];
			$ACC *= $B;
		} elsif ($IR =~ /^DIV\s+(\d+)$/i) {
			if ($1 < 1) {
				$error = "Illigal address $1 (PC=$PC)";
				next;
			} 
			$AR = $1;
			$B = $memory[$AR];
			if ($B == 0) {
				$error = "Division by zero (PC=$PC)";
				next;
			} 
			$ACC /= $B;
		} elsif ($IR =~ /^SET\s+(-?\d+)$/i) {
			$ACC = $1;
		} elsif ($IR =~ /^SET\s+"([^"]*)"$/i) {
			$ACC = $1;
		} elsif ($IR =~ /^NEG$/i) {
			$ACC = -$ACC;
		} elsif ($IR =~ /^INC$/i) {
			$ACC++;
		} elsif ($IR =~ /^DEC$/i) {
			$ACC--;
		} elsif ($IR =~ /^LDA\s+(\d+)$/i) {
			$AR = $1;
			if ($AR == 0) { # input
				$ACC = shift @input; 
				unless (defined $ACC) {
					$error = "Missing input (PC=$PC)";
					next;
				} 
			} else {
				$ACC = $memory[$AR];
			}
		} elsif ($IR =~ /^STA\s+(\d+)$/i) {
			$AR = $1;
			if ($AR == 0) { # output
				$output .= $ACC; 
			} else {
				$memory[$AR] = $ACC;
			}
		} elsif ($IR =~ /^BR\s+(\d+)$/i) {
			$PC = $1;
		} elsif ($IR =~ /^BRP\s+(\d+)$/i) {
			$PC = $1 if ($ACC > 0);
		} elsif ($IR =~ /^BRZ\s+(\d+)$/i) {
			$PC = $1 if ($ACC == 0);
		} elsif ($IR =~ /^NOOP$/i) {
			;
		} elsif ($IR =~ /^HLT$/i) {
			$PC = '?';
			last;
		} else { # error
			$error = "Illegal instruction (PC=$PC, IR=$IR)";
			next;
		}
		$trace .= "CLOCK=[$clock]\tPC=[$PC]\n\t\t\tIR=[$IR]\n\t\t\tAR=[$AR]\n\t\t\tAC=[$ACC]\n\t\t\t B=[$B]\n" if ($tr_opt eq 'Execute Trace');
		# INCREMENT
		$PC++;
		$trace .= "CLOCK=[$clock]\tPC=[$PC]\n\t\t\tIR=[$IR]\n\t\t\tAR=[$AR]\n\t\t\tAC=[$ACC]\n\t\t\t B=[$B]\n" if ($tr_opt eq 'Increment Trace');
		# CHECK FOR ENDLESS LOOPS
		$error = "Exceeded maximum running time (endless loop?)" if ((times)[0] > $maxTime);
	}
	$output .= "\n\nTRACE:\n\n$trace" unless ($tr_opt eq 'No Register Trace');
	if ($show_mem eq 'on') {
		$output .= "\n\nMEMORY:\n\n";
		for (my $i = 1; $i <= $#memory; $i++) {
			$output .= "$i. $memory[$i]\n";
		}
	}
	$output .= "\n\nERROR: $error" if (defined $error);
	return $output;
}

# indicate where error occurred as a comment
sub mark_error ($$) {
	my ($line, $source) = @_;
	my @code = split(/\r?\n/, $source);
	$code[$line - 1] .= " ;; <-- problem here" unless ($code[$line - 1] =~ /<-- problem here$/);
	return join("\n", @code);
}

# add address numbers as comments
sub addcomments (\@) {
	my $n = 1;
	for (@{$_[0]}) {
		$_ .= "\t;; address $n"; # unless (/;;\s+address\s+\d+$/);
		$n++;
	}
}

# print counter based on file
sub mycounter {
         my $IDfile = 'counter.txt';
         sysopen(ID, $IDfile, O_RDWR|O_CREAT) || die "cannot open $IDfile: $!";
         flock(ID, 2) || die "cannot lock $IDfile: $!";
         my $id = <ID> || 1;
         chomp($id);
         seek(ID,0,0) || die "cannot rewind $IDfile: $!";
         truncate(ID,0) || die "cannot truncate $IDfile: $!";
         print(ID $id+1, "\n") || die "cannot write to $IDfile: $!";
         close(ID) || die "cannot close $IDfile: $!";
         return "Used $id times" . (defined($install)? " $install": '');
}

# MAIN
print header, start_html(-title=>'OAMulator', -BGCOLOR=>"#$bg_color"), "\n<center>\n", 
	h3(a({href=>"$homeURL"},'OAMulator'), 
		': OAMPL Compiler + OAM Assembler/Emulator');
if (!param() || param('Submit') eq 'Clear') { 
	# clean form
	cgiform('','','','');
} elsif (param('Submit') eq 'Example') { 
	# load example
	my $example = 'write "Hello, world!" ;; edit away!';
	cgiform("$example",'','','');
} elsif (param('Submit') eq 'Compile') { 
	# compile
	my ($error, $line, $oam) = compile(param('oampl'));
	cgiform((defined($error)? mark_error($line, param('oampl')): param('oampl')), 
		$oam, 
		(defined(param('input'))? param('input') : ''), 
		(defined($error)? "$error error at line $line": ''));
} elsif (param('Submit') eq 'Execute') { 
	# execute
	my $console = execute(param('oam'), param('input'), param('trace_option'), param('Show Memory'));
	cgiform((param('oampl') or ''), param('oam'), 
		(defined(param('input'))? param('input') : ''), $console);
} else { 
	# error
	die "Unrecognized request: $!\n";
}
# print br, "Please help out by participating in a very brief anonymous ", a({href=>'survey.cgi'}, 'survey'), hr;
print	mycounter(), br, 'Free software under ', 
	a({href=>'http://www.gnu.org/copyleft/gpl.html'}, 'GNU General Public License (GPL)'),
	br, '&copy; 2001-2003 ', 
	a({href=>'http://informatics.indiana.edu/fil/'}, 'Filippo Menczer');
print "\n</center>\n", end_html;

=head1 NAME

OAMulator - a Web based resource to support the teaching of instruction set
architecture, assembly languages, memory, addressing, high level
programming, and compilation.

=head1 DESCRIPTION

OAMulator is based on a simple, virtual CPU architecture called the One
Address Machine.  A compiler allows to take programs written in a special
programming language, called OAMPL, and transform them into OAM assembly.
An OAM assembler/emulator allows to interpret and execute OAM assembly code
(produced by the compiler or written directly).  The OAMulator is targeted
at students of introductory courses in information technology or information
systems; it is designed to take the mystery out of the CPU architecture and
let students gain confidence with the concepts of compilers and binary
execution.

To install OAMulator on your server:
1. make sure you have a Web (HTTP) server configured to allow CGI or mod_perl
2. save the CGI script (oamulator.cgi) in a CGI-enabled directory on your server
3. make sure the script is world-readable and world-executable
4. if you are familiar with Perl you may edit a couple of localized parameters
5. you may rename the script or make a symbolic link named, say, index.cgi
6. point a browser to the script URL -- have fun!

=head1 README

A Web based compiler/assembler/emulator for instructional support.
Complete documentation at C<http://informatics.indiana.edu/fil/OAM/>.

=head1 PREREQUISITES

This script requires the C<strict> module.  It also requires
C<CGI>, C<CGI::Carp>, and C<Fcntl>.

=pod OSNAMES

any

=pod SCRIPT CATEGORIES

Educational/ComputerScience
CGI
Web

=cut
