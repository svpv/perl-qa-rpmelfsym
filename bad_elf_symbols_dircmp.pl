#!/usr/bin/perl

use strict;

@ARGV == 2 and do { open my $fh, ">&=3" }
	or die "Usage: $0 DIR1 DIR2 >plus 3>minus\n";

my ($dir1, $dir2) = @ARGV;

my @rpms0;
my @rpms1;
my @rpms2;
{
	@rpms1 = glob("$dir1/*.rpm") or die "$dir1: no rpms";
	@rpms2 = glob("$dir2/*.rpm") or die "$dir2: no rpms";

	use File::Basename 'basename';
	my %rpms1 = map { basename($_) => [ $_, -s $_, -M _ ] } @rpms1;
	my %rpms2 = map { basename($_) => [ $_, -s $_, -M _ ] } @rpms2;

	while (my ($basename, $path_size_mtime1) = each %rpms1) {
		my $path_size_mtime2 = $rpms2{$basename};
		next unless $path_size_mtime2;
		next unless
			"@$path_size_mtime1[1,2]" eq
			"@$path_size_mtime2[1,2]";
		push @rpms0, $$path_size_mtime1[0];
		delete $rpms1{$basename};
		delete $rpms2{$basename};
	}

	@rpms0 = sort @rpms0;
	@rpms1 = sort map { $$_[0] } values %rpms1;
	@rpms2 = sort map { $$_[0] } values %rpms2;
}

sub collect {
	my ($rpm, $def, $ref) = @_;
	use qa::rpmelfsym 'rpmelfsym';
	my $out = rpmelfsym $rpm;
	use File::Basename 'basename';
	my $rpm_bn = basename $rpm;
	for my $file2syms (@$out) {
		my $U_prefix = "$rpm_bn\t$$file2syms[0]\tU\t";
		for my $sym (@{$$file2syms[1]}) {
			if ($$sym[0] eq "U") {
				print $ref $U_prefix, $$sym[1], "\n";
			}
			elsif ($$sym[0] =~ /^[A-TV-Z]/) {
				print $def $$sym[1], "\n";
			}
		}
	}
}

require File::Temp;
use sigtrap qw(die normal-signals);

my $def1 = File::Temp->new;
my $ref1 = File::Temp->new;
collect($_, $def1, $ref1) for @rpms1;

my $def2 = File::Temp->new;
my $ref2 = File::Temp->new;
collect($_, $def2, $ref2) for @rpms2;

($def1->sync, -s $def1) or
($ref1->sync, -s $ref1) or
($def2->sync, -s $def2) or
($ref2->sync, -s $ref2) or
exit 0;

my $def0 = File::Temp->new;
my $ref0 = File::Temp->new;
collect($_, $def0, $ref0) for @rpms0;

my $tmp = File::Temp->new;

@ENV{qw( tmp  def0  def1  def2  ref0  ref1  ref2)} =
       ($tmp,$def0,$def1,$def2,$ref0,$ref1,$ref2);

system(<<'EOF') == 0 or die "/bin/sh failed";
set -efu
sort -u -o "$def0" "$def0"
sort -t$'\t' -k4,4 -o "$ref0" "$ref0"
join -t$'\t' -v1 -14 -21 -o '1.1 1.2 1.3 1.4' "$ref0" "$def0" >"$tmp"
cat "$tmp" >"$ref0"
: >"$tmp"
sort -u -o "$def1" "$def1"
sort -u -o "$def2" "$def2"
sort -m -u -o "$def1" "$def1" "$def0"
sort -m -u -o "$def2" "$def2" "$def0"
: >"$def0"
sort -t$'\t' -k4,4 -o "$ref1" "$ref1"
sort -t$'\t' -k4,4 -o "$ref2" "$ref2"
sort -m -t$'\t' -k4,4 -o "$ref1" "$ref1" "$ref0"
sort -m -t$'\t' -k4,4 -o "$ref2" "$ref2" "$ref0"
: >"$ref0"
join -t$'\t' -v1 -14 -21 -o '1.1 1.2 1.3 1.4' "$ref1" "$def1" >"$tmp"
sort -u -o "$ref1" "$tmp"
: >"$def1"
join -t$'\t' -v1 -14 -21 -o '1.1 1.2 1.3 1.4' "$ref2" "$def2" >"$tmp"
sort -u -o "$ref2" "$tmp"
: >"$def2"
comm -13 "$ref1" "$ref2"
comm -23 "$ref1" "$ref2" >&3
EOF
