# $Id: Makefile.PL,v 1.11 2000/11/18 21:06:28 cwinters Exp $

use ExtUtils::MakeMaker;

# Ask the user for testing configuration information; save it in a
# file and remove it if asked (since it will contain password info)

my $EXTRA_INFO = '';

sub _get_response {
 my $msg     = shift;
 my $default = shift;
 print $msg;
 $default = join( ', ', @{ $default } ) if ( ref $default eq 'ARRAY' );
 my $show_default = $default || 'no default';
 print " <$show_default> ";
 my $response = <STDIN>;
 chomp $response;
 $response = $default if ( $response =~ /^\s*$/ );
 return $response;
}

sub _set_sybase_env {
 my $syb_set = _get_response( "Current value of SYBASE environment variable: $ENV{SYBASE}. " . 
                              'Is this correct? (Y/n)', 'Y' );
 if ( $syb_set !~ /\s*y\s*/i ) {
   my $syb_env = _get_response( 'Enter a value for the SYBASE environment variable', '/opt/sybase' );
   $EXTRA_INFO .= "ENV_SYBASE:     $syb_env\n";
 }
 print "\n";
}

 # File we write the configuration info to
 my $config_file = 'spops_test.conf';

 # Available SPOPS DBI drivers (when we start testing with more databases, 
 # we add them here)
 my %dbd_drivers = ( mysql => 1, ASAny => 1, Sybase => \&_set_sybase_env );

 # Find out about a DBI test
 my ( $dbi_test, $gdbm_test, $dbi_driver, $dbi_dsn, $dbi_user, $dbi_password, $remove_conf );
 eval { require DBI };
 if ( $@ ) {
   print "You don't appear to have DBI installed; skipping DBI tests.";
   $dbi_test = 'n';
 }
 else {
   $dbi_test  = lc _get_response( "Would you like to run tests using DBI? (Y/n)\n", 'Y' );
   $dbi_test  =~ s/^\s*(\w)\s*$/$1/;
   $dbi_test  = ( $dbi_test eq 'y' ) ? 'y' : 'n';
   print "\n";
   if ( $dbi_test eq 'y' ) {
     my @dbd_available = ();
     foreach my $dbd ( keys %dbd_drivers ) {
       eval "require DBD::$dbd";
       push @dbd_available, $dbd   unless ( $@ );
     }
     my $dbd_string = join ', ', sort @dbd_available;
     $dbi_driver = _get_response( "Choose a DBI driver to test.\n" .
                                  "(Available in SPOPS and on your system: $dbd_string)\n" );
     unless ( $dbi_driver ) {
       print "Skipping DBI tests since no driver specified.\n";
       $dbi_test = 'n';
       goto DBI_DONE;
     }
     
     # Use this to ensure the environment is setup properly for the DBD driver to run
     $dbd_drivers{ $dbi_driver }->()  if ( ref $dbd_drivers{ $dbi_driver } eq 'CODE' );
     print "\n";

     $dbi_dsn = _get_response( "Please enter the tail end of the DSN to use for the driver you chose\n" .
                               "(DBI:$dbi_driver will be prepended unless you specify a full DSN)\n",
                               $ENV{DBI_DSN} );
     unless ( $dbi_dsn ) {
       print "Skipping DBI tests since DSN not fully specified\n";
       $dbi_test = 'n';
       goto DBI_DONE;
     }
     print "\n";
     $dbi_dsn = "DBI:$dbi_driver:$dbi_dsn" if ( $dbi_dsn !~ /^dbi/i );
     $dbi_user = _get_response( "Please enter a username to connect to the data source specified.\n" .
                                "This user should be able to create and remove tables in the database.\n",
                                $ENV{DBI_USER} );
     $dbi_password = _get_response( "Please enter the password for user ($dbi_user)\n", $ENV{DBI_PASSWORD} );
     print "\n";
     print "Please note: you might want to remove the file \n",
           "'$config_file' after the tests have run.\n\n";
   }
 }

DBI_DONE:

 # Find out about a GDBM test
 eval { require GDBM_File };
 if ( $@ ) {
  print "You don't appear to have GDBM_File installed, skipping GDBM tests.";
  $gdbm_test = 'n';
 } 
 else {
   $gdbm_test = lc _get_response( "Would you like to run tests using GDBM? (Y/n)\n", 'Y' );
   $gdbm_test =~ s/^\s*(\w)\s*$/$1/;
   $gdbm_test = ( $gdbm_test eq 'y' ) ? 'y' : 'n';
 }
 print "\n";

 my $write_config = 'y';
 if ( $dbi_test eq 'n' and $gdbm_test eq 'n' ) {
   print "Only the HashFile test will be run.\n";
   $write_config = 'n';
 }

 if ( $write_config eq 'y' ) {
   open( CONF, "> $config_file" ) || die "Cannot open $config_file for writing! Error: $!";
   print CONF <<CONFIG;
DBI_test:     $dbi_test
DBI_driver:   $dbi_driver
DBI_dsn:      $dbi_dsn
DBI_user:     $dbi_user
DBI_password: $dbi_password
GDBM_test:    $gdbm_test
$EXTRA_INFO
CONFIG
 }

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'SPOPS',
    'VERSION_FROM' => 'VERSION',
    'AUTHOR' => 'Chris Winters <chris@cwinter.com>',
    'ABSTRACT' => 'Data abstraction layer used for object persistence and security',
    'PREREQ_PM' => { 'Date::Format' => 2.09,
                     'Data::Dumper' => 0,
                     'Date::Calc'   => 4.3 },
);
