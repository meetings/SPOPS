# This Makefile is for the SPOPS extension to perl.
#
# It was generated automatically by MakeMaker version
# 6.56 (Revision: 65600) from the contents of
# Makefile.PL. Don't edit this file, edit Makefile.PL instead.
#
#       ANY CHANGES MADE HERE WILL BE LOST!
#
#   MakeMaker ARGV: ()
#

#   MakeMaker Parameters:

#     ABSTRACT => q[Data abstraction layer used for object persistence and security]
#     AUTHOR => q[Chris Winters <chris@cwinters.com>]
#     BUILD_REQUIRES => {  }
#     NAME => q[SPOPS]
#     PREREQ_PM => { Carp::Assert=>q[0.17], Class::Fields=>q[0.14], Devel::StackTrace=>q[0.9], Class::Date=>q[1], Data::Dumper=>q[2], Class::Factory=>q[1], Class::Accessor=>q[0.17], Storable=>q[1], Time::Piece=>q[1.07], Test::More=>q[0.41], Log::Dispatch=>q[2], Class::ISA=>q[0.32], Log::Log4perl=>q[0.35] }
#     VERSION_FROM => q[SPOPS.pm]

# --- MakeMaker post_initialize section:


# --- MakeMaker const_config section:

# These definitions are from config.sh (via /usr/lib/perl/5.10/Config.pm).
# They may have been overridden via Makefile.PL or on the command line.
AR = ar
CC = cc
CCCDLFLAGS = -fPIC
CCDLFLAGS = -Wl,-E
DLEXT = so
DLSRC = dl_dlopen.xs
EXE_EXT = 
FULL_AR = /usr/bin/ar
LD = cc
LDDLFLAGS = -shared -O2 -g -L/usr/local/lib
LDFLAGS =  -L/usr/local/lib
LIBC = /lib/libc-2.7.so
LIB_EXT = .a
OBJ_EXT = .o
OSNAME = linux
OSVERS = 2.6.26-2-amd64
RANLIB = :
SITELIBEXP = /usr/local/share/perl/5.10.0
SITEARCHEXP = /usr/local/lib/perl/5.10.0
SO = so
VENDORARCHEXP = /usr/lib/perl5
VENDORLIBEXP = /usr/share/perl5


# --- MakeMaker constants section:
AR_STATIC_ARGS = cr
DIRFILESEP = /
DFSEP = $(DIRFILESEP)
NAME = SPOPS
NAME_SYM = SPOPS
VERSION = 0.87
VERSION_MACRO = VERSION
VERSION_SYM = 0_87
DEFINE_VERSION = -D$(VERSION_MACRO)=\"$(VERSION)\"
XS_VERSION = 0.87
XS_VERSION_MACRO = XS_VERSION
XS_DEFINE_VERSION = -D$(XS_VERSION_MACRO)=\"$(XS_VERSION)\"
INST_ARCHLIB = blib/arch
INST_SCRIPT = blib/script
INST_BIN = blib/bin
INST_LIB = blib/lib
INST_MAN1DIR = blib/man1
INST_MAN3DIR = blib/man3
MAN1EXT = 1p
MAN3EXT = 3pm
INSTALLDIRS = site
DESTDIR = 
PREFIX = $(SITEPREFIX)
PERLPREFIX = /usr
SITEPREFIX = /usr/local
VENDORPREFIX = /usr
INSTALLPRIVLIB = /usr/share/perl/5.10
DESTINSTALLPRIVLIB = $(DESTDIR)$(INSTALLPRIVLIB)
INSTALLSITELIB = /usr/local/share/perl/5.10.0
DESTINSTALLSITELIB = $(DESTDIR)$(INSTALLSITELIB)
INSTALLVENDORLIB = /usr/share/perl5
DESTINSTALLVENDORLIB = $(DESTDIR)$(INSTALLVENDORLIB)
INSTALLARCHLIB = /usr/lib/perl/5.10
DESTINSTALLARCHLIB = $(DESTDIR)$(INSTALLARCHLIB)
INSTALLSITEARCH = /usr/local/lib/perl/5.10.0
DESTINSTALLSITEARCH = $(DESTDIR)$(INSTALLSITEARCH)
INSTALLVENDORARCH = /usr/lib/perl5
DESTINSTALLVENDORARCH = $(DESTDIR)$(INSTALLVENDORARCH)
INSTALLBIN = /usr/bin
DESTINSTALLBIN = $(DESTDIR)$(INSTALLBIN)
INSTALLSITEBIN = /usr/local/bin
DESTINSTALLSITEBIN = $(DESTDIR)$(INSTALLSITEBIN)
INSTALLVENDORBIN = /usr/bin
DESTINSTALLVENDORBIN = $(DESTDIR)$(INSTALLVENDORBIN)
INSTALLSCRIPT = /usr/bin
DESTINSTALLSCRIPT = $(DESTDIR)$(INSTALLSCRIPT)
INSTALLSITESCRIPT = /usr/local/bin
DESTINSTALLSITESCRIPT = $(DESTDIR)$(INSTALLSITESCRIPT)
INSTALLVENDORSCRIPT = /usr/bin
DESTINSTALLVENDORSCRIPT = $(DESTDIR)$(INSTALLVENDORSCRIPT)
INSTALLMAN1DIR = /usr/share/man/man1
DESTINSTALLMAN1DIR = $(DESTDIR)$(INSTALLMAN1DIR)
INSTALLSITEMAN1DIR = /usr/local/man/man1
DESTINSTALLSITEMAN1DIR = $(DESTDIR)$(INSTALLSITEMAN1DIR)
INSTALLVENDORMAN1DIR = /usr/share/man/man1
DESTINSTALLVENDORMAN1DIR = $(DESTDIR)$(INSTALLVENDORMAN1DIR)
INSTALLMAN3DIR = /usr/share/man/man3
DESTINSTALLMAN3DIR = $(DESTDIR)$(INSTALLMAN3DIR)
INSTALLSITEMAN3DIR = /usr/local/man/man3
DESTINSTALLSITEMAN3DIR = $(DESTDIR)$(INSTALLSITEMAN3DIR)
INSTALLVENDORMAN3DIR = /usr/share/man/man3
DESTINSTALLVENDORMAN3DIR = $(DESTDIR)$(INSTALLVENDORMAN3DIR)
PERL_LIB = /usr/share/perl/5.10
PERL_ARCHLIB = /usr/lib/perl/5.10
LIBPERL_A = libperl.a
FIRST_MAKEFILE = Makefile
MAKEFILE_OLD = Makefile.old
MAKE_APERL_FILE = Makefile.aperl
PERLMAINCC = $(CC)
PERL_INC = /usr/lib/perl/5.10/CORE
PERL = /usr/bin/perl
FULLPERL = /usr/bin/perl
ABSPERL = $(PERL)
PERLRUN = $(PERL)
FULLPERLRUN = $(FULLPERL)
ABSPERLRUN = $(ABSPERL)
PERLRUNINST = $(PERLRUN) "-I$(INST_ARCHLIB)" "-I$(INST_LIB)"
FULLPERLRUNINST = $(FULLPERLRUN) "-I$(INST_ARCHLIB)" "-I$(INST_LIB)"
ABSPERLRUNINST = $(ABSPERLRUN) "-I$(INST_ARCHLIB)" "-I$(INST_LIB)"
PERL_CORE = 0
PERM_DIR = 755
PERM_RW = 644
PERM_RWX = 755

MAKEMAKER   = /usr/local/share/perl/5.10.0/ExtUtils/MakeMaker.pm
MM_VERSION  = 6.56
MM_REVISION = 65600

# FULLEXT = Pathname for extension directory (eg Foo/Bar/Oracle).
# BASEEXT = Basename part of FULLEXT. May be just equal FULLEXT. (eg Oracle)
# PARENT_NAME = NAME without BASEEXT and no trailing :: (eg Foo::Bar)
# DLBASE  = Basename part of dynamic library. May be just equal BASEEXT.
MAKE = make
FULLEXT = SPOPS
BASEEXT = SPOPS
PARENT_NAME = 
DLBASE = $(BASEEXT)
VERSION_FROM = SPOPS.pm
OBJECT = 
LDFROM = $(OBJECT)
LINKTYPE = dynamic
BOOTDEP = 

# Handy lists of source code files:
XS_FILES = 
C_FILES  = 
O_FILES  = 
H_FILES  = 
MAN1PODS = 
MAN3PODS = SPOPS.pm \
	SPOPS/ClassFactory.pm \
	SPOPS/ClassFactory/DBI.pm \
	SPOPS/ClassFactory/DefaultBehavior.pm \
	SPOPS/ClassFactory/LDAP.pm \
	SPOPS/DBI.pm \
	SPOPS/DBI/InterBase.pm \
	SPOPS/DBI/MySQL.pm \
	SPOPS/DBI/Oracle.pm \
	SPOPS/DBI/Pg.pm \
	SPOPS/DBI/SQLite.pm \
	SPOPS/DBI/Sybase.pm \
	SPOPS/DBI/TypeInfo.pm \
	SPOPS/Error.pm \
	SPOPS/Exception.pm \
	SPOPS/Exception/DBI.pm \
	SPOPS/Exception/LDAP.pm \
	SPOPS/Exception/Security.pm \
	SPOPS/Export.pm \
	SPOPS/Export/DBI/Data.pm \
	SPOPS/Export/Object.pm \
	SPOPS/Export/Perl.pm \
	SPOPS/Export/SQL.pm \
	SPOPS/Export/XML.pm \
	SPOPS/GDBM.pm \
	SPOPS/HashFile.pm \
	SPOPS/Import.pm \
	SPOPS/Import/DBI/Data.pm \
	SPOPS/Import/DBI/Delete.pm \
	SPOPS/Import/DBI/GenericOperation.pm \
	SPOPS/Import/DBI/Table.pm \
	SPOPS/Import/DBI/TableTransform.pm \
	SPOPS/Import/DBI/TableTransform/InterBase.pm \
	SPOPS/Import/DBI/TableTransform/MySQL.pm \
	SPOPS/Import/DBI/TableTransform/Oracle.pm \
	SPOPS/Import/DBI/TableTransform/Pg.pm \
	SPOPS/Import/DBI/TableTransform/SQLite.pm \
	SPOPS/Import/DBI/TableTransform/Sybase.pm \
	SPOPS/Import/DBI/Update.pm \
	SPOPS/Import/Object.pm \
	SPOPS/Initialize.pm \
	SPOPS/Iterator.pm \
	SPOPS/Iterator/DBI.pm \
	SPOPS/Iterator/LDAP.pm \
	SPOPS/Iterator/WrapList.pm \
	SPOPS/Key/DBI/HandleField.pm \
	SPOPS/Key/DBI/Identity.pm \
	SPOPS/Key/DBI/Pool.pm \
	SPOPS/Key/DBI/Sequence.pm \
	SPOPS/Key/Random.pm \
	SPOPS/Key/UUID.pm \
	SPOPS/LDAP.pm \
	SPOPS/LDAP/MultiDatasource.pm \
	SPOPS/Loopback.pm \
	SPOPS/Manual.pod \
	SPOPS/Manual/CodeGeneration.pod \
	SPOPS/Manual/Configuration.pod \
	SPOPS/Manual/Cookbook.pod \
	SPOPS/Manual/Datasource.pod \
	SPOPS/Manual/Exceptions.pod \
	SPOPS/Manual/ImportExport.pod \
	SPOPS/Manual/Intro.pod \
	SPOPS/Manual/Object.pod \
	SPOPS/Manual/ObjectRules.pod \
	SPOPS/Manual/Relationships.pod \
	SPOPS/Manual/Security.pod \
	SPOPS/Manual/Serialization.pod \
	SPOPS/SQLInterface.pm \
	SPOPS/Secure.pm \
	SPOPS/Secure/DBI.pm \
	SPOPS/Secure/Hierarchy.pm \
	SPOPS/Secure/Loopback.pm \
	SPOPS/Secure/Util.pm \
	SPOPS/Tie.pm \
	SPOPS/Tie/StrictField.pm \
	SPOPS/Tool/CreateOnly.pm \
	SPOPS/Tool/DBI/Datasource.pm \
	SPOPS/Tool/DBI/DiscoverField.pm \
	SPOPS/Tool/DBI/FindDefaults.pm \
	SPOPS/Tool/DBI/MaintainLinkedList.pm \
	SPOPS/Tool/DateConvert.pm \
	SPOPS/Tool/LDAP/Datasource.pm \
	SPOPS/Tool/ReadOnly.pm \
	SPOPS/Tool/UTFConvert.pm \
	SPOPS/Utility.pm

