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
		my $fname = shift @$file2syms;
		my $prefix = "$rpm_bn\t$fname\t";
		for my $sym (@$file2syms) {
			my ($t, $n) = split //, $sym, 2;
			print $prefix, $t, "\t", $n, "\n";
		}
	}
}

print_rpmelfsym($_) for @rpms;
