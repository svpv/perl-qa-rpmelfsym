%define dist qa-rpmelfsym
Name: perl-%dist
Version: 0.05
Release: alt1

Summary: Faster rpmelfsym(1) and bad_elf_symbols implementation
License: GPLv2+
Group: Development/Perl

URL: %CPAN %dist
Source: %dist-%version.tar

# sort --compress-program=lzop
Requires: lzop, coreutils >= 6.8

BuildArch: noarch

# Automatically added by buildreq on Wed Feb 18 2009 (-bi)
BuildRequires: perl-File-LibMagic perl-devel perl-qa-cache

%description
no description

%prep
%setup -q -n %dist-%version

%build
%perl_vendor_build

%install
%perl_vendor_install

# MakeMaker sucks (and I don't know how to tweak it)
rm %buildroot%perl_vendor_privlib/qa/*.pl

%files
%_bindir/*.pl
%perl_vendor_privlib/qa*

%changelog
* Wed Apr 01 2009 Alexey Tourbin <at@altlinux.ru> 0.05-alt1
- bad_elf_symbols*.pl: optimize by running sort(1) in background

* Sun Feb 22 2009 Alexey Tourbin <at@altlinux.ru> 0.04-alt1
- rpmelfsym.pm: fixed ELF magic check for nm(1)

* Fri Feb 20 2009 Alexey Tourbin <at@altlinux.ru> 0.03-alt1
- implemented bad_elf_symbols_dircmp.pl, for use in girar-builder

* Thu Feb 19 2009 Alexey Tourbin <at@altlinux.ru> 0.02-alt1
- rpmelfsym.pm: better handling of tmp write errors

* Wed Feb 18 2009 Alexey Tourbin <at@altlinux.ru> 0.01-alt1
- initial revision
