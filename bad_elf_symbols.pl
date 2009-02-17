#!/usr/bin/perl

use strict;

require File::Temp;
our $DEF = File::Temp->new;
our $REF = File::Temp->new;

sub collect {
	my $rpm = shift;
	use qa::rpmelfsym 'rpmelfsym';
	my $out = rpmelfsym $rpm;
	use File::Basename 'basename';
	my $rpm_bn = basename $rpm;
	my @def =
		map  { $$_[1] }
		grep { $$_[0] =~ /^[A-TV-Z]/ }
		map  { @{$$_[1]} } @$out;
	my @ref =
		grep { @{$$_[1]} }
		map  { [ $$_[0], [
				map { $$_[1] }
				grep { $$_[0] eq "U" }
				@{$$_[1]} ]
		] } @$out;
	for (@def) {
		print $DEF $_, "\n";
	}
	for (@ref) {
		my $prefix = "$rpm_bn\t$$_[0]";
		for my $sym (@{$$_[1]}) {
			print $REF $prefix, "\tU\t", $sym, "\n";
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
		collect $rpm;
	}
}

@ENV{qw(DEF REF)}=($DEF,$REF);
system(<<'EOF') == 0 or die "/bin/sh failed";
set -efu
sort -u -o "$DEF" "$DEF"
sort -t$'\t' -k4,4 -o "$REF" "$REF"
join -t$'\t' -v1 -14 -21 -o '1.1 1.2 1.3 1.4' "$REF" "$DEF"
EOF
