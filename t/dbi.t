# -*-perl-*-

# $Id: dbi.t,v 1.5 2001/07/20 02:54:16 lachoy Exp $

# Note that this is a good way to see if certain databases support the
# type checking methods of the DBI -- in fact, we might want to add
# some date/datetime items in the table as well to see what happens

use strict;
use Data::Dumper qw( Dumper );

use constant NUM_TESTS       => 18;
use constant TEST_TABLE_NAME => 'spops_test';

{
    # Read in the config file and make sure we're supposed to run

    do "t/config.pl";
    my $config = _read_config_file();
    $config->{DBI_test} ||= 'n';
    if ( $config->{DBI_test} ne 'y' ) {
        print "1..0\n";
        print "Skipping test on this platform\n";
        exit;
    }

    require Test::More;
    Test::More->import( tests => NUM_TESTS );

    my $driver_name = $config->{DBI_driver};

    # If DBD::ASAny, ensure it's the right version

    if ( $driver_name eq 'ASAny' ) {
        eval { require DBD::ASAny };
        if ( $@ ) {
            die "Cannot require DBD::ASAny module. Do you have it installed? (Error: $@)\n";
        }

        # get around annoying (!) -w declaration that var is only used once...
        my $dumb_ver = $DBD::ASAny::VERSION; 

        # See that the right version is installed. 1.09 has been tested
        # and found ok. (Assuming higher versions will also be ok.)

        if ( $DBD::ASAny::VERSION < 1.09 ) {
            die <<ASANY;
-- The DBD::ASAny driver prior version 1.09 did not support the {TYPE}
attribute Please upgrade the driver before using SPOPS. If you do not
do so, SPOPS will not work properly!

Skipping text on this platform
ASANY
       }
    }

    # Ensure we can get to SPOPS::Initialize

    eval { require SPOPS::Initialize };
    ok( ! $@, 'SPOPS::Initialize load' );

    # Create the class using SPOPS::Initialize

    my $spops_config = {
        tester => {
           class        => 'DBITest',
           isa          => [ qw/ SPOPS::DBI::Pg SPOPS::DBI / ],
           field        => [ qw/ spops_id spops_name spops_goop spops_num / ],
           id_field     => 'spops_id',
           skip_undef   => { spops_num => 1 },
           sql_defaults => [ qw/ spops_num / ],
           base_table   => TEST_TABLE_NAME,
           table_name   => TEST_TABLE_NAME,
        },
    };
    my $class_init_list = eval { SPOPS::Initialize->process({ config => $spops_config }) };
    ok( ! $@, 'Initialize process run' );
    ok( $class_init_list->[0] eq 'DBITest', 'Initialize class' );


    # If the driver is *known* not to process {TYPE} info, we tell the
    # test class to include the type info in its configuration

    my %no_TYPE_dbd_drivers = ();
    if ( $no_TYPE_dbd_drivers{ $driver_name } ) {
        warn "\nDBD Driver $driver_name does not support {TYPE} information\n",
             "Installing manual types for test.\n";
        _assign_types();
    }

    my %dbd_driver_actions = ( Sybase =>  \&_sybase_setup );
    if ( ref $dbd_driver_actions{ $driver_name } eq 'CODE' ) {
        $dbd_driver_actions{ $driver_name }->( $config );
    }

    # First connect to the database

    my $db = DBI->connect( $config->{DBI_dsn}, 
                           $config->{DBI_user}, 
                           $config->{DBI_password} );
    unless ( $db ) {
        die "Cannot connect to database using parameters given. Please\n",
            "edit 'spops_test.conf' with correct information if you'd like\n",
            "to perform the tests. (Error: ", DBI->errstr, ")\n";
    }

    $db->{AutoCommit} = 1;
    $db->{ChopBlanks} = 1;
    $db->{RaiseError} = 1;
    $db->{PrintError} = 0;

    # This is standard, plain vanilla SQL; I don't want to have to do a
    # vendor-specific testing suite (argh!) -- although we could just
    # create sql files and read them in. Adapting the
    # OpenInteract::SQLInstall for strict SPOPS use might be
    # interesting...

    my $table_sql = <<SQL;
CREATE TABLE @{[ TEST_TABLE_NAME ]} (
    spops_id    int not null primary key,
    spops_name  char(20) null,
    spops_goop  char(20) not null,
    spops_num   int default 2
)
SQL

    {
        my ( $sth );
        eval { 
            $sth = $db->prepare( $table_sql );
            $sth->execute;
        };
        if ( $@ ) {
            die "Halting DBI tests -- Cannot create table in DBI database! Error: $@\n";
        }
    }

    # Create an object
    {
        my $obj = eval { DBITest->new({ spops_name => 'MyProject', 
                                        spops_goop => 'oopie doop',
                                        spops_num  => 241, 
                                        spops_id   => 42 } ) };
        ok( ! $@, 'Create object' );

        # Save the object
        
        eval { $obj->save({ is_add => 1, db => $db, skip_cache => 1 }) };
        ok( ! $@, 'Save object (create)' );
        if ( $@ ) {
            warn "Error saving object: $@\n", Dumper( SPOPS::Error->get ), "\n";
        }
    }

    # Fetch an object, then update it
    {
        my $obj = eval { DBITest->fetch( 42, { db => $db, skip_cache => 1 } ) };
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

        my $new_obj = eval { DBITest->fetch( 42, { db => $db, skip_cache => 1 } ) };
        ok( $new_obj->{spops_name} eq $obj->{spops_name}, 'Fetch object (after update)' );
    }

    # Fetch an object then clone it and save it
    {
        my $obj     = eval { DBITest->fetch( 42, { db => $db, skip_cache => 1 } ) };
        my $new_obj = eval { $obj->clone({ spops_name => 'YourProject', 
                                           spops_goop => 'this n that',
                                           spops_id   => 1792 } ) };
        ok( ! $@, 'Clone object (perform)' );
        ok( $new_obj->{spops_name} ne $obj->{spops_name}, 'Clone object (correct data)');

        eval { $new_obj->save( { is_add => 1, db => $db, skip_cache => 1 } ) };
        ok( ! $@, 'Save object (create, after clone)' );
        if ( $@ ) {
            warn "Cannot save object: $@\n", Dumper( SPOPS::Error->get ), "\n";
        }
    } 

    # Create another object, but this time don't define the spops_num
    # field and see if the default comes through
    {
        my $obj = DBITest->new({ spops_id   => 1588, 
                                 spops_goop => 'here we go!', 
                                 spops_name => 'AnotherProject' });
        eval { $obj->save({ is_add => 1, db => $db, skip_cache => 1 }) };
        ok( $obj->{spops_num} == 2, 'Fetch object (correct data with default' );
    }

    # Fetch the three objects in the db and be sure we got them all
    {
        my $obj_list = eval { DBITest->fetch_group({ db => $db, skip_cache => 1 } ) };
        ok( ! $@, 'Fetch group' );
        if ( $@ ) {
            warn "Cannot retrieve objects: $@\n", Dumper( SPOPS::Error->get ), "\n";
        }
        
        ok( ref $obj_list eq 'ARRAY' && scalar @{ $obj_list } == 3, 'Fetch group (return check)' );
    }

    # Fetch a count of the objects in the database
    {
        my $obj_count = eval { DBITest->fetch_count({ db => $db }) };
        ok( $obj_count == 3, 'Fetch count' );
    }

    # Create an iterator and run through the objects
    {
        my $iter = eval { DBITest->fetch_iterator({ db => $db, skip_cache => 1 }) };
        ok( $iter->isa( 'SPOPS::Iterator' ), 'Iterator returned' );
        my $count = 0;
        while ( my $obj = $iter->get_next ) {
            $count++;
        }
        ok( $count == 3, 'Iterator fetch count' );
    }

    cleanup( $db );

# Future testing ideas:
#  - security
#  - timestamp checking
#  - fetch_group using 'where'


}


sub cleanup {
    my ( $db ) = @_;
    my $clean_sql = 'DROP TABLE ' . TEST_TABLE_NAME;
    eval { $db->do( $clean_sql ) };
    if ( $@ ) {
        warn "All tests passed ok, but we cannot remove the table (", TEST_TABLE_NAME, "). Error: $@\n";
    }
    $db->disconnect;
}
 

sub _sybase_setup { 
     my $config = shift;
     $ENV{SYBASE} = $config->{ENV_SYBASE} if ( $config->{ENV_SYBASE} ); 
     require SPOPS::DBI::Sybase;
     unshift @DBITest::ISA, 'SPOPS::DBI::Sybase';
}


sub _assign_types {
    DBITest->CONFIG->{dbi_type_info} = { spops_id   => 'num',  
                                         spops_name => 'char',
                                         spops_goop => 'char', 
                                         spops_num  => 'num' };
}
