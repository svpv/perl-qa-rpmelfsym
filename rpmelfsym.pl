#!/usr/bin/perl

use strict;

sub print_rpmelfsym ($) {
	my $rpm = shift;
	use qa::rpmelfsym 'rpmelfsym';
	my $out = rpmelfsym $rpm;
	use File::Basename 'basename';
	my $rpm_bn = basename $rpm;
	for my $file2syms (@$out) {
		my $prefix = "$rpm_bn\t$$file2syms[0]";
		for my $sym (@{$$file2syms[1]}) {
			print $prefix, "\t", $$sym[0], "\t", $$sym[1], "\n";
		}
	}
}

for my $arg (@ARGV) {
	my @rpms;
	if (-d $arg) {
		@rpms = glob("$arg/*.rpm") or die "$arg: no rpms";
	}
	else {
		@rpms = $arg;
	}
	for my $rpm (@rpms) {
		print_rpmelfsym $rpm;
	}
}
