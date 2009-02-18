use ExtUtils::MakeMaker;
WriteMakefile
	NAME		=> 'qa::rpmelfsym',
	VERSION		=> '0.01',
	AUTHOR		=> 'Alexey Tourbin <at@altlinux.org>',
	EXE_FILES	=> [qw(rpmelfsym.pl bad_elf_symbols.pl)],
	dist		=> { COMPRESS => 'gzip -9nf' },
	;
