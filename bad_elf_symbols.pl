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

use File::Temp 'tempdir';
use sigtrap qw(die normal-signals);
my $TMPDIR = $ENV{TMPDIR} = tempdir(CLEANUP => 1);

my $SEQNO = "AAAA";
open my $SEQ, ">", "$TMPDIR/seq"
	or die "seq: $!";

sub collect ($$$) {
	my ($rpm, $def, $ref) = @_;
	use qa::rpmelfsym 'rpmelfsym';
	my $out = rpmelfsym $rpm;
	use qa::memoize 0.02 'basename';
	my $rpm_bn = basename $rpm;
	for my $file2syms (@$out) {
		my $fname = shift @$file2syms;
		print $SEQ $SEQNO, "\t", $rpm_bn, "\t", $fname, "\tU\n";
		for my $sym (@$file2syms) {
			my $t = substr $sym, 0, 1, "";
			if ($t eq "U") {
				print $ref $SEQNO, "\t", $sym, "\n"
					or die "ref: $!";
			}
			elsif ($t eq ucfirst($t)) {
				print $def $sym, "\n"
					or die "def: $!";
			}
		}
		$SEQNO++;
	}
}

sub collect_rpms ($;$) {
	my ($rpms, $suffix) = @_;
	open my $def, ">", "$TMPDIR/def$suffix" or die "def: $!";
	open my $ref, ">", "$TMPDIR/ref$suffix" or die "ref: $!";
	collect($_, $def, $ref) for @$rpms;
	close $def or die "def: $!";
	close $ref or die "ref: $!";
}

collect_rpms \@rpms;
exit 0 if $SEQNO eq "AAAA";

0 == system <<'EOF' or die "/bin/sh failed";
set -efu
cd "$TMPDIR"

sort -u -o def def
sort -t$'\t' -k2,2 -o ref ref
join -t$'\t' -v1 -12 -21 -o '1.1 1.2' ref def >tmp
mv -f tmp ref

rm -f def

sort -t$'\t' -k1,1 -o ref ref
join -t$'\t' -o '1.2 1.3 1.4 2.2' seq ref >tmp
sort -u tmp
EOF
