package My::Common;

# $Id: Common.pm,v 2.1 2002/04/30 04:00:17 lachoy Exp $

# Common routines for the My:: classes.

use strict;
use DBI;
use SPOPS::DBI;
use SPOPS::Utility;

# CHANGE
#
# Modify $SPOPS_DB below to:
#
#     SPOPS::DBI::MySQL     if you're using MySQL
#     SPOPS::DBI::Sybase    if you're using Sybase ASA/ASE or MS SQL
#     SPOPS::DBI::Pg        if you're using PostgreSQL
#     SPOPS::DBI::Oracle    if you're using Oracle
#     SPOPS::DBI::SQLite    if you're using SQLite
#     SPOPS::DBI::InterBase if you're using InterBase/FirebirdSQL

my $SPOPS_DB = 'SPOPS::DBI::SQLite';
eval "require $SPOPS_DB";

@My::Common::ISA = ( 'SPOPS::Utility', $SPOPS_DB, 'SPOPS::DBI' );

# CHANGE
#
# Modify database connection info as needed

use constant DBI_DSN      => 'DBI:SQLite:dbname=sqlite_test';
use constant DBI_USER     => '';
use constant DBI_PASSWORD => '';

my ( $DB, $USER, $GROUP );

sub set_user {
    my ( $class, $user ) = @_;
    unless ( $class->global_group_current ) {
        $class->set_group( $user->group );
    }
    return $USER = $user;
}

sub set_group {
    my ( $class, $group ) = @_;
    return $GROUP = $group;
}


# You can change who the superuser is by modifying this ID

sub get_superuser_id  { return 1 }
sub get_supergroup_id { return 1 }

sub global_security_object_class { return 'My::Security' }
sub global_user_current          { return $USER          }
sub global_group_current         { return $GROUP         }

sub global_datasource_handle {
    return $DB if ( $DB );
    $DB = DBI->connect( DBI_DSN, DBI_USER, DBI_PASSWORD,
                        { RaiseError => 1, PrintError => 0, AutoCommit => 1 });
    unless ( $DB ) { SPOPS::Exception->throw( "Cannot connect to DB: $DBI::errstr" ) }
    return $DB;
}

1;
