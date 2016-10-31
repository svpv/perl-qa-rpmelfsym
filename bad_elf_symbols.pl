#!/usr/bin/perl

use strict;

use Getopt::Long 2.24 qw(GetOptions :config gnu_getopt);
GetOptions "include=s" => \(my $include = "*.rpm") and @ARGV
	or die "Usage: $0 [--include=GLOB] [RPM...] [RPMDIR...]\n";

my @rpms;
for (@ARGV) {
	if (-d) {
		use File::Glob 'bsd_glob';
		my @gl = bsd_glob("$_/$include", 0) or die "$_: no rpms";
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
set -efu ${BASH_VERSION:+-o pipefail}
cd "$TMPDIR"

mkfifo pipe
snzip -d <ref.sz >pipe &
snzip -d <def.sz |
join -t"$tab" -v1 -12 -21 -o '1.1 1.2' pipe - >ref
wait $!

sort -t"$tab" -k1,1 -o ref ref
join -t"$tab" -o '1.2 1.3 1.4 2.2' seq ref |sort -u
EOF
