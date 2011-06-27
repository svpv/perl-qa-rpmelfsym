#include <string.h>
#include <errno.h>
#define PERL_NO_GET_CONTEXT
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
	char *argz_pv = SvPVbyte(argz, argz_len);
	char *argz_end = argz_pv + argz_len;
	if (*argz_pv != '/' || argz_pv[argz_len - 1] != '\0')
	    croak("argz: invalid data");
	STRLEN rpm_len = 0;
	char *rpm_pv = SvPVbyte(rpm, rpm_len);
	STRLEN seqno_len = 0;
	char *seqno_pv = NULL;
	while (argz_pv < argz_end) {
	    int n = 0;
	    argz_len = strlen(argz_pv);
	    switch(*argz_pv) {
	    case 'U':
		seqno_pv[seqno_len] = '\t';
		argz_pv[argz_len] = '\n';
		n += PerlIO_write(ref, seqno_pv, seqno_len + 1);
		n += PerlIO_write(ref, argz_pv + 1, argz_len);
		seqno_pv[seqno_len] = '\0';
		argz_pv[argz_len] = '\0';
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
		argz_pv[argz_len] = '\n';
		n += PerlIO_write(def, argz_pv + 1, argz_len);
		argz_pv[argz_len] = '\0';
		if (n != argz_len)
		    croak("def: write error: %s", strerror(errno));
		break;
	    case '/':
		sv_inc(seqno);
		seqno_pv = SvPVbyte(seqno, seqno_len);
		seqno_pv[seqno_len] = '\t';
		rpm_pv[rpm_len] = '\t';
		argz_pv[argz_len] = '\t';
		n += PerlIO_write(seq, seqno_pv, seqno_len + 1);
		n += PerlIO_write(seq, rpm_pv, rpm_len + 1);
		n += PerlIO_write(seq, argz_pv, argz_len + 1);
		n += PerlIO_write(seq, "U\n", 2);
		seqno_pv[seqno_len] = '\0';
		rpm_pv[rpm_len] = '\0';
		argz_pv[argz_len] = '\0';
		if (n != seqno_len + rpm_len + argz_len + 5)
		    croak("seq: write error: %s", strerror(errno));
		break;
	    }
	    argz_pv += argz_len + 1;
	}
