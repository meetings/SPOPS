#!/usr/bin/perl

use strict;
use DBI;
use SPOPS::Initialize;
use Data::Dumper  qw( Dumper );

# Set to 1 to see SQL calls (and other stuff)
use constant DEBUG => 0; 

{

  # Uncomment the following lines for MySQL
#  my $DBI_DB_TYPE  = 'mysql';
#  my $DBI_DB_NAME  = 'test';
#  my $DBI_USERNAME = '';
#  my $DBI_PASSWORD = '';

  # Uncomment the following lines for PostgreSQL
  my $DBI_DB_TYPE  = 'Pg';
  my $DBI_DB_NAME  = 'dbname=test';
  my $DBI_USERNAME = 'postgres';
  my $DBI_PASSWORD = 'postgres';

  # Uncomment the following lines for Sybase ASA
#  my $DBI_DB_TYPE  = 'ASAny';
#  my $DBI_DB_NAME  = 'asademo';
#  my $DBI_USERNAME = 'dba';
#  my $DBI_PASSWORD = 'sql';

  # Uncomment the following lines for Sybase ASE
#  my $DBI_DB_TYPE  = 'Sybase';
#  my $DBI_DB_NAME  = 'master';
#  my $DBI_USERNAME = 'sa';
#  my $DBI_PASSWORD = '';

  my $db = DBI->connect( "DBI:$DBI_DB_TYPE:$DBI_DB_NAME", 
                         $DBI_USERNAME, $DBI_PASSWORD,
                         { AutoCommit => 1, PrintError => 0 } )
               || die "Cannot connect! Error: $DBI::errstr";
  $db->{RaiseError} = 1;

  my $auto_inc = undef;
  if ( $DBI_DB_TYPE eq 'Sybase' or $DBI_DB_TYPE eq 'ASAny' ) {
    $auto_inc = 'NUMERIC(10, 0) not null IDENTITY';
  }
  elsif ( $DBI_DB_TYPE eq 'mysql' ) {
    $auto_inc = 'int not null auto_increment';
  }
  elsif ( $DBI_DB_TYPE eq 'Pg' ) {
    $auto_inc = 'SERIAL not null';
  }

  my $fb_table = <<SQL;
    CREATE TABLE fatbomb (
      fatbomb_id  $auto_inc,
      name        varchar(100) null,
      calories    int null,
      cost        varchar(10) null,
      servings    int null default 15,
      primary key ( fatbomb_id )
   )
SQL

  my $rv = eval { $db->do( $fb_table ) };
  if ( $@ ) {
    print "Uh-oh, looks like this table already exists. Let's remove it and try again...\n";
    my $original_error = $@;
    eval { $db->do( 'DROP table fatbomb' ) };
    if ( $@ ) {
      die "Cannot add table and also tried to remove existing table in case of overlap -- both failed.\n",
          "First Error: $original_error\n\nSecond Error: $@\n";
    }
    print "Table removed ok. Trying to re-create.\n";
    eval { $db->do( $fb_table ) };
    if ( $@ ) {
      die "Cannot add table -- error initially adding, then ",
          "successfully dropped table, but still cannot add it.\n",
          "First Error: $original_error\n\n",
          "Second Error: $@\n";
    }
  }
  print "Table created ok.\n";  

  my $spops = {
     fatbomb => {
       class        => 'My::ObjectClass',
       field        => [ qw/ fatbomb_id calories cost name servings / ],
       no_insert    => [ qw/ fatbomb_id / ],
       base_table   => 'fatbomb',
       id_field     => 'fatbomb_id',
       skip_undef   => [ qw/ servings / ],
       sql_defaults => [ qw/ servings / ],
     },
  };

  if ( $DBI_DB_TYPE eq 'Sybase' or $DBI_DB_TYPE eq 'ASAny' ) {
    $spops->{fatbomb}->{isa}          = [ qw/ SPOPS::DBI::Sybase SPOPS::DBI / ];
#    $spops->{fatbomb}->{syb_identity} = 'fatbomb_id';
    $spops->{fatbomb}->{increment_field} = 1;
  }
  elsif ( $DBI_DB_TYPE eq 'mysql' ) {
    $spops->{fatbomb}->{isa}          = [ qw/ SPOPS::DBI::MySQL SPOPS::DBI / ];
    $spops->{fatbomb}->{increment_field} = 1;
  }
  elsif ( $DBI_DB_TYPE eq 'Pg' ) {
    $spops->{fatbomb}->{isa}          = [ qw/ SPOPS::DBI::Pg SPOPS::DBI / ];
    $spops->{fatbomb}->{increment_field} = 1;
  }

  SPOPS::Initialize->process( $spops );

  my $object = My::ObjectClass->new;
  $object->{calories} = 1500;
  $object->{cost}     = '$3.50';
  $object->{name}     = "Super Deluxe Jumbo Big Mac";
  my $fb_id = eval { $object->save( { db => $db, DEBUG => DEBUG } ) };
  if ( $@ ) {
    my $ei = SPOPS::Error->get;
    die "Error found! ($@) Error information: ", Dumper( $ei ), "\n";
  }
  print "Object saved ok!\n",
        "Object ID: $fb_id\n",
        "Servings:  $object->{servings}\n\n";

  if ( DEBUG ) {
    print "Dump of object:\n",
          Dumper( $object ), "\n";
  }

  # Now re-fetch this object
  undef $object;
  my $new_object = eval { My::ObjectClass->fetch( $fb_id, 
                                                  { db => $db,
                                                    DEBUG => DEBUG } )};
  if ( $@ ) {
    my $ei = SPOPS::Error->get;
    die "Error found! ($@) Error information: ", Dumper( $ei ), "\n";
  }
  print "The next set of values (from re-fetched object) should match that above:\n",
        "Object ID: $new_object->{fatbomb_id}\n",
        "Servings:  $new_object->{servings}\n";

  if ( DEBUG ) {
    print "Dump of refetched object:\n",
          Dumper( $new_object ), "\n";
  }

  if ( DEBUG ) {
    print "Raw dump of table:\n";
    my $sql = qq/ 
      SELECT fatbomb_id, name, calories, cost, servings 
        FROM fatbomb 
    /;
    my $sth = $db->prepare( $sql );
    $sth->execute;
    while ( my $row = $sth->fetchrow_arrayref ) {
      print join( "\t", @{ $row } ), "\n";
    }
    $sth->finish;
    print "Done with dump\n";
  }

  # Comment the next line if you want to see the contents of the table
  # after the test has run
#  $db->do( 'DROP TABLE fatbomb' );
#  if ( $DBI_DB_TYPE eq 'Pg' ) {
#    $db->do( 'DROP SEQUENCE fatbomb_fatbomb_id_seq' );
#  }
  $db->disconnect;
  print "Task complete!\n";
}
