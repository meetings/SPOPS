#!/usr/bin/perl

use strict;
use DBI;
use SPOPS::Configure::DBI;
use Data::Dumper  qw( Dumper );

# Change these lines as needed (test is setup for MySQL tho...)
my $DBI_DSN      = 'DBI:mysql:test';
my $DBI_USERNAME = '';
my $DBI_PASSWORD = '';

my $db = DBI->connect( $DBI_DSN, $DBI_USERNAME, $DBI_PASSWORD )
                 || die "Cannot connect! Error: $DBI::errstr";
$db->{RaiseError} = 1;

my $fb_table = <<'SQL';
 CREATE TABLE fatbomb (
   fatbomb_id  int not null auto_increment,
   name        varchar(100) null,
   calories    int null,
   cost        varchar(10) null,
   servings    smallint null default 15,
   primary key ( fatbomb_id )
)
SQL
eval { $db->do( $fb_table ) };
if ( $@ ) {
  warn "Uh-oh, looks like this table already exists. Let's remove it and try again...\n";
  my $original_error = $@;
  eval { $db->do( 'DROP table fatbomb' ) };
  if ( $@ ) {
    die "Cannot add table and also tried to remove existing table in case of overlap -- both failed.\n",
        "First Error: $original_error\n\nSecond Error: $@\n";
  }
  eval { $db->do( $fb_table ) };
  if ( $@ ) {
    die "Cannot add table -- error initially adding, then successfully dropped table, but still cannot add it.\n",
        "First Error: $original_error\n\nSecond Error: $@\n";
  }
}
  

my $spops = {
     fatbomb => {
       class        => 'My::ObjectClass',
       isa          => [ qw/ SPOPS::DBI::MySQL SPOPS::DBI / ],
       field        => [ qw/ fatbomb_id calories cost name servings / ],
       base_table   => 'fatbomb',
       id_field     => 'fatbomb_id',
       skip_undef   => [ qw/ servings / ],
       sql_defaults => [ qw/ servings / ],
     },
};

SPOPS::Configure::DBI->process_config( { config      => $spops,
                                         require_isa => 1 } );
My::ObjectClass->class_initialize;

my $object = My::ObjectClass->new;
$object->{calories} = 1500;
$object->{cost}     = '$3.50';
$object->{name}     = "Super Deluxe Jumbo Big Mac";
my $fb_id = eval { $object->save( { db => $db } ) };
if ( $@ ) {
   my $ei = SPOPS::Error->get;
   die "Error found! ($@) Error information: ", Dumper( $ei ), "\n";
}
print "Object saved ok!\n",
      "Object ID: $fb_id\n",
      "Servings:  $object->{servings}\n\n";

# Now re-fetch this object
undef $object;
my $new_object = eval { My::ObjectClass->fetch( $fb_id, { db => $db } ) };
if ( $@ ) {
   my $ei = SPOPS::Error->get;
   die "Error found! ($@) Error information: ", Dumper( $ei ), "\n";
 }
print "The next set of values (from re-fetched object) should match that above:\n",
      "Object ID: $new_object->{fatbomb_id}\n",
      "Servings:  $new_object->{servings}\n";

# Uncomment the next line if you want to see the contents of the table
# after the test has run
$db->do( 'DROP TABLE fatbomb' );
$db->disconnect;

