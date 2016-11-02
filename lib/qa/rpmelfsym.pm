package qa::rpmelfsym;

use strict;
our $VERSION = '0.11';

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

{
	my $magic;
	use File::LibMagic 0.90 qw(magic_open magic_load magic_buffer magic_file);
	sub file ($) {
		unless ($magic) {
			$magic = magic_open(0) or die "magic_open failed";
			magic_load($magic, undef);
		}
		my $f = shift;
		magic_file($magic, $f);
	}
}

sub rpmelfsym ($) {
	my $rpm = shift;
	require RPM::Payload;
	my $cpio = RPM::Payload->new($rpm);
	$rpm =~ s#.*/##;
	my ($skipcnt, $skipfname);
	my $out = "";
	while (my $ent = $cpio->next) {
		use Fcntl 'S_ISREG';
		next unless S_ISREG($ent->mode);
		next unless $ent->size > 4;

		my $filename = $ent->filename;
		$filename =~ s#^\./|^/|^#/#;

		next if $filename =~ m#^/usr/lib/debug/.+\.debug\z#;

		$ent->read(my $magic, 4) == 4
			or die "$rpm: $filename: cpio read failed";
		next unless $magic eq "\177ELF";

		require File::Temp;
		my $tmp = File::Temp->new;

		local ($\, $,);
		print $tmp $magic
			or die "$rpm: $filename: tmp write failed: $!";
		while ($ent->read(my $buf, 8192) > 0) {
			print $tmp $buf
			or die "$rpm: $filename: tmp write failed: $!";
		}
		$tmp->flush
			or die "$rpm: $filename: tmp write failed: $!";

		my $type = file("$tmp");
		next unless $type =~ /\bELF .+ dynamically linked/;

		if ($filename =~ m#^/usr/share/#) {
			$skipcnt++ and $skipfname = $filename or
			warn "$rpm: $filename: skipping ELF binary\n";
			next;
		}

		my @file2syms = $filename;
		open my $fh, "-|", qw(nm -D), "$tmp"
			or die "$rpm: $filename: nm failed";
		local $_;
		while (<$fh>) {
			if (/^([[:xdigit:]]{8}([[:xdigit:]]{8})? | {9}( {8})?)([[:alpha:]]) ([^\t\n]+)$/) {
				push @file2syms, $4 . $5;
			} else {
				die "$rpm: $filename: invalid nm output: $_";
			}
		}
		close $fh
			or die "$rpm: $filename: nm failed";
		$out .= join "\0", @file2syms, "" if @file2syms > 1;
	}
	$skipcnt == 2 and warn "$rpm: $skipfname: skipping ELF binary\n" or
	$skipcnt >= 3 and warn "$rpm: skipped @{[$skipcnt-1]} more binaries under /usr/share\n";

	chop $out;
	return $out;
}

use qa::memoize 0.02 qw(memoize_bsm);
memoize_bsm("rpmelfsym");

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(rpmelfsym collect_bad_elfsym print_elfsym);

# We use seqno as a join key for (rpm-basename,elf-filename) tuples, which
# we store separately.  Four-letter words impose 456K limit on ELF files
# from within rpm packages which can be processed simultaneously.  However,
# our typical repo is 10K packages and 30K ELF files total (per arch).

sub last_seqno ($) {
	my $fname = shift;
	open my $fh, "<", $fname
		or return "AAAA";
	stat $fh and my $size = -s _
		or return "AAAA";
	use constant PIPE_BUF => 4096;
	seek $fh, - PIPE_BUF, 2 if $size > PIPE_BUF;
	read $fh, my $buf, PIPE_BUF;
	my @lines = split /\n/, $buf;
	my $line = $lines[-1];
	$line =~ /^([A-Z]{4})\t/
		or die "$fname: invalid last line: $line";
	return $1;
}

