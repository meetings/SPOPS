package SPOPS::Tie::StrictField;

# $Id: StrictField.pm,v 1.1 2001/02/20 04:31:59 lachoy Exp $

use strict;
use Carp       qw( carp );
use SPOPS::Tie qw( IDX_DATA IDX_CHANGE IDX_INTERNAL IDX_TEMP  
                   IDX_CHECK_FIELDS $PREFIX_TEMP $PREFIX_INTERNAL );

@SPOPS::Tie::StrictField::ISA     = qw( SPOPS::Tie );
@SPOPS::Tie::StrictField::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use constant DEBUG => 0;

# Use this for setting up field lists to check

my %FIELDS = ();

sub _field_check {
  my ( $class, $base_class, $p ) = @_;
  if ( $base_class and ref $p->{field} eq 'ARRAY' and ! $FIELDS{ $base_class } ) {
    foreach my $key ( @{ $p->{field} } ) {
      $FIELDS{ $base_class }->{ lc $key } = 1;
    }   
    return 1;
  }
  return 0;
}

sub _fetch {
  my ( $self, $key ) = @_;
  return $self->SUPER::_fetch( $key ) unless ( $self->{ IDX_CHECK_FIELDS() } );
  if ( $FIELDS{ $self->{class} }->{ lc $key } ) {
    return $self->{ IDX_DATA() }->{ lc $key };
  }
  carp "Error retrieving field ($key): it is not a valid field";
  return undef;
}

sub _store {
  my ( $self, $key, $value ) = @_;
  return $self->SUPER::_store( $key, $value ) unless ( $self->{ IDX_CHECK_FIELDS() } );
  if ( $FIELDS{ $self->{class} }->{ lc $key } ) { 
    $self->{ IDX_CHANGE() }++;
    return $self->{ IDX_DATA() }->{ lc $key } = $value;
  }
  carp "Error setting value for field ($key): it is not a valid field";
  return undef;

}

# For EXISTS and DELETE, We can only do these actions on the actual
# data; use the object methods for the other information.

sub EXISTS {
  my ( $self, $key ) = @_;
  return $self->SUPER::EXISTS( $key ) unless ( $self->{ IDX_CHECK_FIELDS() } );
  if ( DEBUG ) { warn " tie: Checking for existence of ($key)\n"; }
  if ( $FIELDS{ $self->{class} }->{ lc $key } ) { 
    return exists $self->{ IDX_DATA() }->{ lc $key };
  }
  carp "Cannot check existence for field ($key): it is not a valid field";
}


sub DELETE {
  my ( $self, $key ) = @_;
  return $self->SUPER::DELETE( $key ) unless ( $self->{ IDX_CHECK_FIELDS() } );
  if ( DEBUG ) { warn " tie: Clearing value for ($key)\n"; }
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

This class subclasses L<SPOPS::Tie>, adding field-checking
functionality. When you tie the hash, you also pass it a hashref of
extra information, one key of which should be 'field'. The 'field'
parameter specifies what keys may be used to access data in the
hash. This is to ensure that when you set or retrieve a property it is
properly spelled. 

If you do not specify the 'field' parameter properly, you will get
normal L<SPOPS::Tie> functionality, which might throw a monkey wrench
into your application since you and any users will expect the system
to not silently accept misspelled object keys.

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

L<SPOPS::Tie>, L<perltie>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
