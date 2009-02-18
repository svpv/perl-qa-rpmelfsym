%define dist qa-rpmelfsym
Name: perl-%dist
Version: 0.01
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
* Wed Feb 18 2009 Alexey Tourbin <at@altlinux.ru> 0.01-alt1
- initial revision
