#!/usr/bin/perl

use strict;

sub print_rpmelfsym ($) {
	my $rpm = shift;
	use qa::rpmelfsym;
	my $out = qa::rpmelfsym::rpmelfsym $rpm;
	use File::Basename 'basename';
	my $rpm_bn = basename $rpm;
	for my $file2syms (@$out) {
		my ($filename, $syms) = @$file2syms;
		for my $sym (@$syms) {
			my ($symtype, $symname) = @$sym;
			printf "%s\t%s\t%s\t%s\n", $rpm_bn, $filename, $symtype, $symname;
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
