# -*-perl-*-

# $Id: 31_dbi_multifield.t,v 1.4 2002/01/23 20:10:51 lachoy Exp $

# Almost exactly the same as 30_dbi.t, but here we're testing whether
# multiple-field primary keys work ok

use strict;
use Data::Dumper qw( Dumper );

use constant NUM_TESTS       => 18;
use constant TEST_TABLE_NAME => 'spops_multi_test';

my $SPOPS_CLASS = 'DBIMultiTest';

my ( $db, $do_end );

END {
    if ( $do_end ) {
        cleanup( $db, TEST_TABLE_NAME );
    }
}
{

    # Grab our DBI routines and be sure we're supposed to run.

    do "t/dbi_config.pl";

    my $config = test_dbi_run();

    $do_end++;

    require Test::More;
    Test::More->import( tests => NUM_TESTS );

    my $driver_name = $config->{DBI_driver};

    my $spops_dbi_driver = check_dbd_compliance( $config, $driver_name, $SPOPS_CLASS );

    # Ensure we can get to SPOPS::Initialize
    # TEST: 1
    require_ok( 'SPOPS::Initialize' );

    # Create the class using SPOPS::Initialize
    # TEST: 2-3
    my $spops_config = {
        tester => {
           class        => $SPOPS_CLASS,
           isa          => [ $spops_dbi_driver, 'SPOPS::DBI' ],
           field        => [ qw/ spops_time spops_user spops_name spops_goop spops_num / ],
           id_field     => [ 'spops_time', 'spops_user' ],
           skip_undef   => [ 'spops_num' ],
           sql_defaults => [ 'spops_num' ],
           base_table   => TEST_TABLE_NAME,
           table_name   => TEST_TABLE_NAME,
        },
    };
    my $class_init_list = eval { SPOPS::Initialize->process({ config => $spops_config }) };
    ok( ! $@, 'Initialize process run' );
    ok( $class_init_list->[0] eq $SPOPS_CLASS, 'Initialize class' );


    # Create a database handle and create our testing table

    $db = get_db_handle( $config );
    create_table( $db, 'multi', TEST_TABLE_NAME );

    my $obj_time = 1004897158;
    my $obj_user = 5;

    # Create an object
    # TEST: 4-5
    {
        my $obj = eval { $SPOPS_CLASS->new({ spops_name => 'MyProject',
                                             spops_goop => 'oopie doop',
                                             spops_num  => 241,
                                             spops_time => $obj_time,
                                             spops_user => $obj_user } ) };
        ok( ! $@, 'Create object' );

        # Save the object

        eval { $obj->save({ is_add => 1, db => $db, skip_cache => 1 }) };
        ok( ! $@, 'Save object (create)' );
        if ( $@ ) {
            warn "Error saving object: $@\n", Dumper( SPOPS::Error->get ), "\n";
        }
    }

    # Fetch an object, then update it
    # TEST: 6-9
    {
        my $obj = eval { $SPOPS_CLASS->fetch( "$obj_time,$obj_user", { db => $db, skip_cache => 1 } ) };
        ok( ! $@, 'Fetch object (perform)' );
        if ( $@ ) {
            warn "Cannot fetch object: $@\n", Dumper( SPOPS::Error->get ), "\n";
        }

        ok( $obj->{spops_name} eq 'MyProject', 'Fetch object (correct data)' );

        $obj->{spops_name} = 'TheirProject';
        $obj->{spops_goop} = 'over there';
        eval { $obj->save({ db => $db, skip_cache => 1 }) };
        ok( ! $@, 'Save object (update)' );
        if ( $@ ) {
            warn "Cannot update object: $@\n", Dumper( SPOPS::Error->get ), "\n";
        }

        my $new_obj = eval { $SPOPS_CLASS->fetch( "$obj_time,$obj_user", { db => $db, skip_cache => 1 } ) };
        ok( $new_obj->{spops_name} eq $obj->{spops_name}, 'Fetch object (after update)' );
    }

    # Fetch an object then clone it and save it
    # TEST: 10-12
    {
        my $obj     = eval { $SPOPS_CLASS->fetch( "$obj_time,$obj_user", { db => $db, skip_cache => 1 } ) };
        my $new_obj = eval { $obj->clone({ spops_name => 'YourProject',
                                           spops_goop => 'this n that',
                                           spops_time => 1004897257 } ) };
        ok( ! $@, 'Clone object (perform)' );
        ok( $new_obj->{spops_name} ne $obj->{spops_name}, 'Clone object (correct data)');
        $new_obj->{spops_user} = 12;

        eval { $new_obj->save( { is_add => 1, db => $db, skip_cache => 1 } ) };
        ok( ! $@, 'Save object (create, after clone)' );
        if ( $@ ) {
            warn "Cannot save object: $@\n", Dumper( SPOPS::Error->get ), "\n";
        }
    }

    # Create another object, but this time don't define the spops_num
    # field and see if the default comes through
    # TEST: 13
    {
        my $obj = $SPOPS_CLASS->new({ spops_time => 1004897292,
                                      spops_user => 5,
                                      spops_goop => 'here we go!',
                                      spops_name => 'AnotherProject' });
        eval { $obj->save({ is_add => 1, db => $db, skip_cache => 1 }) };
        ok( $obj->{spops_num} == 2, 'Fetch object (correct data with default' );
    }

    # Fetch the three objects in the db and be sure we got them all
    # TEST: 14-15
    {
        my $obj_list = eval { $SPOPS_CLASS->fetch_group({ db => $db, skip_cache => 1 } ) };
        ok( ! $@, 'Fetch group' );
        if ( $@ ) {
            warn "Cannot retrieve objects: $@\n", Dumper( SPOPS::Error->get ), "\n";
        }

        ok( ref $obj_list eq 'ARRAY' && scalar @{ $obj_list } == 3, 'Fetch group (return check)' );
    }

    # Fetch a count of the objects in the database
    # TEST: 16
    {
        my $obj_count = eval { $SPOPS_CLASS->fetch_count({ db => $db }) };
        ok( $obj_count == 3, 'Fetch count' );
    }

    # Create an iterator and run through the objects
    # TEST: 17-18
    {
        my $iter = eval { $SPOPS_CLASS->fetch_iterator({ db => $db, skip_cache => 1 }) };
        ok( $iter->isa( 'SPOPS::Iterator' ), 'Iterator returned' );
        my $count = 0;
        while ( my $obj = $iter->get_next ) {
            $count++;
        }
        ok( $count == 3, 'Iterator fetch count' );
    }

# Future testing ideas:
#  - security
#  - timestamp checking
#  - fetch_group using 'where'


}
