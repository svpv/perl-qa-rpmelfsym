#!/usr/bin/perl

use strict;

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

open my $def, "|-", "sort", "-o", "$TMPDIR/def", "-u"
	or die "sort failed";
open my $ref, "|-", "sort", "-o", "$TMPDIR/ref", "-t\t", "-k4,4"
	or die "sort failed";

for my $arg (@ARGV) {
	my @rpms;
	if (-d $arg) {
		@rpms = glob("$arg/*.rpm") or die "$arg: no rpms";
	}
	else {
		@rpms = $arg;
	}
	for my $rpm (@rpms) {
		collect $rpm, $def, $ref;
	}
}

close $def or die "sort failed";
close $ref or die "sort failed";

0 == system "join", "-t\t", qw(-v1 -14 -21 -o), '1.1 1.2 1.3 1.4',
	"$TMPDIR/ref", "$TMPDIR/def"
		or die "join failed";
