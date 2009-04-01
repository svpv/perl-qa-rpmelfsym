#!/usr/bin/perl

use strict;

@ARGV == 2 and do { open my $fh, ">&3" }
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

sub collect ($$$) {
	my ($rpm, $def, $ref) = @_;
	use qa::rpmelfsym 'rpmelfsym';
	my $out = rpmelfsym $rpm;
	use File::Basename 'basename';
	my $rpm_bn = basename $rpm;
	for my $file2syms (@$out) {
		my $U_prefix = "$rpm_bn\t$$file2syms[0]\tU\t";
		for my $sym (@{$$file2syms[1]}) {
			if ($$sym[0] eq "U") {
				print $ref $U_prefix, $$sym[1], "\n"
					or die "sort failed";
			}
			elsif ($$sym[0] =~ /^[A-TV-Z]/) {
				print $def $$sym[1], "\n"
					or die "sort failed";
			}
		}
	}
}

use File::Temp 'tempdir';
use sigtrap qw(die normal-signals);
my $TMPDIR = $ENV{TMPDIR} = tempdir(CLEANUP => 1);

open my $def1, "|-", "sort", "-o", "$TMPDIR/def1", "-u"
	or die "sort failed";
open my $ref1, "|-", "sort", "-o", "$TMPDIR/ref1", "-t\t", "-k4,4"
	or die "sort failed";
collect($_, $def1, $ref1) for @rpms1;
close $def1 or die "sort failed";
close $ref1 or die "sort failed";

open my $def2, "|-", "sort", "-o", "$TMPDIR/def2", "-u"
	or die "sort failed";
open my $ref2, "|-", "sort", "-o", "$TMPDIR/ref2", "-t\t", "-k4,4"
	or die "sort failed";
collect($_, $def2, $ref2) for @rpms2;
close $def2 or die "sort failed";
close $ref2 or die "sort failed";

-s "$TMPDIR/def1" or
-s "$TMPDIR/ref1" or
-s "$TMPDIR/def2" or
-s "$TMPDIR/ref2" or
exit 0;

open my $def0, "|-", "sort", "-o", "$TMPDIR/def0", "-u"
	or die "sort failed";
open my $ref0, "|-", "sort", "-o", "$TMPDIR/ref0", "-t\t", "-k4,4"
	or die "sort failed";
collect($_, $def0, $ref0) for @rpms0;
close $def0 or die "sort failed";
close $ref0 or die "sort failed";

0 == system <<'EOF' or die "/bin/sh failed";
set -efu
cd "$TMPDIR"
join -t$'\t' -v1 -14 -21 -o '1.1 1.2 1.3 1.4' ref0 def0 >tmp
mv -f tmp ref0
sort -m -u -o def1 def1 def0
sort -m -u -o def2 def2 def0
rm -f def0
sort -m -t$'\t' -k4,4 -o ref1 ref1 ref0
sort -m -t$'\t' -k4,4 -o ref2 ref2 ref0
rm -f ref0
join -t$'\t' -v1 -14 -21 -o '1.1 1.2 1.3 1.4' ref1 def1 >tmp
sort -u -o ref1 tmp
rm -f def1 tmp
join -t$'\t' -v1 -14 -21 -o '1.1 1.2 1.3 1.4' ref2 def2 >tmp
sort -u -o ref2 tmp
rm -f def2 tmp
comm -13 ref1 ref2
comm -23 ref1 ref2 >&3
EOF
