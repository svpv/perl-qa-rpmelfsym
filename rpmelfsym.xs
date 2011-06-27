#include <string.h>
#include <errno.h>
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

MODULE	= qa::rpmelfsym		PACKAGE = qa::rpmelfsym

void
collect_bad_elfsym(rpm, argz, ref, def, seq, seqno)
	SV * rpm
	SV * argz
	PerlIO * ref
	PerlIO * def
	PerlIO * seq
	SV * seqno
    CODE:
	STRLEN argz_len = 0;
	const char *argz_pv = SvPVbyte(argz, argz_len);
	const char *argz_end = argz_pv + argz_len;
	if (*argz_pv != '/' || argz_pv[argz_len - 1] != '\0')
	    croak("argz: invalid data");
	STRLEN rpm_len = 0;
	const char *rpm_pv = SvPVbyte(rpm, rpm_len);
	STRLEN seqno_len = 0;
	const char *seqno_pv = NULL;
	while (argz_pv < argz_end) {
	    int n = 0;
	    argz_len = strlen(argz_pv);
	    switch(*argz_pv) {
	    case 'U':
		n += PerlIO_write(ref, seqno_pv, seqno_len);
		n += PerlIO_write(ref, "\t", 1);
		n += PerlIO_write(ref, argz_pv + 1, argz_len - 1);
		n += PerlIO_write(ref, "\n", 1);
		if (n != seqno_len + argz_len + 1)
		    croak("ref: write error: %s", strerror(errno));
		break;
	    case 'T':
	    case 'W':
	    case 'V':
	    case 'D':
	    case 'B':
	    case 'A':
	    case 'R':
	    case 'u':
	    case 'i':
		n += PerlIO_write(def, argz_pv + 1, argz_len - 1);
		n += PerlIO_write(def, "\n", 1);
		if (n != argz_len)
		    croak("def: write error: %s", strerror(errno));
		break;
	    case '/':
		sv_inc(seqno);
		seqno_pv = SvPVbyte(seqno, seqno_len);
		n += PerlIO_write(seq, seqno_pv, seqno_len);
		n += PerlIO_write(seq, "\t", 1);
		n += PerlIO_write(seq, rpm_pv, rpm_len);
		n += PerlIO_write(seq, "\t", 1);
		n += PerlIO_write(seq, argz_pv, argz_len);
		n += PerlIO_write(seq, "\tU\n", 3);
		if (n != seqno_len + rpm_len + argz_len + 5)
		    croak("seq: write error: %s", strerror(errno));
		break;
	    }
	    argz_pv += argz_len + 1;
	}