sub collect_bad_elfsym2 ($$$$$) {
	my ($ref, $def, $seq, $seqno, $rpms) = @_;
	my $cnt = 0;
	for my $rpm (@$rpms) {
		next unless $cnt++ % 2 == 0;
		my $argz = rpmelfsym $rpm;
		next if $argz eq "";
		use qa::memoize 0.02 'basename';
		$rpm = basename $rpm;
		collect_bad_elfsym1($rpm, $argz, $ref, $def, $seq, $seqno);
	}
}

# A few notes about sorting.
# 1) sort(1) is the bottleneck; as workers retrieve cached data,
# they stall while piping to sort(1);
# 2) by default, sort(1) tends to eat up all system resources,
# and must be limited nonetheless; it might be fast, but soon
# you discover that you need to re-read some files from disk;
# 3) by default, when sorting from a pipe, sort(1) sorts in
# "non-parallel" mode (can't get >= 100% CPU usage); to put it
# into parallel mode, --buffer-size=BIG-ENOUGH option, poorly
# documented with respect to this purpose, needs to be used;
# 4) symbol lists can be compressed by a factor of 4-5; also,
# symbols lists are typically huge; e.g. unsorted def is 622M;
# to avoid extra memory pressure, we do not expose raw symbols
# to virtual memory; to this end, we use snzip(1) real-time
# compressor; e.g. `sort -u def' is 369M, while def.sz is 80M;
# 5) for our purposes, snzip(1) performs better than lz4(1);
# 6) `sort -k2' is faster than `sort -k2,2'.
our @SORT = qw(sort --parallel=2 --buffer-size=128M --compress-program=snzip);

sub open_sort_and_snzip {
	my ($out, @how) = @_;
	pipe my ($zR, $zW) or die "pipe: $!";
	use 5.010;
	my $zpid = fork // die "fork: $!";
	if ($zpid == 0) {
		open STDIN, "<&", $zR or die "snzip stdin: $!";
		open STDOUT, ">", "$out.sz" or die "snzip stdout: $!";
		close $zR;
		close $zW;
		exec "snzip";
		die "cannot exec snzip";
	}
	close $zR;
	pipe my ($sR, $sW) or die "pipe: $!";
	my $spid = fork // die "fork: $!";
	if ($spid == 0) {
		open STDIN, "<&", $sR or die "sort stdin: $!";
		open STDOUT, ">&", $zW or die "sort stdout: $!";
		close $sR;
		close $sW;
		close $zW;
		exec @SORT, @how;
		die "cannot exec sort";
	}
	return $sW, $spid, $zpid;
}

sub collect_bad_elfsym ($$$) {
	my ($dir, $suffix, $rpms) = @_;
	my $seqno = last_seqno "$dir/seq";
	open my $seq, ">>", "$dir/seq" or die "seq: $!";
	my ($ref, $refspid, $refzpid) = open_sort_and_snzip "$dir/ref$suffix", "-t\t", "-k2";
	my ($def, $defspid, $defzpid) = open_sort_and_snzip "$dir/def$suffix", "-u";
	my $pid1 = fork // die "fork: $!";
	if ($pid1 == 0) {
		collect_bad_elfsym2($ref, $def, $seq, $seqno, $rpms);
		exit 0;
	}
	my $pid2 = fork // die "fork: $!";
	if ($pid2 == 0) {
		# process "odd" rpms
		shift @$rpms;
		# use alternate seqno
		$seqno++;
		collect_bad_elfsym2($ref, $def, $seq, $seqno, $rpms);
		exit 0;
	}
	close $ref;
	close $def;
	$pid1 == waitpid $pid1, 0 and $? == 0 or die "pid1 failed";
	$pid2 == waitpid $pid2, 0 and $? == 0 or die "pid2 failed";
	$refspid == waitpid $refspid, 0 and $? == 0 or die "refspid failed";
	$defspid == waitpid $defspid, 0 and $? == 0 or die "defspid failed";
	$refzpid == waitpid $refzpid, 0 and $? == 0 or die "refzpid failed";
	$defzpid == waitpid $defzpid, 0 and $? == 0 or die "defzpid failed";
	0 == system "sort", "-o", "$dir/seq", "$dir/seq"
		or die "sort seq failed";
}

1;
