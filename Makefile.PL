# $Id: Makefile.PL,v 1.12 2001/11/06 23:50:59 lachoy Exp $

use strict;
use ExtUtils::MakeMaker;

# Ask the user for testing configuration information; save it in a
# file and remove it if asked (since it will contain password info)

my ( $EXTRA_INFO );

 # Available SPOPS DBI drivers (when we start testing with more
 # databases, we add them here)

my %SUPPORTED_DBD_DRIVERS = ( mysql  => 1,
                              Pg     => 1,
                              ASAny  => 1,
                              ODBC   => 1,
                              Sybase => \&_set_sybase_env );

 # File we write the configuration info to

my $CONFIG_FILE = 'spops_test.conf';

{
    my %OPT = map { $_ => 1 } @ARGV;
    foreach my $opt_key ( keys %OPT ) {
        if ( $OPT{ $opt_key } =~ /^\w+=(.*)$/ ) {
            $OPT{ $opt_key } = $1;
        }
    }

    # If the config file already exists, then skip all this goop and write out the Makefile

    if ( -f $CONFIG_FILE ) {
        my $use_existing = ( $OPT{AUTO} )
                           ? 'y' 
                           : lc get_response( 'You appear to have an existing configuration ' .
                                              'file. Re-use it? (Y/n)', 'Y' );
        if ( $use_existing eq 'y' ) {
            write_makefile();
            exit(0);
        }
    }

    my ( $dbi_test, $dbi_driver, $dbi_dsn, $dbi_user, $dbi_password ) = check_dbi();
    my ( $ldap_test, $ldap_host, $ldap_port, $ldap_base_dn, $ldap_bind_dn, $ldap_password ) = check_ldap();
    my ( $gdbm_test ) = check_gdbm();     

    if ( $dbi_test eq 'n' and $ldap_test eq 'n' and $gdbm_test eq 'n' ) {
        print "Only the HashFile test will be run.\n";
        eval { unlink( $CONFIG_FILE ) };
    }
    else {
        open( CONF, "> $CONFIG_FILE" ) || die "Cannot open $CONFIG_FILE for writing! Error: $!";
        print CONF <<CONFIG;
DBI_test:      $dbi_test
DBI_driver:    $dbi_driver
DBI_dsn:       $dbi_dsn
DBI_user:      $dbi_user
DBI_password:  $dbi_password
LDAP_test:     $ldap_test
LDAP_host:     $ldap_host
LDAP_port:     $ldap_port
LDAP_base_dn:  $ldap_base_dn
LDAP_bind_dn:  $ldap_bind_dn
LDAP_bind_password: $ldap_password
GDBM_test:     $gdbm_test
$EXTRA_INFO
CONFIG
    }

    write_makefile();
}



# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

sub write_makefile {
  WriteMakefile(
    'NAME'         => 'SPOPS',
    'VERSION_FROM' => 'SPOPS.pm',
    'AUTHOR'       => 'Chris Winters <chris@cwinters.com>',
    'ABSTRACT'     => 'Data abstraction layer used for object persistence and security',
    'PREREQ_PM'    => { 'Storable'     => 1.00,
                        'Class::ISA'   => undef,
                        'Test::More'   => 0.07,
                        'Data::Dumper' => undef,
                        'Class::Date'  => 1.00 } );
}


# Generic routine to read a response from the command-line (defaults,
# etc.) Note that return value has whitespace at the end/beginning of
# the routine trimmed.

sub get_response {
    my ( $msg, $default ) = @_;
    print $msg;
    $default = join( ', ', @{ $default } ) if ( ref $default eq 'ARRAY' );
    my $show_default = $default || 'no default';
    print " <$show_default> ";
    my $response = <STDIN>;
    chomp $response;
    $response = $default if ( $response =~ /^\s*$/ );
    $response =~ s/^\s+//;
    $response =~ s/\s+$//;
    return $response;
}


# Set the sybase environment as necessary

sub set_sybase_env {
    my $syb_set = lc get_response( "Current value of SYBASE environment variable: $ENV{SYBASE}. " . 
                                   'Is this correct? (Y/n)', 'Y' );
    if ( $syb_set eq 'y' ) {
        my $syb_env = get_response( 'Enter a value for the SYBASE environment variable', '/opt/sybase' );
        $EXTRA_INFO .= "ENV_SYBASE:     $syb_env\n";
    }
    print "\n";
}


# Find out about a DBI test

