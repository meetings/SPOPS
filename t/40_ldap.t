# -*-perl-*-

# $Id: 40_ldap.t,v 1.6 2001/08/20 21:06:40 lachoy Exp $

use constant NUM_TESTS => 26;

my $LDAP_CLASS = 'LDAP_Test';
my $LDAP_OU    = 'ou=SPOPSTest';
my ( $BASE_DN );

my @DATA_FIELDS = qw( uid cn sn givenname mail );
my @OBJECT_DATA = (
   [ 'laverne', 'Laverne the Great', 'DaFazio', 'Laverne', 'laverne@beer.com' ],
   [ 'fonzie', 'The Fonz', 'Fonzerelli', 'Arthur', 'fonzie@cool.com' ],
   [ 'lachoy', 'La Choy', 'Choy', 'La', 'lachoy@spoiled.com' ],
   [ 'bofh', 'Joe Shmoe', 'Shmoe', 'Joe', 'dingdong@411.com' ]
);

{
    # Read in the config file and make sure we're supposed to run

    do "t/config.pl";
    my $config = _read_config_file();
    if ( $config->{LDAP_test} ne 'y' ) {
        print "1..0\n";
        print "Skipping test on this platform\n";
        exit;
    }

    require Test::More;
    Test::More->import( tests => NUM_TESTS );

    # Tests: 1 - 3

    require_ok( 'Net::LDAP' );
    require_ok( 'SPOPS::LDAP' );
    require_ok( 'SPOPS::Initialize' );

    # Initialize the class

    $BASE_DN = "$LDAP_OU,$config->{LDAP_base_dn}";
    my $spops_config = {
         tester => {
             ldap_base_dn => $BASE_DN,
             class        => $LDAP_CLASS,
             isa          => [ 'SPOPS::LDAP' ],
             field        => [ qw/ uid cn sn givenname mail objectclass / ],
             id_field     => 'uid',
             id_value_field => 'mail',
             field_map    => { user_id => 'uid', first_name => 'givenname' },
             multivalue   => [ 'objectclass' ],
             ldap_object_class => [ qw/ top person inetOrgPerson organizationalPerson / ],
             ldap_fetch_object_class => 'person',
         }
    };

    # Tests: 4 - 5

    my $class_init_list = eval { SPOPS::Initialize->process({ config => $spops_config }) };
    ok( ! $@, 'Initialize process run' );
    is( $class_init_list->[0], $LDAP_CLASS, 'Class initialize' );

    # Now create the connection

    # Tests: 6 - 7

    my $ldap = Net::LDAP->new( $config->{LDAP_host}, 
                               port    => $config->{LDAP_port} );
    ok( $ldap, 'Connect to directory' );
    my @bind_args = ( $config->{LDAP_bind_dn} ) 
                      ? ( $config->{LDAP_bind_dn}, password => $config->{LDAP_bind_password} ) 
                      : ();
    my $ldap_msg = $ldap->bind( @bind_args );
    ok( ! $ldap_msg->code, 'Bind to directory' ); # && die "Cannot bind! Error: ", $msg->error, "\n";

    # Cleanup any leftover items

    my $old_items = tear_down( $ldap );
    if ( $old_items ) {
        warn "Cleaned up ($old_items) old entries in LDAP directory\n",
             "(probably leftover from previous halted test run, don't worry)\n";
    }

    setup( $ldap );

    my ( $test_object );

    # Create an object

    # Tests: 8 - 11

    my @o = ();
    my $create_error = 0;
    my $data_idx = int( rand scalar @OBJECT_DATA );
    my $data = $OBJECT_DATA[ $data_idx ];
    $test_object = $LDAP_CLASS->new;
    ok( ! $test_object->is_saved, 'Save status of new object' );
    for ( my $j = 0; $j < scalar @DATA_FIELDS; $j++ ) {
        $test_object->{ $DATA_FIELDS[ $j ] } = $data->[ $j ];
    }
    ok( $test_object->is_changed, 'Change status of modified object' );
    eval { $test_object->save({ ldap => $ldap }) };
    ok( ! $@, 'Create object' );
    ok( $test_object->is_saved, 'Save status of saved object' );
    undef $test_object;

    # Fetch the object

    # Tests: 12 - 15

    $test_object = eval { $LDAP_CLASS->fetch( $data->[0], { ldap => $ldap }) };
    ok( ! $@ and $test_object, 'Fetch object (action)' );
    is( $test_object->{mail}, $data->[4], 'Fetch object (content)' );
    ok( $test_object->is_saved, 'Fetch object save status' );
    ok( ! $test_object->is_changed, 'Fetch object change status' );
    my $fetch_filter = "mail=$test_object->{mail}";
    undef $test_object;

    # Fetch the object with a filter

    # Tests: 16 - 17

    $test_object = eval { $LDAP_CLASS->fetch( undef,
                                              { ldap  => $ldap,
                                                filter => $fetch_filter } ) };
    ok( ! $@ and $test_object, 'Fetch object by filter (action)' );
    is( $test_object->{mail}, $data->[4], 'Fetch object by filter (content)' );
    my $fetch_dn = $test_object->dn;
    undef $test_object;

    # Fetch the object with a DN

    # Tests: 18 - 19

    $test_object = eval { $LDAP_CLASS->fetch_by_dn( $fetch_dn, { ldap => $ldap }) };
    ok( ! $@ and $test_object, 'Fetch object by DN (action)' );
    is( $test_object->{mail}, $data->[4], 'Fetch object by DN (content)' );

    # Now update that object

    # Tests: 20 - 22

    $test_object->{cn}   = 'Heavy D';
    $test_object->{mail} = 'slapdash@yahoo.com';
    ok( $test_object->is_changed, 'Change status of modified object' );
    eval { $test_object->save({ ldap => $ldap }) };
    ok( ! $@, 'Object update' );
    ok( ! $test_object->is_changed, 'Change status of modified but saved object' );
    undef $test_object;

    # Now add some more

    my $added = 0;
    for ( my $i = 0; $i < scalar @OBJECT_DATA; $i++ ) {
        next if ( $i == $data_idx );
        my $new_object = $LDAP_CLASS->new;
        my $new_data   = $OBJECT_DATA[ $i ];
        for ( my $j = 0; $j < scalar @DATA_FIELDS; $j++ ) {
            $new_object->{ $DATA_FIELDS[ $j ] } = $new_data->[ $j ];
        }
        eval { $new_object->save({ ldap => $ldap }) };
        $added++;
    }

    # Then fetch them all

    # Tests: 23

    my $object_list = $LDAP_CLASS->fetch_group({ ldap  => $ldap });
    is( scalar @OBJECT_DATA, scalar @{ $object_list }, 'Fetch group of objects' );

    # And fetch them all with an iterator

    # Tests: 24-25

    my $ldap_iter = $LDAP_CLASS->fetch_iterator({ ldap => $ldap });
    ok( $ldap_iter->isa( 'SPOPS::Iterator' ), 'Iterator return' );
    my $iter_count = 0;
    while ( my $iterated = $ldap_iter->get_next ) {
        $iter_count++;
    }
    is( scalar @OBJECT_DATA, $iter_count, 'Iterate through objects' );

    # And remove all the entries

    # Tests: 26

    my $removed = 0;
    foreach my $ldap_object ( @{ $object_list } ) {
        eval { $ldap_object->remove({ ldap => $ldap }) };
        $removed++  unless ( $@ );
    }

    is ( $removed, scalar @OBJECT_DATA, 'Remove object' );

    # And remove our OU object

    tear_down( $ldap );
    $ldap->unbind;
}

# Create our ou object

sub setup {
    my ( $ldap ) = @_;
    my $ldap_msg = $ldap->add( $BASE_DN,
                               attr => [ objectclass => [ 'organizationalRole' ],
                                         cn          => [ 'SPOPS Testing Group' ] ]);
    if ( my $code = $ldap_msg->code ) {
        die "Cannot create OU entry for ($BASE_DN) in LDAP\n",
            "Error: ", $ldap_msg->error, " ($code)\n";
    }
}


# Find all the entries and remove them, along with our OU

sub tear_down {
    my ( $ldap ) = @_;
    my $ldap_msg = $ldap->search( scope  => 'sub', 
                                  base   => $BASE_DN,
                                  filter => 'objectclass=person' );
    return if ( $ldap_msg->code );
    my $entry_count = 0;
    my @entries = $ldap_msg->entries;
    foreach my $entry ( @entries ) {
        $entry->changetype( 'delete' );
        $entry->update( $ldap );
        $entry_count++;
    }
    $ldap->delete( $BASE_DN );
    $entry_count++;
    return $entry_count;
}