# Where is the Config information that we are using/depend on
CONFIGDEP = $(PERL_ARCHLIB)$(DFSEP)Config.pm $(PERL_INC)$(DFSEP)config.h

# Where to build things
INST_LIBDIR      = $(INST_LIB)
INST_ARCHLIBDIR  = $(INST_ARCHLIB)

INST_AUTODIR     = $(INST_LIB)/auto/$(FULLEXT)
INST_ARCHAUTODIR = $(INST_ARCHLIB)/auto/$(FULLEXT)

INST_STATIC      = 
INST_DYNAMIC     = 
INST_BOOT        = 

# Extra linker info
EXPORT_LIST        = 
PERL_ARCHIVE       = 
PERL_ARCHIVE_AFTER = 


TO_INST_PM = SPOPS.pm \
	SPOPS/ClassFactory.pm \
	SPOPS/ClassFactory/DBI.pm \
	SPOPS/ClassFactory/DefaultBehavior.pm \
	SPOPS/ClassFactory/LDAP.pm \
	SPOPS/DBI.pm \
	SPOPS/DBI/InterBase.pm \
	SPOPS/DBI/MySQL.pm \
	SPOPS/DBI/Oracle.pm \
	SPOPS/DBI/Pg.pm \
	SPOPS/DBI/SQLite.pm \
	SPOPS/DBI/Sybase.pm \
	SPOPS/DBI/TypeInfo.pm \
	SPOPS/Error.pm \
	SPOPS/Exception.pm \
	SPOPS/Exception/DBI.pm \
	SPOPS/Exception/LDAP.pm \
	SPOPS/Exception/Security.pm \
	SPOPS/Export.pm \
	SPOPS/Export/DBI/Data.pm \
	SPOPS/Export/Object.pm \
	SPOPS/Export/Perl.pm \
	SPOPS/Export/SQL.pm \
	SPOPS/Export/XML.pm \
	SPOPS/GDBM.pm \
	SPOPS/HashFile.pm \
	SPOPS/Import.pm \
	SPOPS/Import/DBI/Data.pm \
	SPOPS/Import/DBI/Delete.pm \
	SPOPS/Import/DBI/GenericOperation.pm \
	SPOPS/Import/DBI/Table.pm \
	SPOPS/Import/DBI/TableTransform.pm \
	SPOPS/Import/DBI/TableTransform/InterBase.pm \
	SPOPS/Import/DBI/TableTransform/MySQL.pm \
	SPOPS/Import/DBI/TableTransform/Oracle.pm \
	SPOPS/Import/DBI/TableTransform/Pg.pm \
	SPOPS/Import/DBI/TableTransform/SQLite.pm \
	SPOPS/Import/DBI/TableTransform/Sybase.pm \
	SPOPS/Import/DBI/Update.pm \
	SPOPS/Import/Object.pm \
	SPOPS/Initialize.pm \
	SPOPS/Iterator.pm \
	SPOPS/Iterator/DBI.pm \
	SPOPS/Iterator/LDAP.pm \
	SPOPS/Iterator/WrapList.pm \
	SPOPS/Key/DBI/HandleField.pm \
	SPOPS/Key/DBI/Identity.pm \
	SPOPS/Key/DBI/Pool.pm \
	SPOPS/Key/DBI/Sequence.pm \
	SPOPS/Key/Random.pm \
	SPOPS/Key/UUID.pm \
	SPOPS/LDAP.pm \
	SPOPS/LDAP/MultiDatasource.pm \
	SPOPS/Loopback.pm \
	SPOPS/Manual.pod \
	SPOPS/Manual/CodeGeneration.pod \
	SPOPS/Manual/Configuration.pod \
	SPOPS/Manual/Cookbook.pod \
	SPOPS/Manual/Datasource.pod \
	SPOPS/Manual/Exceptions.pod \
	SPOPS/Manual/ImportExport.pod \
	SPOPS/Manual/Intro.pod \
	SPOPS/Manual/Object.pod \
	SPOPS/Manual/ObjectRules.pod \
	SPOPS/Manual/Relationships.pod \
	SPOPS/Manual/Security.pod \
	SPOPS/Manual/Serialization.pod \
	SPOPS/SQLInterface.pm \
	SPOPS/Secure.pm \
	SPOPS/Secure/DBI.pm \
	SPOPS/Secure/Hierarchy.pm \
	SPOPS/Secure/Loopback.pm \
	SPOPS/Secure/Util.pm \
	SPOPS/Tie.pm \
	SPOPS/Tie/StrictField.pm \
	SPOPS/Tool/CreateOnly.pm \
	SPOPS/Tool/DBI/Datasource.pm \
	SPOPS/Tool/DBI/DiscoverField.pm \
	SPOPS/Tool/DBI/FindDefaults.pm \
	SPOPS/Tool/DBI/MaintainLinkedList.pm \
	SPOPS/Tool/DateConvert.pm \
	SPOPS/Tool/LDAP/Datasource.pm \
	SPOPS/Tool/ReadOnly.pm \
	SPOPS/Tool/UTFConvert.pm \
	SPOPS/Utility.pm

