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
	for my $file2syms (@$out) {
		my $U_prefix = "$rpm_bn\t$$file2syms[0]\tU\t";
		for my $sym (@{$$file2syms[1]}) {
			if ($$sym[0] eq "U") {
				print $REF $U_prefix, $$sym[1], "\n";
			}
			elsif ($$sym[0] =~ /^[A-TV-Z]/) {
				print $DEF $$sym[1], "\n";
			}
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
