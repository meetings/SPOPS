# -*-perl-*-

# $Id: 52_rule_date_convert.t,v 1.1 2002/09/09 12:40:13 lachoy Exp $

use strict;
use lib qw( t/ );
use Test::More tests => 15;
use Class::Date;
use Time::Piece;

my $DATE_FORMAT = '%Y-%m-%d %H:%M:%S';

{
    my %config = (
      test => {
         class               => 'TimePieceTest',
         isa                 => [ 'SPOPS::Loopback' ],
         rules_from          => [ 'SPOPS::Tool::DateConvert' ],
         field               => [ qw( myid date_field ) ],
         id_field            => 'myid',
         convert_date_class  => 'Time::Piece',
         convert_date_format => $DATE_FORMAT,
         convert_date_field  => [ 'date_field' ],
      },
    );

    # Create our test class using the loopback

    require_ok( 'SPOPS::Initialize' );

    my $init_list_tp = eval { SPOPS::Initialize->process({ config => \%config }) };
    ok( ! $@, "Initialize process run $@" );
    is( $init_list_tp->[0], 'TimePieceTest',
        'Time::Piece object class initialized' );

    my $original_time = '2002-02-02 02:22:12';

    # Time::Piece

    my $original_obj_tp = Time::Piece->strptime( $original_time, $DATE_FORMAT );
    my $item_tp = TimePieceTest->new({ myid       => 88,
                                       date_field => $original_obj_tp });
    eval { $item_tp->save };
    ok( ! $@, 'Object with Time::Piece field saved' );
    isa_ok( $item_tp->{date_field}, 'Time::Piece',
            'Object field resaved as Time::Piece' );
    is( TimePieceTest->peek( 88, 'date_field' ), $original_time,
        'Time::Piece field value saved' );

    my $new_item_tp = TimePieceTest->fetch( 88 );
    isa_ok( $new_item_tp->{date_field}, 'Time::Piece',
            'Object field fetched as Time::Piece' );
    is( $original_obj_tp, $new_item_tp->{date_field},
        'Object field fetched matches value of original' );

    # Class::Date

    $config{test}->{class} = 'ClassDateTest';
    $config{test}->{convert_date_class} = 'Class::Date';
    my $init_list_cd = eval { SPOPS::Initialize->process({ config => \%config }) };
    ok( ! $@, "Initialize process run $@" );
    is( $init_list_cd->[0], 'ClassDateTest',
        'Class::Date object class initialized' );

    my $original_obj_cd = Class::Date->new( $original_time );
    my $item_cd = ClassDateTest->new({ myid => 44,
                                       date_field => $original_obj_cd });
    eval { $item_cd->save };
    ok( ! $@, 'Object with Class::Date field saved' );
    isa_ok( $item_cd->{date_field}, 'Class::Date',
            'Object field resaved as Class::Date' );
    is( ClassDateTest->peek( 44, 'date_field' ), $original_time,
        'Class::Date field value saved' );

    my $new_item_cd = ClassDateTest->fetch( 44 );
    isa_ok( $new_item_cd->{date_field}, 'Class::Date',
            'Object field fetched as Class::Date' );
    is( $original_obj_cd, $new_item_cd->{date_field},
        'Object field fetched matches value of original' );
}
