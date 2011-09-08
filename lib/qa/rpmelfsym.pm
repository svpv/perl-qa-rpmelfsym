package qa::rpmelfsym;

use strict;
our $VERSION = '0.09';

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

		my @file2syms = $filename;
		open my $fh, "-|", qw(nm -D -P), "$tmp"
			or die "$rpm: $filename: nm failed";
		local $_;
		while (<$fh>) {
			my @sym = split;
			@sym >= 2 and 1 == length $sym[1]
				or die "$rpm: $filename: invalid nm output: @sym";
			push @file2syms, $sym[1] . $sym[0];
		}
		close $fh
			or die "$rpm: $filename: nm failed";
		$out .= join "\0", @file2syms, "" if @file2syms > 1;
	}
	return $out;
}

use qa::memoize 0.02 qw(memoize_bsm);
memoize_bsm("rpmelfsym");

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(rpmelfsym collect_bad_elfsym);

# We use seqno as a join key for (rpm-basename,elf-filename) tuples, which
# we store separately.  Four-letter numbers impose 456K limit on ELF files
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

sub collect_bad_elfsym ($$$) {
	my ($dir, $suffix, $rpms) = @_;
	my $seqno = last_seqno "$dir/seq";
	open my $ref, ">>", "$dir/ref$suffix" or die "ref: $!";
	open my $def, ">>", "$dir/def$suffix" or die "def: $!";
	open my $seq, ">>", "$dir/seq" or die "seq: $!";
	for my $rpm (@$rpms) {
		my $argz = rpmelfsym $rpm;
		next if $argz eq "";
		use qa::memoize 0.02 'basename';
		$rpm = basename $rpm;
		collect_bad_elfsym1($rpm, $argz, $ref, $def, $seq, $seqno);
	}
}

1;