PM_TO_BLIB = SPOPS/Manual/Serialization.pod \
	$(INST_LIB)/SPOPS/Manual/Serialization.pod \
	SPOPS/Import.pm \
	$(INST_LIB)/SPOPS/Import.pm \
	SPOPS/Secure/Hierarchy.pm \
	$(INST_LIB)/SPOPS/Secure/Hierarchy.pm \
	SPOPS/Key/DBI/Pool.pm \
	$(INST_LIB)/SPOPS/Key/DBI/Pool.pm \
	SPOPS/Iterator/WrapList.pm \
	$(INST_LIB)/SPOPS/Iterator/WrapList.pm \
	SPOPS/Import/DBI/Update.pm \
	$(INST_LIB)/SPOPS/Import/DBI/Update.pm \
	SPOPS/Iterator/LDAP.pm \
	$(INST_LIB)/SPOPS/Iterator/LDAP.pm \
	SPOPS/Import/DBI/Table.pm \
	$(INST_LIB)/SPOPS/Import/DBI/Table.pm \
	SPOPS/Import/Object.pm \
	$(INST_LIB)/SPOPS/Import/Object.pm \
	SPOPS/ClassFactory/DefaultBehavior.pm \
	$(INST_LIB)/SPOPS/ClassFactory/DefaultBehavior.pm \
	SPOPS/Import/DBI/TableTransform/MySQL.pm \
	$(INST_LIB)/SPOPS/Import/DBI/TableTransform/MySQL.pm \
	SPOPS/DBI/InterBase.pm \
	$(INST_LIB)/SPOPS/DBI/InterBase.pm \
	SPOPS/ClassFactory.pm \
	$(INST_LIB)/SPOPS/ClassFactory.pm \
	SPOPS/Key/DBI/Identity.pm \
	$(INST_LIB)/SPOPS/Key/DBI/Identity.pm \
	SPOPS/Key/Random.pm \
	$(INST_LIB)/SPOPS/Key/Random.pm \
	SPOPS/Import/DBI/TableTransform/Pg.pm \
	$(INST_LIB)/SPOPS/Import/DBI/TableTransform/Pg.pm \
	SPOPS/Manual/Object.pod \
	$(INST_LIB)/SPOPS/Manual/Object.pod \
	SPOPS/SQLInterface.pm \
	$(INST_LIB)/SPOPS/SQLInterface.pm \
	SPOPS/Manual/Exceptions.pod \
	$(INST_LIB)/SPOPS/Manual/Exceptions.pod \
	SPOPS/Secure.pm \
	$(INST_LIB)/SPOPS/Secure.pm \
	SPOPS/DBI/Pg.pm \
	$(INST_LIB)/SPOPS/DBI/Pg.pm \
	SPOPS/Tool/DBI/FindDefaults.pm \
	$(INST_LIB)/SPOPS/Tool/DBI/FindDefaults.pm \
	SPOPS/GDBM.pm \
	$(INST_LIB)/SPOPS/GDBM.pm \
	SPOPS/Export/XML.pm \
	$(INST_LIB)/SPOPS/Export/XML.pm \
	SPOPS/DBI.pm \
	$(INST_LIB)/SPOPS/DBI.pm \
	SPOPS/Import/DBI/GenericOperation.pm \
	$(INST_LIB)/SPOPS/Import/DBI/GenericOperation.pm \
	SPOPS/Import/DBI/TableTransform/Sybase.pm \
	$(INST_LIB)/SPOPS/Import/DBI/TableTransform/Sybase.pm \
	SPOPS/Import/DBI/Data.pm \
	$(INST_LIB)/SPOPS/Import/DBI/Data.pm \
	SPOPS/Manual/ImportExport.pod \
	$(INST_LIB)/SPOPS/Manual/ImportExport.pod \
	SPOPS/Manual/ObjectRules.pod \
	$(INST_LIB)/SPOPS/Manual/ObjectRules.pod \
	SPOPS/Tie/StrictField.pm \
	$(INST_LIB)/SPOPS/Tie/StrictField.pm \
	SPOPS/Key/UUID.pm \
	$(INST_LIB)/SPOPS/Key/UUID.pm \
	SPOPS/Exception/Security.pm \
	$(INST_LIB)/SPOPS/Exception/Security.pm \
	SPOPS/Error.pm \
	$(INST_LIB)/SPOPS/Error.pm \
	SPOPS/Import/DBI/TableTransform/InterBase.pm \
	$(INST_LIB)/SPOPS/Import/DBI/TableTransform/InterBase.pm \
	SPOPS/Key/DBI/HandleField.pm \
	$(INST_LIB)/SPOPS/Key/DBI/HandleField.pm \
	SPOPS.pm \
	$(INST_LIB)/SPOPS.pm \
	SPOPS/Manual/Relationships.pod \
	$(INST_LIB)/SPOPS/Manual/Relationships.pod \
	SPOPS/Iterator.pm \
	$(INST_LIB)/SPOPS/Iterator.pm \
	SPOPS/Tool/DateConvert.pm \
	$(INST_LIB)/SPOPS/Tool/DateConvert.pm \
	SPOPS/Export.pm \
	$(INST_LIB)/SPOPS/Export.pm \
	SPOPS/Manual/Datasource.pod \
	$(INST_LIB)/SPOPS/Manual/Datasource.pod \
	SPOPS/Tool/DBI/MaintainLinkedList.pm \
	$(INST_LIB)/SPOPS/Tool/DBI/MaintainLinkedList.pm \
	SPOPS/Key/DBI/Sequence.pm \
	$(INST_LIB)/SPOPS/Key/DBI/Sequence.pm \
	SPOPS/Tool/DBI/Datasource.pm \
	$(INST_LIB)/SPOPS/Tool/DBI/Datasource.pm \
	SPOPS/HashFile.pm \
	$(INST_LIB)/SPOPS/HashFile.pm \
	SPOPS/Manual/Configuration.pod \
	$(INST_LIB)/SPOPS/Manual/Configuration.pod \
	SPOPS/Iterator/DBI.pm \
	$(INST_LIB)/SPOPS/Iterator/DBI.pm \
	SPOPS/Tool/UTFConvert.pm \
	$(INST_LIB)/SPOPS/Tool/UTFConvert.pm \
	SPOPS/Secure/DBI.pm \
	$(INST_LIB)/SPOPS/Secure/DBI.pm \
	SPOPS/Tie.pm \
	$(INST_LIB)/SPOPS/Tie.pm \
	SPOPS/Manual.pod \
	$(INST_LIB)/SPOPS/Manual.pod \
	SPOPS/Initialize.pm \
	$(INST_LIB)/SPOPS/Initialize.pm \
	SPOPS/DBI/MySQL.pm \
	$(INST_LIB)/SPOPS/DBI/MySQL.pm \
	SPOPS/Tool/DBI/DiscoverField.pm \
	$(INST_LIB)/SPOPS/Tool/DBI/DiscoverField.pm \
	SPOPS/ClassFactory/LDAP.pm \
	$(INST_LIB)/SPOPS/ClassFactory/LDAP.pm \
	SPOPS/Secure/Util.pm \
	$(INST_LIB)/SPOPS/Secure/Util.pm \
	SPOPS/DBI/Oracle.pm \
	$(INST_LIB)/SPOPS/DBI/Oracle.pm \
	SPOPS/Import/DBI/TableTransform/Oracle.pm \
	$(INST_LIB)/SPOPS/Import/DBI/TableTransform/Oracle.pm \
	SPOPS/Export/SQL.pm \
	$(INST_LIB)/SPOPS/Export/SQL.pm \
	SPOPS/DBI/Sybase.pm \
	$(INST_LIB)/SPOPS/DBI/Sybase.pm \
	SPOPS/Tool/ReadOnly.pm \
	$(INST_LIB)/SPOPS/Tool/ReadOnly.pm \
	SPOPS/Tool/CreateOnly.pm \
	$(INST_LIB)/SPOPS/Tool/CreateOnly.pm \
	SPOPS/Import/DBI/Delete.pm \
	$(INST_LIB)/SPOPS/Import/DBI/Delete.pm \
	SPOPS/Export/DBI/Data.pm \
	$(INST_LIB)/SPOPS/Export/DBI/Data.pm \
	SPOPS/Manual/CodeGeneration.pod \
	$(INST_LIB)/SPOPS/Manual/CodeGeneration.pod \
	SPOPS/ClassFactory/DBI.pm \
	$(INST_LIB)/SPOPS/ClassFactory/DBI.pm \
	SPOPS/Import/DBI/TableTransform/SQLite.pm \
	$(INST_LIB)/SPOPS/Import/DBI/TableTransform/SQLite.pm \
	SPOPS/Secure/Loopback.pm \
	$(INST_LIB)/SPOPS/Secure/Loopback.pm \
	SPOPS/DBI/TypeInfo.pm \
	$(INST_LIB)/SPOPS/DBI/TypeInfo.pm \
	SPOPS/Exception/LDAP.pm \
	$(INST_LIB)/SPOPS/Exception/LDAP.pm \
	SPOPS/Exception.pm \
	$(INST_LIB)/SPOPS/Exception.pm \
	SPOPS/LDAP/MultiDatasource.pm \
	$(INST_LIB)/SPOPS/LDAP/MultiDatasource.pm \
	SPOPS/Export/Object.pm \
	$(INST_LIB)/SPOPS/Export/Object.pm \
	SPOPS/LDAP.pm \
	$(INST_LIB)/SPOPS/LDAP.pm \
	SPOPS/Manual/Security.pod \
	$(INST_LIB)/SPOPS/Manual/Security.pod \
	SPOPS/Manual/Cookbook.pod \
	$(INST_LIB)/SPOPS/Manual/Cookbook.pod \
	SPOPS/Tool/LDAP/Datasource.pm \
	$(INST_LIB)/SPOPS/Tool/LDAP/Datasource.pm \
	SPOPS/Exception/DBI.pm \
	$(INST_LIB)/SPOPS/Exception/DBI.pm \
	SPOPS/Utility.pm \
	$(INST_LIB)/SPOPS/Utility.pm \
	SPOPS/Manual/Intro.pod \
	$(INST_LIB)/SPOPS/Manual/Intro.pod \
	SPOPS/Export/Perl.pm \
	$(INST_LIB)/SPOPS/Export/Perl.pm \
	SPOPS/Loopback.pm \
	$(INST_LIB)/SPOPS/Loopback.pm \
	SPOPS/DBI/SQLite.pm \
	$(INST_LIB)/SPOPS/DBI/SQLite.pm \
	SPOPS/Import/DBI/TableTransform.pm \
	$(INST_LIB)/SPOPS/Import/DBI/TableTransform.pm


# --- MakeMaker platform_constants section:
MM_Unix_VERSION = 6.56
PERL_MALLOC_DEF = -DPERL_EXTMALLOC_DEF -Dmalloc=Perl_malloc -Dfree=Perl_mfree -Drealloc=Perl_realloc -Dcalloc=Perl_calloc


# --- MakeMaker tool_autosplit section:
# Usage: $(AUTOSPLITFILE) FileToSplit AutoDirToSplitInto
AUTOSPLITFILE = $(ABSPERLRUN)  -e 'use AutoSplit;  autosplit($$ARGV[0], $$ARGV[1], 0, 1, 1)' --



# --- MakeMaker tool_xsubpp section:


# --- MakeMaker tools_other section:
SHELL = /bin/sh
CHMOD = chmod
CP = cp
MV = mv
NOOP = $(TRUE)
NOECHO = @
RM_F = rm -f
RM_RF = rm -rf
TEST_F = test -f
TOUCH = touch
UMASK_NULL = umask 0
DEV_NULL = > /dev/null 2>&1
MKPATH = $(ABSPERLRUN) -MExtUtils::Command -e 'mkpath' --
EQUALIZE_TIMESTAMP = $(ABSPERLRUN) -MExtUtils::Command -e 'eqtime' --
FALSE = false
TRUE = true
ECHO = echo
ECHO_N = echo -n
UNINST = 0
VERBINST = 0
MOD_INSTALL = $(ABSPERLRUN) -MExtUtils::Install -e 'install([ from_to => {@ARGV}, verbose => '\''$(VERBINST)'\'', uninstall_shadows => '\''$(UNINST)'\'', dir_mode => '\''$(PERM_DIR)'\'' ]);' --
DOC_INSTALL = $(ABSPERLRUN) -MExtUtils::Command::MM -e 'perllocal_install' --
UNINSTALL = $(ABSPERLRUN) -MExtUtils::Command::MM -e 'uninstall' --
WARN_IF_OLD_PACKLIST = $(ABSPERLRUN) -MExtUtils::Command::MM -e 'warn_if_old_packlist' --
MACROSTART = 
MACROEND = 
USEMAKEFILE = -f
FIXIN = $(ABSPERLRUN) -MExtUtils::MY -e 'MY->fixin(shift)' --


# --- MakeMaker makemakerdflt section:
makemakerdflt : all
	$(NOECHO) $(NOOP)


# --- MakeMaker dist section:
TAR = tar
TARFLAGS = cvf
ZIP = zip
ZIPFLAGS = -r
COMPRESS = gzip --best
SUFFIX = .gz
SHAR = shar
PREOP = $(NOECHO) $(NOOP)
POSTOP = $(NOECHO) $(NOOP)
TO_UNIX = $(NOECHO) $(NOOP)
CI = ci -u
RCS_LABEL = rcs -Nv$(VERSION_SYM): -q
DIST_CP = best
DIST_DEFAULT = tardist
DISTNAME = SPOPS
DISTVNAME = SPOPS-0.87


# --- MakeMaker macro section:


