package SPOPS::Tie::StrictField;

# $Id: StrictField.pm,v 2.0 2002/03/19 04:00:04 lachoy Exp $

use strict;
use base  qw( SPOPS::Tie );

use Carp       qw( carp );
use SPOPS::Tie qw( IDX_DATA IDX_CHANGE IDX_INTERNAL IDX_TEMP  
                   IDX_CHECK_FIELDS $PREFIX_TEMP $PREFIX_INTERNAL );

$SPOPS::Tie::StrictField::VERSION  = substr(q$Revision: 2.0 $, 10);

*_w    = *SPOPS::_w;
*DEBUG = *SPOPS::DEBUG;

# Use this for setting up field lists to check

my %FIELDS = ();


# Called by parent -- return a true to indicate fields ARE being
# checked

sub _field_check {
    my ( $class, $base_class, $p ) = @_;
    if ( $base_class and ref $p->{field} eq 'ARRAY' ) {
        unless ( ref $FIELDS{ $base_class } eq 'HASH' ) {
            foreach my $key ( @{ $p->{field} } ) {
                $FIELDS{ $base_class }->{ lc $key } = 1;
            }
        }
        return 1;
    }
    return 0;
}


# Return true if we can fetch (is a valid field), false if not

sub _can_fetch {
    my ( $self, $key ) = @_;
    return 1 unless ( $self->{ IDX_CHECK_FIELDS() } );
    return 1 if ( $FIELDS{ $self->{class} }->{ lc $key } );
    carp "ERROR: Cannot retrieve field ($key): it is not a valid field";
    return undef;
}


# Return true if we can store (is a valid field), false if not

sub _can_store {
    my ( $self, $key, $value ) = @_;
    return 1 unless ( $self->{ IDX_CHECK_FIELDS() } );
    return 1 if ( $FIELDS{ $self->{class} }->{ lc $key } );
    carp "ERROR: Cannot set value for field ($key): it is not a valid field";
    return undef;

}

# For EXISTS and DELETE, We can only do these actions on the actual
# data; use the object methods for the other information.

sub EXISTS {
    my ( $self, $key ) = @_;
    return $self->SUPER::EXISTS( $key ) unless ( $self->{ IDX_CHECK_FIELDS() } );
    DEBUG() && _w( 3, " tie: Checking for existence of ($key)\n" );
    if ( $FIELDS{ $self->{class} }->{ lc $key } ) {
        return exists $self->{ IDX_DATA() }->{ lc $key };
    }
    carp "Cannot check existence for field ($key): it is not a valid field";
}


sub DELETE {
    my ( $self, $key ) = @_;
    return $self->SUPER::DELETE( $key ) unless ( $self->{ IDX_CHECK_FIELDS() } );
    DEBUG() && _w( 3, " tie: Clearing value for ($key)\n" );
    if ( $FIELDS{ $self->{class} }->{ lc $key } ) { 
        $self->{ IDX_DATA() }->{ lc $key } = undef;
        $self->{ IDX_CHANGE() }++;
    }
    carp "Cannot remove data for field ($key): it is not a valid field";
}

1;

__END__

=pod

=head1 NAME

SPOPS::Tie::StrictField - Enable field checking for SPOPS objects

=head1 SYNOPSIS

 use SPOPS::Tie::StrictField;
 my ( %data );
 my @fields = qw( first_name last_name login birth_date );
 tie %data, 'SPOPS::Tie::StrictField', $class, \@fields;

 # Trigger warnings by trying to store a misspelled
 # or unknown property

 # 'login' is the correct field
 $data{login_name}  = 'cb';

 # not in @fields list
 $data{middle_name} = 'Amadeus';

=head1 DESCRIPTION

This class subclasses L<SPOPS::Tie|SPOPS::Tie>, adding field-checking
functionality. When you tie the hash, you also pass it a hashref of
extra information, one key of which should be 'field'. The 'field'
parameter specifies what keys may be used to access data in the
hash. This is to ensure that when you set or retrieve a property it is
properly spelled.

If you do not specify the 'field' parameter properly, you will get
normal L<SPOPS::Tie|SPOPS::Tie> functionality, which might throw a
monkey wrench into your application since you and any users will
expect the system to not silently accept misspelled object keys.

For instance:

 my ( %data );
 my $class = 'SPOPS::User';
 tie %data, 'SPOPS::Tie::StrictField', $class, [ qw/ first_name last_name login / ];
 $data{firstname} = 'Chucky';

would result in a message to STDERR, something like:

 Error setting value for field (firstname): it is not a valid field
 at my_tie.pl line 9

since you have misspelled the property, which should be 'first_name'.

=head1 SEE ALSO

L<SPOPS::Tie|SPOPS::Tie>

L<perltie|perltie>

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