sub check_dbi {
    my ( $dbi_test, $dbi_driver, $dbi_dsn, $dbi_user, $dbi_pass );
    eval { require DBI };
    if ( $@ ) {
        print "You don't appear to have DBI installed; skipping DBI tests.\n";
        return ( 'n' );
    }
    $dbi_test  = lc get_response( "Would you like to run tests using DBI? (Y/n)\n", 'Y' );
    if ( $dbi_test ne 'y' ) {
        return ( 'n' );
    }
    print "\n";
    my @dbd_available = ();
    foreach my $dbd ( keys %SUPPORTED_DBD_DRIVERS ) {
        eval "require DBD::$dbd";
        push @dbd_available, $dbd   unless ( $@ );
    }
    my $dbd_string = join ', ', sort @dbd_available;
    $dbi_driver = get_response( "Choose a DBI driver to test.\n" .
                                "(Available in SPOPS and on your system: $dbd_string)\n" );
    unless ( $dbi_driver ) {
        print "Skipping DBI tests since no driver specified.\n";
        return ( 'n' );
    }

    # Use this to ensure the environment is setup properly for the
    # DBD driver to run

    if ( ref $SUPPORTED_DBD_DRIVERS{ $dbi_driver } eq 'CODE' ) {
        $SUPPORTED_DBD_DRIVERS{ $dbi_driver }->();
    }
    print "\n";

    my ( $odbc_driver );
    if ( $dbi_driver eq 'ODBC' ) {
        print "You've chosen ODBC as your DBD. However, SPOPS needs to know ",
              "what type of database is working behind the ODBC driver.\n";
        $odbc_driver = get_response( "Choose a database behind the scenes (MySQL, Pg, Sybase)\n" .
                                     "(MS SQL users should enter 'Sybase')", 'Sybase' );
    }
    print "\n";

    $dbi_dsn = get_response( "Please enter the tail end of the DSN to use for the driver you chose\n" .
                             "('DBI:$dbi_driver:' will be prepended unless you specify a full DSN)\n",
                             $ENV{DBI_DSN} );
    unless ( $dbi_dsn ) {
        print "Skipping DBI tests since DSN not fully specified\n";
        return ( 'n' );
    }
    print "\n";
    $dbi_dsn = "DBI:$dbi_driver:$dbi_dsn" if ( $dbi_dsn !~ /^dbi/i );
    $dbi_user = get_response( "Please enter a username to connect to the data source specified.\n" .
                              "This user should be able to create and remove tables in the database.\n",
                              $ENV{DBI_USER} );
    $dbi_pass = get_response( "Please enter the password for user ($dbi_user)\n", $ENV{DBI_PASSWORD} );
    print "\n";
    print "Please note: you might want to remove the file \n",
          "'$CONFIG_FILE' after the tests have run since it \n",
          "contains user/password information.\n\n";

    $dbi_driver = $odbc_driver if ( $odbc_driver );
    return ( 'y', $dbi_driver, $dbi_dsn, $dbi_user, $dbi_pass );
}


# Find out whether to run LDAP test

sub check_ldap {
    my ( $ldap_test, $ldap_host, $ldap_port, $ldap_base_dn, $ldap_bind_dn, $ldap_password );
    eval { require Net::LDAP };
    if ( $@ ) {
        print "You don't appear to have Net::LDAP installed; skipping LDAP tests.\n";
        return ( 'n' );
    }
    $ldap_test = lc get_response( "Would you like to run tests using LDAP? (Y/n)\n", 'Y' );
    if ( $ldap_test ne 'y' ) {
        return ( 'n' );
    }
    print "\n";
    print "We need some information about your LDAP setup to run tests:\n";
    $ldap_host = lc get_response( "  Host? (localhost)    ", 'localhost' );
    $ldap_port = lc get_response( "  Port? (389)          ", 389 );
    $ldap_base_dn = get_response( "  Base DN?             " );
    print "I will create an OU and entries under ($ldap_base_dn) for testing,\n",
          "and then remove the OU when I'm finished.\n";
    $ldap_bind_dn = get_response( "  Bind DN? (anonymous) ", 'anonymous bind' );
    $ldap_bind_dn = ( $ldap_bind_dn eq 'anonymous bind' ) ? '' : $ldap_bind_dn;
    if ( $ldap_bind_dn ) {
        $ldap_password = get_response( "  Bind password?       " );
    }
    return ( $ldap_test, $ldap_host, $ldap_port, $ldap_base_dn, $ldap_bind_dn, $ldap_password );
}


# Find out about a GDBM test

sub check_gdbm {
    eval { require GDBM_File };
    if ( $@ ) {
        print "You don't appear to have GDBM_File installed, skipping GDBM tests.\n";
        return ( 'n' );
    } 
    my $gdbm_test = lc get_response( "Would you like to run tests using GDBM? (Y/n)\n", 'Y' );
    print "\n";
    return ( $gdbm_test );
}
