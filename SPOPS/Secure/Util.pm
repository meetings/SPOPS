package SPOPS::Secure::Util;

# $Id: Util.pm,v 1.2 2002/09/16 20:42:22 lachoy Exp $

use strict;
use Data::Dumper  qw( Dumper );
use SPOPS::Secure qw( :level :scope );

*_w    = *SPOPS::_w;
*DEBUG = *SPOPS::DEBUG;

# Setup a hashref where w/u => security_level and g points to a
# hashref where the key is the group_id value is the security level.

sub parse_objects_into_hashref {
    my ( $class, $security_objects ) = @_;

    my %items = ( SEC_SCOPE_WORLD() => undef,
                  SEC_SCOPE_USER()  => undef,
                  SEC_SCOPE_GROUP() => {} );
    my $found_item = 0;
ITEM:
    foreach my $sec ( @{ $security_objects } ) {
        $found_item++;
        if ( $sec->{scope} eq SEC_SCOPE_WORLD || $sec->{scope} eq SEC_SCOPE_USER ) {
            $items{ $sec->{scope} } = $sec->{security_level};
            DEBUG() && _w( 2,  "Assign [$sec->{security_level}] to [$sec->{scope}]" );
        }
        elsif ( $sec->{scope} eq SEC_SCOPE_GROUP ) {
            $items{ $sec->{scope} }->{ $sec->{scope_id} } = $sec->{security_level};
            DEBUG() && _w( 2, "Assign [$sec->{security_level}] to ",
                            "[$sec->{scope}][$sec->{scope_id}]" );
        }
    }
    DEBUG() && _w( 1, "All security parsed: ", Dumper( \%items ) );;
    return undef unless ( $found_item );
    return \%items;
}

sub find_class_and_oid {
    my ( $class, $item, $p ) = @_;

    # First assume it's a class we're passed in to check

    my $obj_class = $p->{class} || $item;
    my $oid       = $p->{object_id} || $p->{oid} || '0';

    # If this is an object, modify lines accordingly

    if ( ref $item and UNIVERSAL::can( $item, 'id' ) ) {
        $oid        = eval { $item->id };
        $obj_class  = ref $item;
    }
    return ( $obj_class, $oid );
}


1;
