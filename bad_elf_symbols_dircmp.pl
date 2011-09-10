#!/usr/bin/perl

use strict;

@ARGV == 2 and do { open my $fh, ">&3" }
	or die "Usage: $0 RPMDIR1 RPMDIR2 >plus 3>minus\n";

my ($dir1, $dir2) = @ARGV;

my @rpms0;
my @rpms1;
my @rpms2;
{
	use File::Glob 'bsd_glob';
	@rpms1 = bsd_glob("$dir1/*.rpm", 0) or die "$dir1: no rpms";
	@rpms2 = bsd_glob("$dir2/*.rpm", 0) or die "$dir2: no rpms";

	use qa::memoize 0.02 'basename';
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

use File::Temp 'tempdir';
use sigtrap qw(die normal-signals);
my $TMPDIR = $ENV{TMPDIR} = tempdir(CLEANUP => 1);

use qa::rpmelfsym 'collect_bad_elfsym';
collect_bad_elfsym $TMPDIR, "1", \@rpms1;
collect_bad_elfsym $TMPDIR, "2", \@rpms2;
exit 0 unless -s "$TMPDIR/seq";

collect_bad_elfsym $TMPDIR, "0", \@rpms0;

$ENV{tab} = "\t";
0 == system <<'EOF' or die "/bin/sh failed";
set -efu
cd "$TMPDIR"

sort -u -o def1 def1
sort -t"$tab" -k2,2 -o ref1 ref1
join -t"$tab" -v1 -12 -21 -o '1.1 1.2' ref1 def1 >tmp
mv -f tmp ref1

sort -u -o def2 def2
sort -t"$tab" -k2,2 -o ref2 ref2
join -t"$tab" -v1 -12 -21 -o '1.1 1.2' ref2 def2 >tmp
mv -f tmp ref2

sort -u -o def0 def0
sort -t"$tab" -k2,2 -o ref0 ref0

join -t"$tab" -v1 -12 -21 -o '1.1 1.2' ref0 def0 >tmp &
join -t"$tab" -v1 -12 -21 -o '1.1 1.2' ref1 def0 >ref1a
join -t"$tab" -v1 -12 -21 -o '1.1 1.2' ref2 def0 >ref2a
wait $!
mv -f tmp ref0
rm -f def0

join -t"$tab" -v1 -12 -21 -o '1.1 1.2' ref0 def1 >ref1b
join -t"$tab" -v1 -12 -21 -o '1.1 1.2' ref0 def2 >ref2b
sort -u -o ref1 ref1a ref1b
sort -u -o ref2 ref2a ref2b

join -t"$tab" -o '1.2 1.3 1.4 2.2' seq ref1 >tmp
sort -u -o xref1 tmp

join -t"$tab" -o '1.2 1.3 1.4 2.2' seq ref2 >tmp
sort -u -o xref2 tmp

comm -13 xref1 xref2
comm -23 xref1 xref2 >&3
EOF