# --- MakeMaker depend section:


# --- MakeMaker cflags section:


# --- MakeMaker const_loadlibs section:


# --- MakeMaker const_cccmd section:


# --- MakeMaker post_constants section:


# --- MakeMaker pasthru section:

PASTHRU = LIBPERL_A="$(LIBPERL_A)"\
	LINKTYPE="$(LINKTYPE)"\
	PREFIX="$(PREFIX)"


# --- MakeMaker special_targets section:
.SUFFIXES : .xs .c .C .cpp .i .s .cxx .cc $(OBJ_EXT)

.PHONY: all config static dynamic test linkext manifest blibdirs clean realclean disttest distdir



# --- MakeMaker c_o section:


# --- MakeMaker xs_c section:


# --- MakeMaker xs_o section:


# --- MakeMaker top_targets section:
all :: pure_all manifypods
	$(NOECHO) $(NOOP)


pure_all :: config pm_to_blib subdirs linkext
	$(NOECHO) $(NOOP)

subdirs :: $(MYEXTLIB)
	$(NOECHO) $(NOOP)

config :: $(FIRST_MAKEFILE) blibdirs
	$(NOECHO) $(NOOP)

help :
	perldoc ExtUtils::MakeMaker


# --- MakeMaker blibdirs section:
blibdirs : $(INST_LIBDIR)$(DFSEP).exists $(INST_ARCHLIB)$(DFSEP).exists $(INST_AUTODIR)$(DFSEP).exists $(INST_ARCHAUTODIR)$(DFSEP).exists $(INST_BIN)$(DFSEP).exists $(INST_SCRIPT)$(DFSEP).exists $(INST_MAN1DIR)$(DFSEP).exists $(INST_MAN3DIR)$(DFSEP).exists
	$(NOECHO) $(NOOP)

# Backwards compat with 6.18 through 6.25
blibdirs.ts : blibdirs
	$(NOECHO) $(NOOP)

$(INST_LIBDIR)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_LIBDIR)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_LIBDIR)
	$(NOECHO) $(TOUCH) $(INST_LIBDIR)$(DFSEP).exists

$(INST_ARCHLIB)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_ARCHLIB)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_ARCHLIB)
	$(NOECHO) $(TOUCH) $(INST_ARCHLIB)$(DFSEP).exists

$(INST_AUTODIR)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_AUTODIR)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_AUTODIR)
	$(NOECHO) $(TOUCH) $(INST_AUTODIR)$(DFSEP).exists

$(INST_ARCHAUTODIR)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_ARCHAUTODIR)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_ARCHAUTODIR)
	$(NOECHO) $(TOUCH) $(INST_ARCHAUTODIR)$(DFSEP).exists

$(INST_BIN)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_BIN)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_BIN)
	$(NOECHO) $(TOUCH) $(INST_BIN)$(DFSEP).exists

$(INST_SCRIPT)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_SCRIPT)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_SCRIPT)
	$(NOECHO) $(TOUCH) $(INST_SCRIPT)$(DFSEP).exists

$(INST_MAN1DIR)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_MAN1DIR)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_MAN1DIR)
	$(NOECHO) $(TOUCH) $(INST_MAN1DIR)$(DFSEP).exists

$(INST_MAN3DIR)$(DFSEP).exists :: Makefile.PL
	$(NOECHO) $(MKPATH) $(INST_MAN3DIR)
	$(NOECHO) $(CHMOD) $(PERM_DIR) $(INST_MAN3DIR)
	$(NOECHO) $(TOUCH) $(INST_MAN3DIR)$(DFSEP).exists



# --- MakeMaker linkext section:

linkext :: $(LINKTYPE)
	$(NOECHO) $(NOOP)


# --- MakeMaker dlsyms section:


# --- MakeMaker dynamic section:

dynamic :: $(FIRST_MAKEFILE) $(INST_DYNAMIC) $(INST_BOOT)
	$(NOECHO) $(NOOP)


# --- MakeMaker dynamic_bs section:

BOOTSTRAP =


# --- MakeMaker dynamic_lib section:


# --- MakeMaker static section:

## $(INST_PM) has been moved to the all: target.
## It remains here for awhile to allow for old usage: "make static"
static :: $(FIRST_MAKEFILE) $(INST_STATIC)
	$(NOECHO) $(NOOP)


# --- MakeMaker static_lib section:


# --- MakeMaker manifypods section:

POD2MAN_EXE = $(PERLRUN) "-MExtUtils::Command::MM" -e pod2man "--"
POD2MAN = $(POD2MAN_EXE)


