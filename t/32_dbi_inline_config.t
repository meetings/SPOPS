# -*-perl-*-

# $Id: 32_dbi_inline_config.t,v 3.0 2002/08/28 01:16:32 lachoy Exp $

use strict;
use constant NUM_TESTS       => 4;
use constant TEST_TABLE_NAME => 'foo';

my $SPOPS_CLASS = 'DBIInlineTest';

my ( $db, $do_end );

{
    # Grab our DBI routines and be sure we're supposed to run.

    do "t/dbi_config.pl";
    my $config = test_dbi_run();
    $do_end++;

    require Test::More;
    Test::More->import( tests => NUM_TESTS );

    require_ok( 'SPOPS::Initialize' );

    my $driver_name = $config->{DBI_driver};
    my $spops_dbi_driver = get_spops_driver( $config, $driver_name );

    # Create the class using SPOPS::Initialize

    my $spops_config = {
        tester => {
           class        => $SPOPS_CLASS,
           isa          => [ $spops_dbi_driver, 'SPOPS::DBI' ],
           rules_from   => [ 'SPOPS::Tool::DBI::Datasource' ],
           field        => [ qw/ spops_id spops_name spops_goop spops_num / ],
           id_field     => 'spops_id',
           base_table   => TEST_TABLE_NAME,
           dbi_config   => {
                 dsn      => $config->{DBI_dsn},
                 username => $config->{DBI_user},
                 password => $config->{DBI_password}
           },
        },
    };
    my $class_init_list = eval { SPOPS::Initialize->process({ config => $spops_config }) };
    ok( ! $@, 'Initialize process run' );
    is( $class_init_list->[0], $SPOPS_CLASS, 'Initialize class' );

    my $dbh = $SPOPS_CLASS->global_datasource_handle;
    ok( UNIVERSAL::isa( $dbh, 'DBI::db' ), 'Retrieved datasource from class' );
}
