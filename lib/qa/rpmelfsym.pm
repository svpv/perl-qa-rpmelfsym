package qa::rpmelfsym;

use strict;

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
	my @out;
	while (my $ent = $cpio->next) {
		use Fcntl 'S_ISREG';
		next unless S_ISREG($ent->mode);
		next unless $ent->size > 4;

		my $filename = $ent->filename;
		$filename =~ s#^./+#/#;

		$ent->read(my $magic, 4) == 4 or die "$rpm: $filename: cpio read failed";
		next unless $magic eq "\177ELF";

		require File::Temp;
		my $tmp = File::Temp->new;

		my $write = sub ($) {
			my $len = length $_[0];
			my $off = 0;
			my $err;
			while ($len > 0) {
				my $wlen = syswrite $tmp, $_[0], $len, $off;
				if (not defined $wlen) {
					if ($err++) {
						die "$rpm: $filename: tmp write failed: $!";
					}
					else {
						warn "warning: $rpm: $filename: tmp write failed: $!";
						redo;
					}
				}
				elsif ($wlen == 0) {
					if ($err++) {
						die "$rpm: $filename: tmp write failed (0)";
					}
					else {
						warn "warning: $rpm: $filename: tmp write failed (0)";
						redo;
					}
				}
				else {
					$len -= $wlen;
					$off += $wlen;
					undef $err;
				}
			}
		};

		&$write($magic);

		my $n = $ent->size - 4;
		while ($n > 0) {
			use List::Util qw(min);
			my $m = min($n, 8192);
			$ent->read(my $buf, $m) == $m or die "$rpm: $filename: cpio read failed";
			&$write($buf);
			$n -= $m;
		}

		my $type = file("$tmp");
		next unless $type =~ /\bELF .*(dynamically linked|shared object)/;

		my @syms;
		open my $fh, "-|", "nm", "-D", "$tmp" or die "$rpm: $filename: nm failed";
		local $_;
		while (<$fh>) {
			chomp;
			my @sym = split;
			shift @sym if @sym == 3;
			@sym == 2 or die "$rpm: $filename: invalid nm output: $_";
			length($sym[0]) == 1 or die "$rpm: $filename: invalid nm output: $_";
			push @syms, \@sym;
		}
		close $fh or die "$rpm: $filename: nm failed";
		push @out, [ $filename, \@syms ] if @syms;
	}
	@out = sort { $$a[0] cmp $$b[0] } @out;
	return \@out;
}

use qa::memoize qw(memoize_st1);
memoize_st1("rpmelfsym");

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(rpmelfsym);

1;