manifypods : pure_all  \
	SPOPS/Manual/Serialization.pod \
	SPOPS/Import.pm \
	SPOPS/Secure/Hierarchy.pm \
	SPOPS/Key/DBI/Pool.pm \
	SPOPS/Iterator/WrapList.pm \
	SPOPS/Import/DBI/Update.pm \
	SPOPS/Iterator/LDAP.pm \
	SPOPS/Import/DBI/Table.pm \
	SPOPS/Import/Object.pm \
	SPOPS/ClassFactory/DefaultBehavior.pm \
	SPOPS/Import/DBI/TableTransform/MySQL.pm \
	SPOPS/DBI/InterBase.pm \
	SPOPS/ClassFactory.pm \
	SPOPS/Key/DBI/Identity.pm \
	SPOPS/Key/Random.pm \
	SPOPS/Import/DBI/TableTransform/Pg.pm \
	SPOPS/Manual/Object.pod \
	SPOPS/SQLInterface.pm \
	SPOPS/Manual/Exceptions.pod \
	SPOPS/Secure.pm \
	SPOPS/DBI/Pg.pm \
	SPOPS/Tool/DBI/FindDefaults.pm \
	SPOPS/GDBM.pm \
	SPOPS/Export/XML.pm \
	SPOPS/DBI.pm \
	SPOPS/Import/DBI/GenericOperation.pm \
	SPOPS/Import/DBI/TableTransform/Sybase.pm \
	SPOPS/Import/DBI/Data.pm \
	SPOPS/Manual/ImportExport.pod \
	SPOPS/Manual/ObjectRules.pod \
	SPOPS/Tie/StrictField.pm \
	SPOPS/Key/UUID.pm \
	SPOPS/Exception/Security.pm \
	SPOPS/Error.pm \
	SPOPS/Import/DBI/TableTransform/InterBase.pm \
	SPOPS/Key/DBI/HandleField.pm \
	SPOPS.pm \
	SPOPS/Manual/Relationships.pod \
	SPOPS/Iterator.pm \
	SPOPS/Tool/DateConvert.pm \
	SPOPS/Export.pm \
	SPOPS/Manual/Datasource.pod \
	SPOPS/Tool/DBI/MaintainLinkedList.pm \
	SPOPS/Key/DBI/Sequence.pm \
	SPOPS/Tool/DBI/Datasource.pm \
	SPOPS/HashFile.pm \
	SPOPS/Manual/Configuration.pod \
	SPOPS/Iterator/DBI.pm \
	SPOPS/Tool/UTFConvert.pm \
	SPOPS/Secure/DBI.pm \
	SPOPS/Tie.pm \
	SPOPS/Manual.pod \
	SPOPS/Initialize.pm \
	SPOPS/DBI/MySQL.pm \
	SPOPS/Tool/DBI/DiscoverField.pm \
	SPOPS/ClassFactory/LDAP.pm \
	SPOPS/Secure/Util.pm \
	SPOPS/DBI/Oracle.pm \
	SPOPS/Import/DBI/TableTransform/Oracle.pm \
	SPOPS/Export/SQL.pm \
	SPOPS/DBI/Sybase.pm \
	SPOPS/Tool/ReadOnly.pm \
	SPOPS/Tool/CreateOnly.pm \
	SPOPS/Import/DBI/Delete.pm \
	SPOPS/Export/DBI/Data.pm \
	SPOPS/Manual/CodeGeneration.pod \
	SPOPS/ClassFactory/DBI.pm \
	SPOPS/Import/DBI/TableTransform/SQLite.pm \
	SPOPS/Secure/Loopback.pm \
	SPOPS/DBI/TypeInfo.pm \
	SPOPS/Exception/LDAP.pm \
	SPOPS/Exception.pm \
	SPOPS/LDAP/MultiDatasource.pm \
	SPOPS/Export/Object.pm \
	SPOPS/LDAP.pm \
	SPOPS/Manual/Security.pod \
	SPOPS/Manual/Cookbook.pod \
	SPOPS/Tool/LDAP/Datasource.pm \
	SPOPS/Exception/DBI.pm \
	SPOPS/Utility.pm \
	SPOPS/Manual/Intro.pod \
	SPOPS/Export/Perl.pm \
	SPOPS/Loopback.pm \
	SPOPS/DBI/SQLite.pm \
	SPOPS/Import/DBI/TableTransform.pm
	$(NOECHO) $(POD2MAN) --section=3 --perm_rw=$(PERM_RW) \
	  SPOPS/Manual/Serialization.pod $(INST_MAN3DIR)/SPOPS::Manual::Serialization.$(MAN3EXT) \
	  SPOPS/Import.pm $(INST_MAN3DIR)/SPOPS::Import.$(MAN3EXT) \
	  SPOPS/Secure/Hierarchy.pm $(INST_MAN3DIR)/SPOPS::Secure::Hierarchy.$(MAN3EXT) \
	  SPOPS/Key/DBI/Pool.pm $(INST_MAN3DIR)/SPOPS::Key::DBI::Pool.$(MAN3EXT) \
	  SPOPS/Iterator/WrapList.pm $(INST_MAN3DIR)/SPOPS::Iterator::WrapList.$(MAN3EXT) \
	  SPOPS/Import/DBI/Update.pm $(INST_MAN3DIR)/SPOPS::Import::DBI::Update.$(MAN3EXT) \
	  SPOPS/Iterator/LDAP.pm $(INST_MAN3DIR)/SPOPS::Iterator::LDAP.$(MAN3EXT) \
	  SPOPS/Import/DBI/Table.pm $(INST_MAN3DIR)/SPOPS::Import::DBI::Table.$(MAN3EXT) \
	  SPOPS/Import/Object.pm $(INST_MAN3DIR)/SPOPS::Import::Object.$(MAN3EXT) \
	  SPOPS/ClassFactory/DefaultBehavior.pm $(INST_MAN3DIR)/SPOPS::ClassFactory::DefaultBehavior.$(MAN3EXT) \
	  SPOPS/Import/DBI/TableTransform/MySQL.pm $(INST_MAN3DIR)/SPOPS::Import::DBI::TableTransform::MySQL.$(MAN3EXT) \
	  SPOPS/DBI/InterBase.pm $(INST_MAN3DIR)/SPOPS::DBI::InterBase.$(MAN3EXT) \
	  SPOPS/ClassFactory.pm $(INST_MAN3DIR)/SPOPS::ClassFactory.$(MAN3EXT) \
	  SPOPS/Key/DBI/Identity.pm $(INST_MAN3DIR)/SPOPS::Key::DBI::Identity.$(MAN3EXT) \
	  SPOPS/Key/Random.pm $(INST_MAN3DIR)/SPOPS::Key::Random.$(MAN3EXT) \
	  SPOPS/Import/DBI/TableTransform/Pg.pm $(INST_MAN3DIR)/SPOPS::Import::DBI::TableTransform::Pg.$(MAN3EXT) \
	  SPOPS/Manual/Object.pod $(INST_MAN3DIR)/SPOPS::Manual::Object.$(MAN3EXT) \
	  SPOPS/SQLInterface.pm $(INST_MAN3DIR)/SPOPS::SQLInterface.$(MAN3EXT) \
	  SPOPS/Manual/Exceptions.pod $(INST_MAN3DIR)/SPOPS::Manual::Exceptions.$(MAN3EXT) \
	  SPOPS/Secure.pm $(INST_MAN3DIR)/SPOPS::Secure.$(MAN3EXT) \
	  SPOPS/DBI/Pg.pm $(INST_MAN3DIR)/SPOPS::DBI::Pg.$(MAN3EXT) \
	  SPOPS/Tool/DBI/FindDefaults.pm $(INST_MAN3DIR)/SPOPS::Tool::DBI::FindDefaults.$(MAN3EXT) \
	  SPOPS/GDBM.pm $(INST_MAN3DIR)/SPOPS::GDBM.$(MAN3EXT) \
	  SPOPS/Export/XML.pm $(INST_MAN3DIR)/SPOPS::Export::XML.$(MAN3EXT) \
	  SPOPS/DBI.pm $(INST_MAN3DIR)/SPOPS::DBI.$(MAN3EXT) \
	  SPOPS/Import/DBI/GenericOperation.pm $(INST_MAN3DIR)/SPOPS::Import::DBI::GenericOperation.$(MAN3EXT) \
	  SPOPS/Import/DBI/TableTransform/Sybase.pm $(INST_MAN3DIR)/SPOPS::Import::DBI::TableTransform::Sybase.$(MAN3EXT) \
	  SPOPS/Import/DBI/Data.pm $(INST_MAN3DIR)/SPOPS::Import::DBI::Data.$(MAN3EXT) \
	  SPOPS/Manual/ImportExport.pod $(INST_MAN3DIR)/SPOPS::Manual::ImportExport.$(MAN3EXT) \
	  SPOPS/Manual/ObjectRules.pod $(INST_MAN3DIR)/SPOPS::Manual::ObjectRules.$(MAN3EXT) \
	  SPOPS/Tie/StrictField.pm $(INST_MAN3DIR)/SPOPS::Tie::StrictField.$(MAN3EXT) \
	  SPOPS/Key/UUID.pm $(INST_MAN3DIR)/SPOPS::Key::UUID.$(MAN3EXT) \
	  SPOPS/Exception/Security.pm $(INST_MAN3DIR)/SPOPS::Exception::Security.$(MAN3EXT) \
	  SPOPS/Error.pm $(INST_MAN3DIR)/SPOPS::Error.$(MAN3EXT) \
	  SPOPS/Import/DBI/TableTransform/InterBase.pm $(INST_MAN3DIR)/SPOPS::Import::DBI::TableTransform::InterBase.$(MAN3EXT) \
	  SPOPS/Key/DBI/HandleField.pm $(INST_MAN3DIR)/SPOPS::Key::DBI::HandleField.$(MAN3EXT) \
	  SPOPS.pm $(INST_MAN3DIR)/SPOPS.$(MAN3EXT) \
	  SPOPS/Manual/Relationships.pod $(INST_MAN3DIR)/SPOPS::Manual::Relationships.$(MAN3EXT) \
	  SPOPS/Iterator.pm $(INST_MAN3DIR)/SPOPS::Iterator.$(MAN3EXT) \
	  SPOPS/Tool/DateConvert.pm $(INST_MAN3DIR)/SPOPS::Tool::DateConvert.$(MAN3EXT) \
	  SPOPS/Export.pm $(INST_MAN3DIR)/SPOPS::Export.$(MAN3EXT) \
	  SPOPS/Manual/Datasource.pod $(INST_MAN3DIR)/SPOPS::Manual::Datasource.$(MAN3EXT) \
	  SPOPS/Tool/DBI/MaintainLinkedList.pm $(INST_MAN3DIR)/SPOPS::Tool::DBI::MaintainLinkedList.$(MAN3EXT) \
	  SPOPS/Key/DBI/Sequence.pm $(INST_MAN3DIR)/SPOPS::Key::DBI::Sequence.$(MAN3EXT) \
	  SPOPS/Tool/DBI/Datasource.pm $(INST_MAN3DIR)/SPOPS::Tool::DBI::Datasource.$(MAN3EXT) \
	  SPOPS/HashFile.pm $(INST_MAN3DIR)/SPOPS::HashFile.$(MAN3EXT) \
	  SPOPS/Manual/Configuration.pod $(INST_MAN3DIR)/SPOPS::Manual::Configuration.$(MAN3EXT) \
	  SPOPS/Iterator/DBI.pm $(INST_MAN3DIR)/SPOPS::Iterator::DBI.$(MAN3EXT) \
	  SPOPS/Tool/UTFConvert.pm $(INST_MAN3DIR)/SPOPS::Tool::UTFConvert.$(MAN3EXT) \
	  SPOPS/Secure/DBI.pm $(INST_MAN3DIR)/SPOPS::Secure::DBI.$(MAN3EXT) \
	  SPOPS/Tie.pm $(INST_MAN3DIR)/SPOPS::Tie.$(MAN3EXT) \
	  SPOPS/Manual.pod $(INST_MAN3DIR)/SPOPS::Manual.$(MAN3EXT) \
	  SPOPS/Initialize.pm $(INST_MAN3DIR)/SPOPS::Initialize.$(MAN3EXT) \
	  SPOPS/DBI/MySQL.pm $(INST_MAN3DIR)/SPOPS::DBI::MySQL.$(MAN3EXT) \
	  SPOPS/Tool/DBI/DiscoverField.pm $(INST_MAN3DIR)/SPOPS::Tool::DBI::DiscoverField.$(MAN3EXT) \
	  SPOPS/ClassFactory/LDAP.pm $(INST_MAN3DIR)/SPOPS::ClassFactory::LDAP.$(MAN3EXT) \
	  SPOPS/Secure/Util.pm $(INST_MAN3DIR)/SPOPS::Secure::Util.$(MAN3EXT) \
	  SPOPS/DBI/Oracle.pm $(INST_MAN3DIR)/SPOPS::DBI::Oracle.$(MAN3EXT) \
	  SPOPS/Import/DBI/TableTransform/Oracle.pm $(INST_MAN3DIR)/SPOPS::Import::DBI::TableTransform::Oracle.$(MAN3EXT) \
	  SPOPS/Export/SQL.pm $(INST_MAN3DIR)/SPOPS::Export::SQL.$(MAN3EXT) \
	  SPOPS/DBI/Sybase.pm $(INST_MAN3DIR)/SPOPS::DBI::Sybase.$(MAN3EXT) \
	  SPOPS/Tool/ReadOnly.pm $(INST_MAN3DIR)/SPOPS::Tool::ReadOnly.$(MAN3EXT) \
	  SPOPS/Tool/CreateOnly.pm $(INST_MAN3DIR)/SPOPS::Tool::CreateOnly.$(MAN3EXT) \
	  SPOPS/Import/DBI/Delete.pm $(INST_MAN3DIR)/SPOPS::Import::DBI::Delete.$(MAN3EXT) \
	  SPOPS/Export/DBI/Data.pm $(INST_MAN3DIR)/SPOPS::Export::DBI::Data.$(MAN3EXT) \
	  SPOPS/Manual/CodeGeneration.pod $(INST_MAN3DIR)/SPOPS::Manual::CodeGeneration.$(MAN3EXT) \
	  SPOPS/ClassFactory/DBI.pm $(INST_MAN3DIR)/SPOPS::ClassFactory::DBI.$(MAN3EXT) \
	  SPOPS/Import/DBI/TableTransform/SQLite.pm $(INST_MAN3DIR)/SPOPS::Import::DBI::TableTransform::SQLite.$(MAN3EXT) \
	  SPOPS/Secure/Loopback.pm $(INST_MAN3DIR)/SPOPS::Secure::Loopback.$(MAN3EXT) \
	  SPOPS/DBI/TypeInfo.pm $(INST_MAN3DIR)/SPOPS::DBI::TypeInfo.$(MAN3EXT) \
	  SPOPS/Exception/LDAP.pm $(INST_MAN3DIR)/SPOPS::Exception::LDAP.$(MAN3EXT) \
	  SPOPS/Exception.pm $(INST_MAN3DIR)/SPOPS::Exception.$(MAN3EXT) \
	  SPOPS/LDAP/MultiDatasource.pm $(INST_MAN3DIR)/SPOPS::LDAP::MultiDatasource.$(MAN3EXT) \
	  SPOPS/Export/Object.pm $(INST_MAN3DIR)/SPOPS::Export::Object.$(MAN3EXT) \
	  SPOPS/LDAP.pm $(INST_MAN3DIR)/SPOPS::LDAP.$(MAN3EXT) \
	  SPOPS/Manual/Security.pod $(INST_MAN3DIR)/SPOPS::Manual::Security.$(MAN3EXT) \
	  SPOPS/Manual/Cookbook.pod $(INST_MAN3DIR)/SPOPS::Manual::Cookbook.$(MAN3EXT) \
	  SPOPS/Tool/LDAP/Datasource.pm $(INST_MAN3DIR)/SPOPS::Tool::LDAP::Datasource.$(MAN3EXT) \
	  SPOPS/Exception/DBI.pm $(INST_MAN3DIR)/SPOPS::Exception::DBI.$(MAN3EXT) \
	  SPOPS/Utility.pm $(INST_MAN3DIR)/SPOPS::Utility.$(MAN3EXT) \
	  SPOPS/Manual/Intro.pod $(INST_MAN3DIR)/SPOPS::Manual::Intro.$(MAN3EXT) \
	  SPOPS/Export/Perl.pm $(INST_MAN3DIR)/SPOPS::Export::Perl.$(MAN3EXT) \
	  SPOPS/Loopback.pm $(INST_MAN3DIR)/SPOPS::Loopback.$(MAN3EXT) \
	  SPOPS/DBI/SQLite.pm $(INST_MAN3DIR)/SPOPS::DBI::SQLite.$(MAN3EXT) \
	  SPOPS/Import/DBI/TableTransform.pm $(INST_MAN3DIR)/SPOPS::Import::DBI::TableTransform.$(MAN3EXT) 




