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

use qa::rpmelfsym 'collect_bad_elfsym';
collect_bad_elfsym $TMPDIR, "", \@rpms;
exit 0 unless -s "$TMPDIR/seq";

$ENV{tab} = "\t";
0 == system <<'EOF' or die "/bin/sh failed";
set -efu
cd "$TMPDIR"

sort -u -o def def
sort -t"$tab" -k2,2 -o ref ref
join -t"$tab" -v1 -12 -21 -o '1.1 1.2' ref def >tmp
mv -f tmp ref

rm -f def

sort -t"$tab" -k1,1 -o ref ref
join -t"$tab" -o '1.2 1.3 1.4 2.2' seq ref >tmp
sort -u tmp
EOF
