#!/usr/bin/perl

# $Id: stock_doodads.pl,v 1.1 2001/10/15 04:23:18 lachoy Exp $

use strict;

require My::Security;
require My::User;
require My::Doodad;

my @DOODAD_FIELD = qw( name description unit_cost factory );
my @DOODAD_DATA  = (
 [ 'Gobstopper', "Doesn't melt in your hand or your mouth", 1.75, 'Kalamazoo, Michigan, USA' ],
 [ 'AF-22 Peacegiver', 'Brings feeling of peace instead of anger', 20,000, 'San Jose, California, USA' ],
 [ 'Chuckie', 'One bad doll', 12.95, 'Gary, Indiana, USA' ],
 [ 'Lego army', 'With friends like these...', 85.75, 'Copenhagen, Denmark' ],
);

{
    my $user = My::User->fetch_by_login_name( 'UserA', { return_single => 1 } );
    My::Doodad->set_user( $user );

    foreach my $data ( @DOODAD_DATA ) {
        my $doodad = My::Doodad->new;
        for ( my $i = 0; $i < scalar @DOODAD_FIELD; $i++ ) {
            $doodad->{ $DOODAD_FIELD[ $i ] } = $data->[ $i ];
        }
        $doodad->save({ skip_cache => 1 });
        print "Created doodad with ID: ", $doodad->id, "\n";
    }
}