# --- MakeMaker processPL section:


# --- MakeMaker installbin section:


# --- MakeMaker subdirs section:

# none

# --- MakeMaker clean_subdirs section:
clean_subdirs :
	$(NOECHO) $(NOOP)


# --- MakeMaker clean section:

# Delete temporary files but do not touch installed files. We don't delete
# the Makefile here so a later make realclean still has a makefile to use.

clean :: clean_subdirs
	- $(RM_F) \
	  *$(LIB_EXT) core \
	  core.[0-9] $(INST_ARCHAUTODIR)/extralibs.all \
	  core.[0-9][0-9] $(BASEEXT).bso \
	  pm_to_blib.ts core.[0-9][0-9][0-9][0-9] \
	  $(BASEEXT).x $(BOOTSTRAP) \
	  perl$(EXE_EXT) tmon.out \
	  *$(OBJ_EXT) pm_to_blib \
	  $(INST_ARCHAUTODIR)/extralibs.ld blibdirs.ts \
	  core.[0-9][0-9][0-9][0-9][0-9] *perl.core \
	  core.*perl.*.? $(MAKE_APERL_FILE) \
	  perl $(BASEEXT).def \
	  core.[0-9][0-9][0-9] mon.out \
	  lib$(BASEEXT).def perlmain.c \
	  perl.exe so_locations \
	  $(BASEEXT).exp 
	- $(RM_RF) \
	  blib 
	- $(MV) $(FIRST_MAKEFILE) $(MAKEFILE_OLD) $(DEV_NULL)


# --- MakeMaker realclean_subdirs section:
realclean_subdirs :
	$(NOECHO) $(NOOP)


# --- MakeMaker realclean section:
# Delete temporary files (via clean) and also delete dist files
realclean purge ::  clean realclean_subdirs
	- $(RM_F) \
	  $(MAKEFILE_OLD) $(FIRST_MAKEFILE) 
	- $(RM_RF) \
	  $(DISTVNAME) 


# --- MakeMaker metafile section:
metafile : create_distdir
	$(NOECHO) $(ECHO) Generating META.yml
	$(NOECHO) $(ECHO) '--- #YAML:1.0' > META_new.yml
	$(NOECHO) $(ECHO) 'name:               SPOPS' >> META_new.yml
	$(NOECHO) $(ECHO) 'version:            0.87' >> META_new.yml
	$(NOECHO) $(ECHO) 'abstract:           Data abstraction layer used for object persistence and security' >> META_new.yml
	$(NOECHO) $(ECHO) 'author:' >> META_new.yml
	$(NOECHO) $(ECHO) '    - Chris Winters <chris@cwinters.com>' >> META_new.yml
	$(NOECHO) $(ECHO) 'license:            unknown' >> META_new.yml
	$(NOECHO) $(ECHO) 'distribution_type:  module' >> META_new.yml
	$(NOECHO) $(ECHO) 'configure_requires:' >> META_new.yml
	$(NOECHO) $(ECHO) '    ExtUtils::MakeMaker:  0' >> META_new.yml
	$(NOECHO) $(ECHO) 'build_requires:' >> META_new.yml
	$(NOECHO) $(ECHO) '    ExtUtils::MakeMaker:  0' >> META_new.yml
	$(NOECHO) $(ECHO) 'requires:' >> META_new.yml
	$(NOECHO) $(ECHO) '    Carp::Assert:       0.17' >> META_new.yml
	$(NOECHO) $(ECHO) '    Class::Accessor:    0.17' >> META_new.yml
	$(NOECHO) $(ECHO) '    Class::Date:        1' >> META_new.yml
	$(NOECHO) $(ECHO) '    Class::Factory:     1' >> META_new.yml
	$(NOECHO) $(ECHO) '    Class::Fields:      0.14' >> META_new.yml
	$(NOECHO) $(ECHO) '    Class::ISA:         0.32' >> META_new.yml
	$(NOECHO) $(ECHO) '    Data::Dumper:       2' >> META_new.yml
	$(NOECHO) $(ECHO) '    Devel::StackTrace:  0.9' >> META_new.yml
	$(NOECHO) $(ECHO) '    Log::Dispatch:      2' >> META_new.yml
	$(NOECHO) $(ECHO) '    Log::Log4perl:      0.35' >> META_new.yml
	$(NOECHO) $(ECHO) '    Storable:           1' >> META_new.yml
	$(NOECHO) $(ECHO) '    Test::More:         0.41' >> META_new.yml
	$(NOECHO) $(ECHO) '    Time::Piece:        1.07' >> META_new.yml
	$(NOECHO) $(ECHO) 'no_index:' >> META_new.yml
	$(NOECHO) $(ECHO) '    directory:' >> META_new.yml
	$(NOECHO) $(ECHO) '        - t' >> META_new.yml
	$(NOECHO) $(ECHO) '        - inc' >> META_new.yml
	$(NOECHO) $(ECHO) 'generated_by:       ExtUtils::MakeMaker version 6.56' >> META_new.yml
	$(NOECHO) $(ECHO) 'meta-spec:' >> META_new.yml
	$(NOECHO) $(ECHO) '    url:      http://module-build.sourceforge.net/META-spec-v1.4.html' >> META_new.yml
	$(NOECHO) $(ECHO) '    version:  1.4' >> META_new.yml
	-$(NOECHO) $(MV) META_new.yml $(DISTVNAME)/META.yml


# --- MakeMaker signature section:
signature :
	cpansign -s


# --- MakeMaker dist_basics section:
distclean :: realclean distcheck
	$(NOECHO) $(NOOP)

distcheck :
	$(PERLRUN) "-MExtUtils::Manifest=fullcheck" -e fullcheck

skipcheck :
	$(PERLRUN) "-MExtUtils::Manifest=skipcheck" -e skipcheck

manifest :
	$(PERLRUN) "-MExtUtils::Manifest=mkmanifest" -e mkmanifest

veryclean : realclean
	$(RM_F) *~ */*~ *.orig */*.orig *.bak */*.bak *.old */*.old 



# --- MakeMaker dist_core section:

dist : $(DIST_DEFAULT) $(FIRST_MAKEFILE)
	$(NOECHO) $(ABSPERLRUN) -l -e 'print '\''Warning: Makefile possibly out of date with $(VERSION_FROM)'\''' \
	  -e '    if -e '\''$(VERSION_FROM)'\'' and -M '\''$(VERSION_FROM)'\'' < -M '\''$(FIRST_MAKEFILE)'\'';' --

tardist : $(DISTVNAME).tar$(SUFFIX)
	$(NOECHO) $(NOOP)

uutardist : $(DISTVNAME).tar$(SUFFIX)
	uuencode $(DISTVNAME).tar$(SUFFIX) $(DISTVNAME).tar$(SUFFIX) > $(DISTVNAME).tar$(SUFFIX)_uu

$(DISTVNAME).tar$(SUFFIX) : distdir
	$(PREOP)
	$(TO_UNIX)
	$(TAR) $(TARFLAGS) $(DISTVNAME).tar $(DISTVNAME)
	$(RM_RF) $(DISTVNAME)
	$(COMPRESS) $(DISTVNAME).tar
	$(POSTOP)

zipdist : $(DISTVNAME).zip
	$(NOECHO) $(NOOP)

$(DISTVNAME).zip : distdir
	$(PREOP)
	$(ZIP) $(ZIPFLAGS) $(DISTVNAME).zip $(DISTVNAME)
	$(RM_RF) $(DISTVNAME)
	$(POSTOP)

shdist : distdir
	$(PREOP)
	$(SHAR) $(DISTVNAME) > $(DISTVNAME).shar
	$(RM_RF) $(DISTVNAME)
	$(POSTOP)


# --- MakeMaker distdir section:
create_distdir :
	$(RM_RF) $(DISTVNAME)
	$(PERLRUN) "-MExtUtils::Manifest=manicopy,maniread" \
		-e "manicopy(maniread(),'$(DISTVNAME)', '$(DIST_CP)');"

distdir : create_distdir distmeta 
	$(NOECHO) $(NOOP)



# --- MakeMaker dist_test section:
disttest : distdir
	cd $(DISTVNAME) && $(ABSPERLRUN) Makefile.PL 
	cd $(DISTVNAME) && $(MAKE) $(PASTHRU)
	cd $(DISTVNAME) && $(MAKE) test $(PASTHRU)



# --- MakeMaker dist_ci section:

ci :
	$(PERLRUN) "-MExtUtils::Manifest=maniread" \
	  -e "@all = keys %{ maniread() };" \
	  -e "print(qq{Executing $(CI) @all\n}); system(qq{$(CI) @all});" \
	  -e "print(qq{Executing $(RCS_LABEL) ...\n}); system(qq{$(RCS_LABEL) @all});"


# --- MakeMaker distmeta section:
distmeta : create_distdir metafile
	$(NOECHO) cd $(DISTVNAME) && $(ABSPERLRUN) -MExtUtils::Manifest=maniadd -e 'eval { maniadd({q{META.yml} => q{Module meta-data (added by MakeMaker)}}) } ' \
	  -e '    or print "Could not add META.yml to MANIFEST: $${'\''@'\''}\n"' --



# --- MakeMaker distsignature section:
distsignature : create_distdir
	$(NOECHO) cd $(DISTVNAME) && $(ABSPERLRUN) -MExtUtils::Manifest=maniadd -e 'eval { maniadd({q{SIGNATURE} => q{Public-key signature (added by MakeMaker)}}) } ' \
	  -e '    or print "Could not add SIGNATURE to MANIFEST: $${'\''@'\''}\n"' --
	$(NOECHO) cd $(DISTVNAME) && $(TOUCH) SIGNATURE
	cd $(DISTVNAME) && cpansign -s



