#!/usr/bin/perl

use strict;

use Getopt::Long 2.24 qw(GetOptions :config gnu_getopt);
GetOptions "include=s" => \(my $include = "*.rpm")
	and @ARGV == 2 and do { open my $fh, ">&3" }
	or die "Usage: $0 [--include=GLOB] RPMDIR1 RPMDIR2 >plus 3>minus\n";

my ($dir1, $dir2) = @ARGV;

my @rpms0;
my @rpms1;
my @rpms2;
{
	use File::Glob 'bsd_glob';
	@rpms1 = bsd_glob("$dir1/$include", 0) or die "$dir1: no rpms";
	@rpms2 = bsd_glob("$dir2/$include", 0) or die "$dir2: no rpms";

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
my $TMPDIR = $ENV{TMPDIR} = tempdir qw(rpmelfsym.XXXXXXXX TMPDIR 1 CLEANUP 1);

use qa::rpmelfsym 'collect_bad_elfsym';
collect_bad_elfsym $TMPDIR, "1", \@rpms1;
collect_bad_elfsym $TMPDIR, "2", \@rpms2;
unless (-s "$TMPDIR/seq") {
	warn basename($0), ": no ELF binaries\n";
	exit 0;
}

collect_bad_elfsym $TMPDIR, "0", \@rpms0;

# We use /bin/sh with bash syntax.
# You may want to change this to
#    system qw(bash -c) => <<'EOF'
0 == system <<'EOF' or die "/bin/sh failed";
set -efu -o pipefail +o posix
cd "$TMPDIR"

make_xref()
{
join -t$'\t' -v1 -12 -21 -o '1.1 1.2' \
	<(sort -m -k2 <(snzip -d <ref0.sz) <(snzip -d <ref$1.sz) ) \
	<(sort -m -u  <(snzip -d <def0.sz) <(snzip -d <def$1.sz) ) |sort |
		join -t$'\t' -o '1.2 1.3 1.4 2.2' seq - |sort -u >xref$1
}

make_xref 1 &
make_xref 2
wait $!

comm -13 xref1 xref2
comm -23 xref1 xref2 >&3
EOF
