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

collect_rpms \@rpms1, "1";
collect_rpms \@rpms2, "2";
exit 0 if $SEQNO eq "AAAA";

collect_rpms \@rpms0, "0";

0 == system <<'EOF' or die "/bin/sh failed";
set -efu
cd "$TMPDIR"

sort -u -o def0 def0
sort -t$'\t' -k2,2 -o ref0 ref0
join -t$'\t' -v1 -12 -21 -o '1.1 1.2' ref0 def0 >tmp
mv -f tmp ref0

sort -u -o def1 def1
sort -t$'\t' -k2,2 -o ref1 ref1
join -t$'\t' -v1 -12 -21 -o '1.1 1.2' ref1 def1 >tmp
mv -f tmp ref1

sort -u -o def2 def2
sort -t$'\t' -k2,2 -o ref2 ref2
join -t$'\t' -v1 -12 -21 -o '1.1 1.2' ref2 def2 >tmp
mv -f tmp ref2

join -t$'\t' -v1 -12 -21 -o '1.1 1.2' ref0 def1 >tmpA
join -t$'\t' -v1 -12 -21 -o '1.1 1.2' ref1 def0 >tmpB
sort -u -o ref1 tmpA tmpB

join -t$'\t' -v1 -12 -21 -o '1.1 1.2' ref0 def2 >tmpA
join -t$'\t' -v1 -12 -21 -o '1.1 1.2' ref2 def0 >tmpB
sort -u -o ref2 tmpA tmpB

rm -f ref0 def0 def1 def2

join -t$'\t' -o '1.2 1.3 1.4 2.2' seq ref1 >tmp
sort -u -o xref1 tmp

join -t$'\t' -o '1.2 1.3 1.4 2.2' seq ref2 >tmp
sort -u -o xref2 tmp

comm -13 xref1 xref2
comm -23 xref1 xref2 >&3
EOF