# --- MakeMaker install section:

install :: pure_install doc_install
	$(NOECHO) $(NOOP)

install_perl :: pure_perl_install doc_perl_install
	$(NOECHO) $(NOOP)

install_site :: pure_site_install doc_site_install
	$(NOECHO) $(NOOP)

install_vendor :: pure_vendor_install doc_vendor_install
	$(NOECHO) $(NOOP)

pure_install :: pure_$(INSTALLDIRS)_install
	$(NOECHO) $(NOOP)

doc_install :: doc_$(INSTALLDIRS)_install
	$(NOECHO) $(NOOP)

pure__install : pure_site_install
	$(NOECHO) $(ECHO) INSTALLDIRS not defined, defaulting to INSTALLDIRS=site

doc__install : doc_site_install
	$(NOECHO) $(ECHO) INSTALLDIRS not defined, defaulting to INSTALLDIRS=site

pure_perl_install :: all
	$(NOECHO) $(MOD_INSTALL) \
		read $(PERL_ARCHLIB)/auto/$(FULLEXT)/.packlist \
		write $(DESTINSTALLARCHLIB)/auto/$(FULLEXT)/.packlist \
		$(INST_LIB) $(DESTINSTALLPRIVLIB) \
		$(INST_ARCHLIB) $(DESTINSTALLARCHLIB) \
		$(INST_BIN) $(DESTINSTALLBIN) \
		$(INST_SCRIPT) $(DESTINSTALLSCRIPT) \
		$(INST_MAN1DIR) $(DESTINSTALLMAN1DIR) \
		$(INST_MAN3DIR) $(DESTINSTALLMAN3DIR)
	$(NOECHO) $(WARN_IF_OLD_PACKLIST) \
		$(SITEARCHEXP)/auto/$(FULLEXT)


pure_site_install :: all
	$(NOECHO) $(MOD_INSTALL) \
		read $(SITEARCHEXP)/auto/$(FULLEXT)/.packlist \
		write $(DESTINSTALLSITEARCH)/auto/$(FULLEXT)/.packlist \
		$(INST_LIB) $(DESTINSTALLSITELIB) \
		$(INST_ARCHLIB) $(DESTINSTALLSITEARCH) \
		$(INST_BIN) $(DESTINSTALLSITEBIN) \
		$(INST_SCRIPT) $(DESTINSTALLSITESCRIPT) \
		$(INST_MAN1DIR) $(DESTINSTALLSITEMAN1DIR) \
		$(INST_MAN3DIR) $(DESTINSTALLSITEMAN3DIR)
	$(NOECHO) $(WARN_IF_OLD_PACKLIST) \
		$(PERL_ARCHLIB)/auto/$(FULLEXT)

pure_vendor_install :: all
	$(NOECHO) $(MOD_INSTALL) \
		read $(VENDORARCHEXP)/auto/$(FULLEXT)/.packlist \
		write $(DESTINSTALLVENDORARCH)/auto/$(FULLEXT)/.packlist \
		$(INST_LIB) $(DESTINSTALLVENDORLIB) \
		$(INST_ARCHLIB) $(DESTINSTALLVENDORARCH) \
		$(INST_BIN) $(DESTINSTALLVENDORBIN) \
		$(INST_SCRIPT) $(DESTINSTALLVENDORSCRIPT) \
		$(INST_MAN1DIR) $(DESTINSTALLVENDORMAN1DIR) \
		$(INST_MAN3DIR) $(DESTINSTALLVENDORMAN3DIR)

doc_perl_install :: all
	$(NOECHO) $(ECHO) Appending installation info to $(DESTINSTALLARCHLIB)/perllocal.pod
	-$(NOECHO) $(MKPATH) $(DESTINSTALLARCHLIB)
	-$(NOECHO) $(DOC_INSTALL) \
		"Module" "$(NAME)" \
		"installed into" "$(INSTALLPRIVLIB)" \
		LINKTYPE "$(LINKTYPE)" \
		VERSION "$(VERSION)" \
		EXE_FILES "$(EXE_FILES)" \
		>> $(DESTINSTALLARCHLIB)/perllocal.pod

doc_site_install :: all
	$(NOECHO) $(ECHO) Appending installation info to $(DESTINSTALLARCHLIB)/perllocal.pod
	-$(NOECHO) $(MKPATH) $(DESTINSTALLARCHLIB)
	-$(NOECHO) $(DOC_INSTALL) \
		"Module" "$(NAME)" \
		"installed into" "$(INSTALLSITELIB)" \
		LINKTYPE "$(LINKTYPE)" \
		VERSION "$(VERSION)" \
		EXE_FILES "$(EXE_FILES)" \
		>> $(DESTINSTALLARCHLIB)/perllocal.pod

doc_vendor_install :: all
	$(NOECHO) $(ECHO) Appending installation info to $(DESTINSTALLARCHLIB)/perllocal.pod
	-$(NOECHO) $(MKPATH) $(DESTINSTALLARCHLIB)
	-$(NOECHO) $(DOC_INSTALL) \
		"Module" "$(NAME)" \
		"installed into" "$(INSTALLVENDORLIB)" \
		LINKTYPE "$(LINKTYPE)" \
		VERSION "$(VERSION)" \
		EXE_FILES "$(EXE_FILES)" \
		>> $(DESTINSTALLARCHLIB)/perllocal.pod


uninstall :: uninstall_from_$(INSTALLDIRS)dirs
	$(NOECHO) $(NOOP)

uninstall_from_perldirs ::
	$(NOECHO) $(UNINSTALL) $(PERL_ARCHLIB)/auto/$(FULLEXT)/.packlist

uninstall_from_sitedirs ::
	$(NOECHO) $(UNINSTALL) $(SITEARCHEXP)/auto/$(FULLEXT)/.packlist

uninstall_from_vendordirs ::
	$(NOECHO) $(UNINSTALL) $(VENDORARCHEXP)/auto/$(FULLEXT)/.packlist


# --- MakeMaker force section:
# Phony target to force checking subdirectories.
FORCE :
	$(NOECHO) $(NOOP)


# --- MakeMaker perldepend section:


# --- MakeMaker makefile section:
# We take a very conservative approach here, but it's worth it.
# We move Makefile to Makefile.old here to avoid gnu make looping.
$(FIRST_MAKEFILE) : Makefile.PL $(CONFIGDEP)
	$(NOECHO) $(ECHO) "Makefile out-of-date with respect to $?"
	$(NOECHO) $(ECHO) "Cleaning current config before rebuilding Makefile..."
	-$(NOECHO) $(RM_F) $(MAKEFILE_OLD)
	-$(NOECHO) $(MV)   $(FIRST_MAKEFILE) $(MAKEFILE_OLD)
	- $(MAKE) $(USEMAKEFILE) $(MAKEFILE_OLD) clean $(DEV_NULL)
	$(PERLRUN) Makefile.PL 
	$(NOECHO) $(ECHO) "==> Your Makefile has been rebuilt. <=="
	$(NOECHO) $(ECHO) "==> Please rerun the $(MAKE) command.  <=="
	$(FALSE)



# --- MakeMaker staticmake section:

# --- MakeMaker makeaperl section ---
MAP_TARGET    = perl
FULLPERL      = /usr/bin/perl

$(MAP_TARGET) :: static $(MAKE_APERL_FILE)
	$(MAKE) $(USEMAKEFILE) $(MAKE_APERL_FILE) $@

$(MAKE_APERL_FILE) : $(FIRST_MAKEFILE) pm_to_blib
	$(NOECHO) $(ECHO) Writing \"$(MAKE_APERL_FILE)\" for this $(MAP_TARGET)
	$(NOECHO) $(PERLRUNINST) \
		Makefile.PL DIR= \
		MAKEFILE=$(MAKE_APERL_FILE) LINKTYPE=static \
		MAKEAPERL=1 NORECURS=1 CCCDLFLAGS=


# --- MakeMaker test section:

