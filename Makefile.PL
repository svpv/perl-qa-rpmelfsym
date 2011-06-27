use ExtUtils::MakeMaker;
WriteMakefile
	NAME		=> 'qa::rpmelfsym',
	VERSION_FROM	=> 'lib/qa/rpmelfsym.pm',
	AUTHOR		=> 'Alexey Tourbin <at@altlinux.org>',
	EXE_FILES	=> [qw(rpmelfsym.pl bad_elf_symbols.pl bad_elf_symbols_dircmp.pl)],
	dist		=> { COMPRESS => 'gzip -9nf' },
	;
