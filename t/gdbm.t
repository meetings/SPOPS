# -*-perl-*-

# $Id: gdbm.t,v 1.4 2001/07/20 02:54:16 lachoy Exp $

use strict;

use constant GDBM_FILE => 't/test.gdbm';
use constant NUM_TESTS => 15;

sub cleanup  { unlink GDBM_FILE }
sub new_object {
    eval { GDBMTest->new({ name    => 'MyProject', 
                           version => 1.14, 
                           author  => 'La Choy (lachoy@cwinters.com)' }) };
}


{

    # Get the configuration info (in this case, just whether we're
    # supposed to run or not)

    do "t/config.pl";
    my $config = _read_config_file();
    $config->{GDBM_test} ||= 'n';
    if ( $config->{GDBM_test} ne 'y' ) {
        print "1..0\n";
        print "Skipping test on this platform\n";
        exit;
    }

    require Test::More;
    Test::More->import( tests => NUM_TESTS );

    # Ensure GDBM_File is installed (Makefile.PL should have checked,
    # but just in case...)

    eval { require GDBM_File };
    ok( ! $@, 'GDBM_File module' );

    # Same with SPOPS::Initialize
    eval { require SPOPS::Initialize };
    ok( ! $@, 'SPOPS::Initialize require' );

    my $spops_config = {
       tester => {
           class      => 'GDBMTest',
           isa        => [ 'SPOPS::GDBM' ],
           field      => [ qw/ name version author url / ],
           create_id  => sub { return join '-', $_[0]->{name}, $_[0]->{version} },
           gdbm_info  => { filename => GDBM_FILE }, 
       },
    };

    my $class_init_list = eval { SPOPS::Initialize->process({ config => $spops_config }) };
    ok( ! $@, 'Initialize process run' );
    ok( $class_init_list->[0] eq 'GDBMTest', 'Initialize class' );
    
    # Time for a test drive
    {

        # Make sure we can at least create an object
        my $obj = new_object;
        ok( ! $@, "Create object" );

        # Make sure GDBM_WRCREAT really creates a new file
        cleanup();
        $obj = new_object;
        eval { $obj->save({ perm => 'create' }) };
        warn "Error: $@" if ( $@ );
        ok( ! $@ && -w GDBM_FILE, 'Create new file (create permission)' );

        # Make sure GDBM_WRITE gets changed to GDBM_WRCREAT if the file doesn't exist
        cleanup();
        $obj = new_object;
        eval { $obj->save({ perm => 'write' }) };
        ok( ! $@ && -w GDBM_FILE, 'Create new file (write permission)' );

        # See if it does the Right Thing on its own
        cleanup();
        $obj = new_object;
        eval { $obj->save };
        ok( ! $@ && -w GDBM_FILE, 'Create new file (no permission)' );

    }

    # Fetch an object, then clone it and save it (no cleanup from previous
    {
        my $obj = eval { GDBMTest->fetch( 'MyProject-1.14' ) };
        ok( ! $@, 'Fetch object' );
        ok( $obj->{name} eq 'MyProject', 'Fetch object (content check)' );

        my $new_obj = eval { $obj->clone({ name => 'YourProject', version => 1.02 }) };
        ok( ! $@, 'Clone object' );
        ok( $new_obj->{name} ne $obj->{name}, 'Clone object (override content)' );

        eval { $new_obj->save };
        ok( ! $@, 'Save object' );
    }

    # Fetch the two objects in the db and be sure we got them all
    {
        my $obj_list = eval { GDBMTest->fetch_group };
        ok( ! $@, 'Fetch group' );
        ok( ref $obj_list eq 'ARRAY' && scalar @{ $obj_list } == 2, 'Fetch group (number check)' );
    }
    cleanup();
}
