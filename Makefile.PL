use ExtUtils::MakeMaker;
WriteMakefile
	NAME		=> 'qa::rpmelfsym',
	VERSION		=> '0.06',
	AUTHOR		=> 'Alexey Tourbin <at@altlinux.org>',
	EXE_FILES	=> [qw(rpmelfsym.pl bad_elf_symbols.pl bad_elf_symbols_dircmp.pl)],
	dist		=> { COMPRESS => 'gzip -9nf' },
	;
