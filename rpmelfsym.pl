#!/usr/bin/perl

use strict;

die "Usage: $0 [RPM...] [RPMDIR...]\n" unless @ARGV;

my @rpms;
for (@ARGV) {
	if (-d) {
		use File::Glob 'bsd_glob';
		my @gl = bsd_glob("$_/*.rpm", 0) or die "$_: no rpms";
		push @rpms, @gl;
	}
	else {
		push @rpms, $_;
	}
}

sub print_rpmelfsym ($) {
	my $rpm = shift;
	use qa::rpmelfsym 'rpmelfsym';
	my $argz = rpmelfsym $rpm;
	return if $argz eq "";
	use qa::memoize 0.02 'basename';
	my $rpm_bn = basename $rpm;
	my $prefix;
	for my $sym (split "\0", $argz) {
		my $t = substr $sym, 0, 1, "";
		if ($t eq "/") {
			$prefix = "$rpm_bn\t/$sym\t";
		}
		else {
			print $prefix, $t, "\t", $sym, "\n";
		}
	}
}

print_rpmelfsym($_) for @rpms;
