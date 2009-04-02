#!/usr/bin/perl

use strict;

die "Usage: $0 [RPM...] [RPMDIR...]\n" unless @ARGV;

my @rpms;
for (@ARGV) {
	if (-d) {
		my @gl = glob("$_/*.rpm");
		die "$_: no rpms" unless @gl;
		push @rpms, @gl;
	}
	else {
		push @rpms, $_;
	}
}

sub collect ($$$) {
	my ($rpm, $def, $ref) = @_;
	use qa::rpmelfsym 'rpmelfsym';
	my $out = rpmelfsym $rpm;
	use File::Basename 'basename';
	my $rpm_bn = basename $rpm;
	for my $file2syms (@$out) {
		my $U_prefix = "$rpm_bn\t$$file2syms[0]\tU\t";
		for my $sym (@{$$file2syms[1]}) {
			if ($$sym[0] eq "U") {
				print $ref $U_prefix, $$sym[1], "\n"
					or die "sort failed";
			}
			elsif ($$sym[0] =~ /^[A-TV-Z]/) {
				print $def $$sym[1], "\n"
					or die "sort failed";
			}
		}
	}
}

use File::Temp 'tempdir';
use sigtrap qw(die normal-signals);
my $TMPDIR = $ENV{TMPDIR} = tempdir(CLEANUP => 1);

sub collect_rpms ($;$) {
	my ($rpms, $suffix) = @_;
	open my $def, "|-", "sort", "-o", "$TMPDIR/def$suffix", "-u"
		or die "sort failed";
	open my $ref, "|-", "sort", "-o", "$TMPDIR/ref$suffix", "-t\t", "-k4,4"
		or die "sort failed";
	collect($_, $def, $ref) for @$rpms;
	close $def or die "sort failed";
	close $ref or die "sort failed";
}

collect_rpms \@rpms;

0 == system "join", "-t\t", qw(-v1 -14 -21 -o), '1.1 1.2 1.3 1.4',
	"$TMPDIR/ref", "$TMPDIR/def"
		or die "join failed";
