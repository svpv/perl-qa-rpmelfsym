%define dist qa-rpmelfsym
Name: perl-%dist
Version: 0.07
Release: alt1

Summary: Faster rpmelfsym(1) and bad_elf_symbols implementation
License: GPLv2+
Group: Development/Perl

URL: %CPAN %dist
Source: %dist-%version.tar

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
* Tue Apr 07 2009 Alexey Tourbin <at@altlinux.ru> 0.07-alt1
- switched to (basename,size,mtime) caching mode
- flattened down internal data structure, for efficiency
- reverted piping to sort(1) and other optimizations proved inefficient
- optimized by saving (rpm-basename,filename) in a separate file
- optimized by eliminating huge 'sort -m' merges

* Fri Apr 03 2009 Alexey Tourbin <at@altlinux.ru> 0.06-alt1
- optimized inner loop writes for speed

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
