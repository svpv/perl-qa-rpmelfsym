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

sub print_rpmelfsym ($) {
	my $rpm = shift;
	use qa::rpmelfsym 'rpmelfsym';
	my $out = rpmelfsym $rpm;
	use qa::memoize 0.02 'basename';
	my $rpm_bn = basename $rpm;
	for my $file2syms (@$out) {
		my $prefix = "$rpm_bn\t$$file2syms[0]";
		for my $sym (@{$$file2syms[1]}) {
			print $prefix, "\t", $$sym[0], "\t", $$sym[1], "\n";
		}
	}
}

print_rpmelfsym($_) for @rpms;
