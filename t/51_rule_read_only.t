# -*-perl-*-

# $Id: 51_rule_read_only.t,v 3.0 2002/08/28 01:16:32 lachoy Exp $

use strict;
use lib qw( t/ );
use Test::More tests => 6;

{
    my %config = (
      test => {
         class      => 'ReadOnlyTest',
         isa        => [ 'SPOPS::Loopback' ],
         rules_from => [ 'SPOPS::Tool::ReadOnly' ],
         field      => [ qw( id_field field_name ) ],
         id_field   => 'id_field',
      },
    );

    # Create our test class using the loopback

    require_ok( 'SPOPS::Initialize' );

    my $class_init_list = eval { SPOPS::Initialize->process({ config => \%config }) };
    ok( ! $@, "Initialize process run $@" );
    is( $class_init_list->[0], 'ReadOnlyTest', 'Object class initialized' );

    # Create an object and try to save it

    my $item = ReadOnlyTest->new({ id_field   => "Foo!",
                                   field_name => "Bar!" });
    eval { $item->save };
    ok( $@, "Object creation failed (this is good)" );

    my $fetched = ReadOnlyTest->fetch( "test" );
    $fetched->{id_field} = "changed";
    eval { $fetched->save };
    ok( $@, "Update of fetched object failed (this is good)" );

    eval { $fetched->remove };
    ok( $@, "Remove of fetched object failed (this is good)" );
}
