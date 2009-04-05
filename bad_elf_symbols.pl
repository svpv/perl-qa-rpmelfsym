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

sub collect ($$$) {
	my ($rpm, $def, $ref) = @_;
	use qa::rpmelfsym 'rpmelfsym';
	my $out = rpmelfsym $rpm;
	use qa::memoize 0.02 'basename';
	my $rpm_bn = basename $rpm;
	for my $file2syms (@$out) {
		my ($defs, $refs);
		my $fname = shift @$file2syms;
		my $U_prefix = "$rpm_bn\t$fname\tU\t";
		for my $sym (@$file2syms) {
			if ($sym =~ s/^U//) {
				$refs .= $U_prefix . $sym . "\n";
			}
			elsif ($sym =~ s/^[A-TV-Z]//) {
				$defs .= $sym . "\n";
			}
		}
		if (defined $defs) {
			print $def $defs or die "def: $!";
		}
		if (defined $refs) {
			print $ref $refs or die "ref: $!";
		}
	}
}

use File::Temp 'tempdir';
use sigtrap qw(die normal-signals);
my $TMPDIR = $ENV{TMPDIR} = tempdir(CLEANUP => 1);

sub collect_rpms ($;$) {
	my ($rpms, $suffix) = @_;
	open my $def, ">", "$TMPDIR/def$suffix" or die "def: $!";
	open my $ref, ">", "$TMPDIR/ref$suffix" or die "ref: $!";
	collect($_, $def, $ref) for @$rpms;
	close $def or die "def: $!";
	close $ref or die "ref: $!";
}

collect_rpms \@rpms;

0 == system <<'EOF' or die "/bin/sh failed";
set -efu
cd "$TMPDIR"
sort -u -o def def
sort -t$'\t' -k4,4 -o ref ref
join -t$'\t' -v1 -14 -21 -o '1.1 1.2 1.3 1.4' ref def >tmp
sort -u tmp
EOF
