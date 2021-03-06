#include <string.h>
#include <errno.h>
#include <assert.h>
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifndef PIPE_BUF
#define PUPE_BUF 4096
#endif

MODULE	= qa::rpmelfsym		PACKAGE = qa::rpmelfsym

void
print_elfsym(rpm, argz, fh)
	SV * rpm
	SV * argz
	PerlIO * fh
    CODE:
	STRLEN argz_len = 0;
	char *argz_pv = SvPVbyte(argz, argz_len);
	char *argz_end = argz_pv + argz_len + 1;
	STRLEN rpm_len = 0;
	char *rpm_pv = SvPVbyte(rpm, rpm_len);
	if (*argz_pv != '/')
	    croak("%s: argz: invalid data", rpm_pv);
	SV *bufsv = sv_mortalcopy(rpm);
	char *buf = SvGROW(bufsv, rpm_len + 256);
	buf[rpm_len] = '\t';
	STRLEN prefix_len = 0;
	while (argz_pv < argz_end) {
	    argz_len = strlen(argz_pv);
	    if (isALPHA(*argz_pv)) {
		int n1 = prefix_len + 3 + argz_len;
		buf = SvGROW(bufsv, n1);
		buf[prefix_len + 1] = *argz_pv;
		memcpy(buf + prefix_len + 3, argz_pv + 1, argz_len - 1);
		buf[n1 - 1] = '\n';
		int n2 = PerlIO_write(fh, buf, n1);
		if (n1 != n2)
		    croak("fh: write error: %s", strerror(errno));
	    }
	    else if (*argz_pv == '/') {
		prefix_len = rpm_len + 1 + argz_len;
		buf = SvGROW(bufsv, prefix_len + 3);
		memcpy(buf + rpm_len + 1, argz_pv, argz_len);
		buf[prefix_len + 0] = '\t';
		buf[prefix_len + 2] = '\t';
	    }
	    argz_pv += argz_len + 1;
	}
	if (PerlIO_flush(fh) != 0)
	    croak("fh: flush error: %s", strerror(errno));

void
collect_bad_elfsym1(rpm, argz, ref, def, seq, seqno)
	SV * rpm
	SV * argz
	PerlIO * ref
	PerlIO * def
	PerlIO * seq
	SV * seqno
    CODE:
	int ref_fill = 0;
	int def_fill = 0;
	int seq_fill = 0;
	STRLEN argz_len = 0;
	char *argz_pv = SvPVbyte(argz, argz_len);
	char *argz_end = argz_pv + argz_len + 1;
	STRLEN rpm_len = 0;
	char *rpm_pv = SvPVbyte(rpm, rpm_len);
	if (*argz_pv != '/')
	    croak("%s: argz: invalid data", rpm_pv);
	STRLEN seqno_len = 0;
	char *seqno_pv = NULL;
	SvGROW(seqno, 256);
	while (argz_pv < argz_end) {
	    int n1 = 0;
	    int n2 = 0;
	    argz_len = strlen(argz_pv);
	    switch (*argz_pv) {
	    case 'U':
		n1 = seqno_len + argz_len + 1;
		assert(n1 < PIPE_BUF);
		if (ref_fill + n1 <= PIPE_BUF)
		    ref_fill += n1;
		else {
		    if (PerlIO_flush(ref) != 0)
			croak("ref: flush error: %s", strerror(errno));
		    ref_fill = n1;
		}
		seqno_pv = SvGROW(seqno, n1);
		memcpy(seqno_pv + seqno_len + 1, argz_pv + 1, argz_len - 1);
		seqno_pv[seqno_len] = '\t';
		seqno_pv[n1 - 1] = '\n';
		n2 = PerlIO_write(ref, seqno_pv, n1);
		seqno_pv[seqno_len] = '\0';
		if (n1 != n2)
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
		n1 = argz_len;
		assert(n1 < PIPE_BUF);
		if (def_fill + n1 <= PIPE_BUF)
		    def_fill += n1;
		else {
		    if (PerlIO_flush(def) != 0)
			croak("def: flush error: %s", strerror(errno));
		    def_fill = n1;
		}
		argz_pv[argz_len] = '\n';
		n2 = PerlIO_write(def, argz_pv + 1, argz_len);
		argz_pv[argz_len] = '\0';
		if (n1 != n2)
		    croak("def: write error: %s", strerror(errno));
		break;
	    case '/':
		sv_inc(seqno);
		sv_inc(seqno);
		seqno_pv = SvPVbyte(seqno, seqno_len);
		n1 = seqno_len + rpm_len + argz_len + 5;
		assert(n1 < PIPE_BUF);
		if (seq_fill + n1 <= PIPE_BUF)
		    seq_fill += n1;
		else {
		    if (PerlIO_flush(seq) != 0)
			croak("seq: flush error: %s", strerror(errno));
		    seq_fill = n1;
		}
		seqno_pv[seqno_len] = '\t';
		rpm_pv[rpm_len] = '\t';
		argz_pv[argz_len] = '\t';
		n2 += PerlIO_write(seq, seqno_pv, seqno_len + 1);
		n2 += PerlIO_write(seq, rpm_pv, rpm_len + 1);
		n2 += PerlIO_write(seq, argz_pv, argz_len + 1);
		n2 += PerlIO_write(seq, "U\n", 2);
		seqno_pv[seqno_len] = '\0';
		rpm_pv[rpm_len] = '\0';
		argz_pv[argz_len] = '\0';
		if (n1 != n2)
		    croak("seq: write error: %s", strerror(errno));
		break;
	    }
	    argz_pv += argz_len + 1;
	}
	if (PerlIO_flush(ref) != 0)
	    croak("ref: flush error: %s", strerror(errno));
	if (PerlIO_flush(def) != 0)
	    croak("def: flush error: %s", strerror(errno));
	if (PerlIO_flush(seq) != 0)
	    croak("seq: flush error: %s", strerror(errno));