TEST_VERBOSE=0
TEST_TYPE=test_$(LINKTYPE)
TEST_FILE = test.pl
TEST_FILES = t/*.t
TESTDB_SW = -d

testdb :: testdb_$(LINKTYPE)

test :: $(TEST_TYPE) subdirs-test

subdirs-test ::
	$(NOECHO) $(NOOP)


test_dynamic :: pure_all
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) "-MExtUtils::Command::MM" "-e" "test_harness($(TEST_VERBOSE), '$(INST_LIB)', '$(INST_ARCHLIB)')" $(TEST_FILES)

testdb_dynamic :: pure_all
	PERL_DL_NONLAZY=1 $(FULLPERLRUN) $(TESTDB_SW) "-I$(INST_LIB)" "-I$(INST_ARCHLIB)" $(TEST_FILE)

test_ : test_dynamic

test_static :: test_dynamic
testdb_static :: testdb_dynamic


# --- MakeMaker ppd section:
# Creates a PPD (Perl Package Description) for a binary distribution.
ppd :
	$(NOECHO) $(ECHO) '<SOFTPKG NAME="$(DISTNAME)" VERSION="0.87">' > $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '    <ABSTRACT>Data abstraction layer used for object persistence and security</ABSTRACT>' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '    <AUTHOR>Chris Winters &lt;chris@cwinters.com&gt;</AUTHOR>' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '    <IMPLEMENTATION>' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Carp::Assert" VERSION="0.17" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Class::Accessor" VERSION="0.17" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Class::Date" VERSION="1" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Class::Factory" VERSION="1" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Class::Fields" VERSION="0.14" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Class::ISA" VERSION="0.32" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Data::Dumper" VERSION="2" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Devel::StackTrace" VERSION="0.9" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Log::Dispatch" VERSION="2" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Log::Log4perl" VERSION="0.35" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Storable::" VERSION="1" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Test::More" VERSION="0.41" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <REQUIRE NAME="Time::Piece" VERSION="1.07" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <ARCHITECTURE NAME="i486-linux-gnu-thread-multi-5.10" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '        <CODEBASE HREF="" />' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '    </IMPLEMENTATION>' >> $(DISTNAME).ppd
	$(NOECHO) $(ECHO) '</SOFTPKG>' >> $(DISTNAME).ppd


# --- MakeMaker pm_to_blib section:

pm_to_blib : $(FIRST_MAKEFILE) $(TO_INST_PM)
	$(NOECHO) $(ABSPERLRUN) -MExtUtils::Install -e 'pm_to_blib({@ARGV}, '\''$(INST_LIB)/auto'\'', q[$(PM_FILTER)], '\''$(PERM_DIR)'\'')' -- \
	  SPOPS/Manual/Serialization.pod $(INST_LIB)/SPOPS/Manual/Serialization.pod \
	  SPOPS/Import.pm $(INST_LIB)/SPOPS/Import.pm \
	  SPOPS/Secure/Hierarchy.pm $(INST_LIB)/SPOPS/Secure/Hierarchy.pm \
	  SPOPS/Key/DBI/Pool.pm $(INST_LIB)/SPOPS/Key/DBI/Pool.pm \
	  SPOPS/Iterator/WrapList.pm $(INST_LIB)/SPOPS/Iterator/WrapList.pm \
	  SPOPS/Import/DBI/Update.pm $(INST_LIB)/SPOPS/Import/DBI/Update.pm \
	  SPOPS/Iterator/LDAP.pm $(INST_LIB)/SPOPS/Iterator/LDAP.pm \
	  SPOPS/Import/DBI/Table.pm $(INST_LIB)/SPOPS/Import/DBI/Table.pm \
	  SPOPS/Import/Object.pm $(INST_LIB)/SPOPS/Import/Object.pm \
	  SPOPS/ClassFactory/DefaultBehavior.pm $(INST_LIB)/SPOPS/ClassFactory/DefaultBehavior.pm \
	  SPOPS/Import/DBI/TableTransform/MySQL.pm $(INST_LIB)/SPOPS/Import/DBI/TableTransform/MySQL.pm \
	  SPOPS/DBI/InterBase.pm $(INST_LIB)/SPOPS/DBI/InterBase.pm \
	  SPOPS/ClassFactory.pm $(INST_LIB)/SPOPS/ClassFactory.pm \
	  SPOPS/Key/DBI/Identity.pm $(INST_LIB)/SPOPS/Key/DBI/Identity.pm \
	  SPOPS/Key/Random.pm $(INST_LIB)/SPOPS/Key/Random.pm \
	  SPOPS/Import/DBI/TableTransform/Pg.pm $(INST_LIB)/SPOPS/Import/DBI/TableTransform/Pg.pm \
	  SPOPS/Manual/Object.pod $(INST_LIB)/SPOPS/Manual/Object.pod \
	  SPOPS/SQLInterface.pm $(INST_LIB)/SPOPS/SQLInterface.pm \
	  SPOPS/Manual/Exceptions.pod $(INST_LIB)/SPOPS/Manual/Exceptions.pod \
	  SPOPS/Secure.pm $(INST_LIB)/SPOPS/Secure.pm \
	  SPOPS/DBI/Pg.pm $(INST_LIB)/SPOPS/DBI/Pg.pm \
	  SPOPS/Tool/DBI/FindDefaults.pm $(INST_LIB)/SPOPS/Tool/DBI/FindDefaults.pm \
	  SPOPS/GDBM.pm $(INST_LIB)/SPOPS/GDBM.pm \
	  SPOPS/Export/XML.pm $(INST_LIB)/SPOPS/Export/XML.pm \
	  SPOPS/DBI.pm $(INST_LIB)/SPOPS/DBI.pm \
	  SPOPS/Import/DBI/GenericOperation.pm $(INST_LIB)/SPOPS/Import/DBI/GenericOperation.pm \
	  SPOPS/Import/DBI/TableTransform/Sybase.pm $(INST_LIB)/SPOPS/Import/DBI/TableTransform/Sybase.pm \
	  SPOPS/Import/DBI/Data.pm $(INST_LIB)/SPOPS/Import/DBI/Data.pm \
	  SPOPS/Manual/ImportExport.pod $(INST_LIB)/SPOPS/Manual/ImportExport.pod \
	  SPOPS/Manual/ObjectRules.pod $(INST_LIB)/SPOPS/Manual/ObjectRules.pod \
	  SPOPS/Tie/StrictField.pm $(INST_LIB)/SPOPS/Tie/StrictField.pm \
	  SPOPS/Key/UUID.pm $(INST_LIB)/SPOPS/Key/UUID.pm \
	  SPOPS/Exception/Security.pm $(INST_LIB)/SPOPS/Exception/Security.pm \
	  SPOPS/Error.pm $(INST_LIB)/SPOPS/Error.pm \
	  SPOPS/Import/DBI/TableTransform/InterBase.pm $(INST_LIB)/SPOPS/Import/DBI/TableTransform/InterBase.pm \
	  SPOPS/Key/DBI/HandleField.pm $(INST_LIB)/SPOPS/Key/DBI/HandleField.pm \
	  SPOPS.pm $(INST_LIB)/SPOPS.pm \
	  SPOPS/Manual/Relationships.pod $(INST_LIB)/SPOPS/Manual/Relationships.pod \
	  SPOPS/Iterator.pm $(INST_LIB)/SPOPS/Iterator.pm \
	  SPOPS/Tool/DateConvert.pm $(INST_LIB)/SPOPS/Tool/DateConvert.pm \
	  SPOPS/Export.pm $(INST_LIB)/SPOPS/Export.pm \
	  SPOPS/Manual/Datasource.pod $(INST_LIB)/SPOPS/Manual/Datasource.pod \
	  SPOPS/Tool/DBI/MaintainLinkedList.pm $(INST_LIB)/SPOPS/Tool/DBI/MaintainLinkedList.pm \
	  SPOPS/Key/DBI/Sequence.pm $(INST_LIB)/SPOPS/Key/DBI/Sequence.pm \
	  SPOPS/Tool/DBI/Datasource.pm $(INST_LIB)/SPOPS/Tool/DBI/Datasource.pm \
	  SPOPS/HashFile.pm $(INST_LIB)/SPOPS/HashFile.pm \
	  SPOPS/Manual/Configuration.pod $(INST_LIB)/SPOPS/Manual/Configuration.pod \
	  SPOPS/Iterator/DBI.pm $(INST_LIB)/SPOPS/Iterator/DBI.pm \
	  SPOPS/Tool/UTFConvert.pm $(INST_LIB)/SPOPS/Tool/UTFConvert.pm \
	  SPOPS/Secure/DBI.pm $(INST_LIB)/SPOPS/Secure/DBI.pm \
	  SPOPS/Tie.pm $(INST_LIB)/SPOPS/Tie.pm \
	  SPOPS/Manual.pod $(INST_LIB)/SPOPS/Manual.pod \
	  SPOPS/Initialize.pm $(INST_LIB)/SPOPS/Initialize.pm \
	  SPOPS/DBI/MySQL.pm $(INST_LIB)/SPOPS/DBI/MySQL.pm \
	  SPOPS/Tool/DBI/DiscoverField.pm $(INST_LIB)/SPOPS/Tool/DBI/DiscoverField.pm \
	  SPOPS/ClassFactory/LDAP.pm $(INST_LIB)/SPOPS/ClassFactory/LDAP.pm \
	  SPOPS/Secure/Util.pm $(INST_LIB)/SPOPS/Secure/Util.pm \
	  SPOPS/DBI/Oracle.pm $(INST_LIB)/SPOPS/DBI/Oracle.pm \
	  SPOPS/Import/DBI/TableTransform/Oracle.pm $(INST_LIB)/SPOPS/Import/DBI/TableTransform/Oracle.pm \
	  SPOPS/Export/SQL.pm $(INST_LIB)/SPOPS/Export/SQL.pm \
	  SPOPS/DBI/Sybase.pm $(INST_LIB)/SPOPS/DBI/Sybase.pm \
	  SPOPS/Tool/ReadOnly.pm $(INST_LIB)/SPOPS/Tool/ReadOnly.pm \
	  SPOPS/Tool/CreateOnly.pm $(INST_LIB)/SPOPS/Tool/CreateOnly.pm \
	  SPOPS/Import/DBI/Delete.pm $(INST_LIB)/SPOPS/Import/DBI/Delete.pm \
	  SPOPS/Export/DBI/Data.pm $(INST_LIB)/SPOPS/Export/DBI/Data.pm \
	  SPOPS/Manual/CodeGeneration.pod $(INST_LIB)/SPOPS/Manual/CodeGeneration.pod \
	  SPOPS/ClassFactory/DBI.pm $(INST_LIB)/SPOPS/ClassFactory/DBI.pm \
	  SPOPS/Import/DBI/TableTransform/SQLite.pm $(INST_LIB)/SPOPS/Import/DBI/TableTransform/SQLite.pm \
	  SPOPS/Secure/Loopback.pm $(INST_LIB)/SPOPS/Secure/Loopback.pm \
	  SPOPS/DBI/TypeInfo.pm $(INST_LIB)/SPOPS/DBI/TypeInfo.pm \
	  SPOPS/Exception/LDAP.pm $(INST_LIB)/SPOPS/Exception/LDAP.pm \
	  SPOPS/Exception.pm $(INST_LIB)/SPOPS/Exception.pm \
	  SPOPS/LDAP/MultiDatasource.pm $(INST_LIB)/SPOPS/LDAP/MultiDatasource.pm \
	  SPOPS/Export/Object.pm $(INST_LIB)/SPOPS/Export/Object.pm \
	  SPOPS/LDAP.pm $(INST_LIB)/SPOPS/LDAP.pm \
	  SPOPS/Manual/Security.pod $(INST_LIB)/SPOPS/Manual/Security.pod \
	  SPOPS/Manual/Cookbook.pod $(INST_LIB)/SPOPS/Manual/Cookbook.pod \
	  SPOPS/Tool/LDAP/Datasource.pm $(INST_LIB)/SPOPS/Tool/LDAP/Datasource.pm \
	  SPOPS/Exception/DBI.pm $(INST_LIB)/SPOPS/Exception/DBI.pm \
	  SPOPS/Utility.pm $(INST_LIB)/SPOPS/Utility.pm \
	  SPOPS/Manual/Intro.pod $(INST_LIB)/SPOPS/Manual/Intro.pod \
	  SPOPS/Export/Perl.pm $(INST_LIB)/SPOPS/Export/Perl.pm \
	  SPOPS/Loopback.pm $(INST_LIB)/SPOPS/Loopback.pm \
	  SPOPS/DBI/SQLite.pm $(INST_LIB)/SPOPS/DBI/SQLite.pm \
	  SPOPS/Import/DBI/TableTransform.pm $(INST_LIB)/SPOPS/Import/DBI/TableTransform.pm 
	$(NOECHO) $(TOUCH) pm_to_blib


# --- MakeMaker selfdocument section:


# --- MakeMaker postamble section:


# End.
