# $Id: dbi.t,v 1.3 2001/02/25 19:10:34 lachoy Exp $

# Note that this is a good way to see if certain databases support the
# type checking methods of the DBI -- in fact, we might want to add
# some date/datetime items in the table as well to see what happens

use lib qw( t/ );
use DBITest;
use Data::Dumper qw( Dumper );

sub _sybase_setup { 
 my $config = shift;
 $ENV{SYBASE} = $config->{ENV_SYBASE} if ( $config->{ENV_SYBASE} ); 
 use SPOPS::DBI::Sybase;
 unshift @DBITest::ISA, 'SPOPS::DBI::Sybase';
}

do "t/config.pl";
my $config = _read_config_file();
$config->{DBI_test} ||= 'n';
if ( $config->{DBI_test} ne 'y' ) {
  print "1..0\n";
  print "Skipping test on this platform\n";
  exit;
}



my $num_tests = 16;
print "1..$num_tests\n";

# If the driver is *known* not to process {TYPE} info, we tell the test
# class to include the type info in its configuration

my %no_TYPE_dbd_drivers = ();
my $driver_name = $config->{DBI_driver};
if ( $driver_name eq 'ASAny' ) {
  eval "require DBD::ASAny";
  if ( $@ ) {
    print "1..0\n";
    print "Cannot require DBD::ASAny module. Do you have it installed? (Error: $@)\n";
    exit;
  }

  # get around annoying (!) -w declaration that var is only used once...

  my $dumb_ver = $DBD::ASAny::VERSION; 
  if ( $DBD::ASAny::VERSION < 1.09 ) {
    print "1..0\n";
    print "-- The DBD::ASAny driver prior version 1.09 did not support the {TYPE} attribute\n",
          "Please upgrade the driver before using SPOPS. If you do not do so, SPOPS will not\n",
          "work properly!\n";
    print "Skipping text on this platform\n";
    exit;
  }
}

if ( $no_TYPE_dbd_drivers{ $driver_name } ) {
  warn "\nDBD Driver $driver_name does not support {TYPE} information\n",
       "Installing manual types for test.\n";
  DBITest->_assign_types();
}

my %dbd_driver_actions = (
 Sybase =>  \&_sybase_setup,
);

$dbd_driver_actions{ $driver_name }->( $config ) if ( ref $dbd_driver_actions{ $driver_name } eq 'CODE' );

# First connect to the database

my $db = eval { DBI->connect( $config->{DBI_dsn}, $config->{DBI_user}, $config->{DBI_password},
                              { AutoCommit => 1, PrintError => 0, ChopBlanks => 1 } ) 
                  || die $DBI::errstr };
if ( $@ ) {
  warn "Cannot connect to database using parameters given. Please edit 'spops_test.conf'\n",
       "with correct information if you'd like to perform the tests.\n";
  print "not ok 1\n";
  exit;
}
print "ok 1\n";
$db->{RaiseError} = 1;
my $table_name = 'spops_test';

# This is standard, plain vanilla SQL; I don't want to have to do a
# vendor-specific testing suite (argh!) -- although we could just
# create sql files and read them in. Adapting the
# OpenInteract::SQLInstall for strict SPOPS use might be
# interesting...

my $table_sql = qq/
  CREATE TABLE $table_name (
    spops_id    int not null primary key,
    spops_name  char(20) null,
    spops_goop  char(20) not null,
    spops_num   int default 2
  )
/;

{
 my ( $sth );
 eval { 
   $sth = $db->prepare( $table_sql );
   $sth->execute;
 };
 if ( $@ ) {
   print "not ok 2\n";
   warn "Halting DBI tests -- Cannot create table in DBI database! Error: $@\n";
   exit;
 }
 print "ok 2\n";
} 

# Create an object
{
 my $obj = eval { DBITest->new( { spops_name => 'MyProject', spops_goop => 'oopie doop',
                                  spops_num => 241, spops_id => 42 } ) };
 if ( $@ ) {
   warn "Error creating object: $@\n";
   print "not " ;
 }
 print "ok 3\n";

 # Save the object
 eval { $obj->save( { is_add => 1, db => $db, skip_cache => 1 } ) };
 if ( $@ ) {
   warn "Error saving object: $@\n", Dumper( SPOPS::Error->get ), "\n";
   print "not ";
 }
 print "ok 4\n";
}

# Fetch an object, then update it
{
 my $obj = eval { DBITest->fetch( 42, { db => $db, skip_cache => 1 } ) };
 if ( $@ ) {
   warn "Cannot fetch object: $@\n", Dumper( SPOPS::Error->get ), "\n";
   print "not " ;
 }
 print "ok 5\n";

 print "not " if ( $obj->{spops_name} ne 'MyProject' );
 print "ok 6\n";

 $obj->{spops_name} = 'TheirProject';
 $obj->{spops_goop} = 'over there';
 eval { $obj->save( { db => $db, skip_cache => 1 } ) };
 if ( $@ ) {
   warn "Cannot update object: $@\n", Dumper( SPOPS::Error->get ), "\n";
   print "not " ;
 }
 print "ok 7\n";

 my $new_obj = eval { DBITest->fetch( 42, { db => $db, skip_cache => 1 } ) };
 if ( $new_obj->{spops_name} ne $obj->{spops_name} ) {
   print "not ";
 }
 print "ok 8\n";
}

# Fetch an object then clone it and save it
{
 my $obj     = eval { DBITest->fetch( 42, { db => $db, skip_cache => 1 } ) };
 my $new_obj = eval { $obj->clone( { spops_name => 'YourProject', spops_goop => 'this n that',
                                     spops_id => 1792 } ) };
 print "not " if ( $@ );
 print "ok 9\n";

 print "not " if ( $new_obj->{spops_name} eq $obj->{spops_name} );
 print "ok 10\n";

 eval { $new_obj->save( { is_add => 1, db => $db, skip_cache => 1 } ) };
 if ( $@ ) {
   warn "Cannot save object: $@\n", Dumper( SPOPS::Error->get ), "\n";
   print "not " ;
 }
 print "ok 11\n";
} 

# Fetch the three objects in the db and be sure we got them all
{
 my $obj_list = eval { DBITest->fetch_group( { db => $db, skip_cache => 1 } ) };
 if ( $@ ) {
   warn "Cannot retrieve objects: $@\n", Dumper( SPOPS::Error->get ), "\n";
   print "not " ;
 }
 print "ok 12\n";

 print "not " unless ( ref $obj_list eq 'ARRAY' );
 print "ok 13\n";

 if ( scalar @{ $obj_list } != 2 ) {
   warn " Number of items in list is ", scalar @{ $obj_list }, "\n";
   print "not ";
 }
 print "ok 14\n";
}

# Create another object, but this time don't define the spops_num
# field and see if the default comes through
{
 my $obj = DBITest->new( { spops_id => 1588, spops_goop => 'here we go!', 
                           spops_name => 'AnotherProject' } );
 eval { $obj->save( { is_add => 1, db => $db, skip_cache => 1 } ) };
 if ( $@ ) {
   warn "Cannot save object: $@\n", Dumper( SPOPS::Error->get ), "\n";
   print "not " ;
 }
 print "ok 15\n";

 print "not " if ( $obj->{spops_num} != 2 );
 print "ok 16\n";
}

# Future testing ideas:
#  - security
#  - timestamp checking
#  - fetch_group using 'where'

my $clean_sql = qq/ DROP TABLE $table_name /;
eval { $db->do( $clean_sql ) };
warn "All tests passed ok, but we cannot remove the table ($table_name). Error: $@\n" if ( $@ );
$db->disconnect;
 

