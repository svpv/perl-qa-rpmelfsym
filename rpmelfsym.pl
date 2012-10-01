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
	use qa::rpmelfsym 'print_elfsym';
	print_elfsym $rpm_bn, $argz, *STDOUT;
}

print_rpmelfsym($_) for @rpms;
