package SPOPS::Tie;

# $Id: Tie.pm,v 1.16 2001/01/31 02:30:44 cwinters Exp $

use strict;
use vars qw( $PREFIX_TEMP $PREFIX_INTERNAL );
use Carp qw( carp );

require Exporter;

@SPOPS::Tie::ISA       = qw( Exporter );
@SPOPS::Tie::VERSION   = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);
@SPOPS::Tie::EXPORT_OK = qw( IDX_DATA IDX_CHANGE IDX_INTERNAL IDX_TEMP  
                             IDX_CHECK_FIELDS $PREFIX_TEMP $PREFIX_INTERNAL );

use constant IDX_DATA          => '_collection_data';
use constant IDX_CHANGE        => '_changed';
use constant IDX_INTERNAL      => '_internal';
use constant IDX_TEMP          => '_temp_data';
use constant IDX_CHECK_FIELDS  => '_CHECK_FIELD_LIST';
$PREFIX_TEMP       = 'tmp_';
$PREFIX_INTERNAL   = '_internal';

use constant DEBUG => 0;

# Use this for setting up field lists to check

my %FIELDS = ();

# Tie interface stuff below here; see 'perldoc perltie' for what
# each method does. (Or better yet, read Damian Conway's discussion
# of tie in 'Object Oriented Perl'.)


# First ensure the fieldnames are registered, then return the
# object. The object always keeps track of the actual properties, the
# class, whether the object's properties have been changed and keeps
# any temporary data that lives only for the object's lifetime.

sub TIEHASH {
  my ( $class, $base_class, $p ) = @_;

  # If we haven't already stored the fields associated with
  # this class, do so

  my $HAS_FIELD = 0;
  if ( $base_class and ref $p->{field} eq 'ARRAY' and ! $FIELDS{ $base_class } ) {
    foreach my $key ( @{ $p->{field} } ) {
      $FIELDS{ $base_class }->{ lc $key } = 1;
    }   
    $HAS_FIELD = 1;
  }
  return bless ({ class              => $base_class, 
                  IDX_TEMP()         => {},
                  IDX_INTERNAL()     => {},
                  IDX_CHANGE()       => 0, 
                  IDX_DATA()         => {},
                  IDX_CHECK_FIELDS() => $HAS_FIELD }, $class );
}

# Just go through each of the possible things that could be
# set and do the appropriate action.

sub FETCH {
  my ( $self, $key ) = @_;
  if ( DEBUG ) { warn " tie: Trying to retrieve value for ($key)\n"; }
  return $self->{ IDX_CHANGE() }                if ( $key eq IDX_CHANGE );
  return $self->{ IDX_TEMP() }->{ lc $key }     if ( $key =~ /^$PREFIX_TEMP/ );
  return $self->{ IDX_INTERNAL() }->{ lc $key } if ( $key =~ /^$PREFIX_INTERNAL/ );
  return $self->{ IDX_DATA() }->{ lc $key }     if ( ! $self->{ IDX_CHECK_FIELDS() } or 
                                                     $FIELDS{ $self->{class} }->{ lc $key } );
  carp "Error retrieving field ($key): it is not a valid field";
  return undef;
}

# Similar to FETCH, including the blabbing about whether the field is valid

sub STORE {
  my ( $self, $key, $value ) = @_;
  if ( DEBUG ) { warn " tie: Trying to store in ($key) value ($value)\n"; }
  return $self->{ IDX_CHANGE() } = $value                if ( $key eq IDX_CHANGE );
  return $self->{ IDX_TEMP() }->{ lc $key } = $value     if ( $key =~ /^$PREFIX_TEMP/ );
  return $self->{ IDX_INTERNAL() }->{ lc $key } = $value if ( $key =~ /^$PREFIX_INTERNAL/ );
  if ( ! $self->{ IDX_CHECK_FIELDS() } or 
       $FIELDS{ $self->{class} }->{ lc $key } ) { 
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
  if ( DEBUG ) { warn " tie: Checking for existence of ($key)\n"; }
  if ( ! $self->{ IDX_CHECK_FIELDS() } or $FIELDS{ $self->{class} }->{ lc $key } ) { 
    return exists $self->{ IDX_DATA() }->{ lc $key };
  }
  carp "Cannot check existence for field ($key): it is not a valid field";
}

sub DELETE {
  my ( $self, $key ) = @_;
  if ( DEBUG ) { warn " tie: Clearing value for ($key)\n"; }
  if ( ! $self->{ IDX_CHECK_FIELDS() } or 
       $FIELDS{ $self->{class} }->{ lc $key } ) { 
    $self->{ IDX_DATA() }->{ lc $key } = undef;
    $self->{ IDX_CHANGE() }++;
  }
  carp "Cannot remove data for field ($key): it is not a valid field";
}

# We've disabled the ability to do: $object = {} or %{ $object } = ();
# nothing bad happens, it's just a no-op

sub CLEAR {
  my ( $self ) = @_;
  carp 'Trying to clear object through hash means failed; use object interface';
}

# Note that you only see the data when you cycle through the keys 
# or even do a Data::Dumper::Dumper( $object ); you do not see
# the meta-data being tracked.

sub FIRSTKEY {
  my ( $self ) = @_;
  if ( DEBUG ) { warn " tie: Finding first key in data object\n"; }
  keys %{ $self->{ IDX_DATA() } };
  my $first_key = each %{ $self->{ IDX_DATA() } };
  return undef unless defined $first_key;
  return $first_key;
}

sub NEXTKEY {
  my ( $self ) = @_;
  if ( DEBUG ) { warn " tie: Finding next key in data object\n"; }
  my $next_key = each %{ $self->{ IDX_DATA() } };
  return undef unless defined $next_key;
  return $next_key;
}

1;

__END__

=pod

=head1 NAME

SPOPS::Tie - Simple class implementing tied hash with some goodies

=head1 SYNOPSIS

 # Create the tied hash
 use SPOPS::Tie;
 my ( %data );
 my @fields = qw( first_name last_name login birth_date );
 tie %data, 'SPOPS::Tie', $class, \@fields;

 # Store some simple properties
 $data{first_name} = 'Charles';
 $data{last_name}  = 'Barkley';
 $data{login}      = 'cb';
 $data{birth_date} = '1957-01-19';

 # Store a temporary property
 $data{tmp_rebound_avg} = 11.3;

 # Trigger a warning by trying to store a misspelled 
 # or unknown property
 $data{login_name}  = 'cb';  # 'login' is correct
 $data{middle_name} = 'Amadeus'; # not in @fields list

 while ( my ( $prop, $val ) = each %data ) {
  printf( "%-15s: %s\n", $prop, $val );
 }

 # Note that output does not include 'tmp_rebound_avg'
 >first_name     : Charles
 >login          : cb
 >last_name      : Barkley
 >birth_date     : 1957-01-19

=head1 DESCRIPTION

Stores data for a SPOPS object, and also some accompanying materials
such as whether the object has been changed and any temporary
variables.

=head2 Validating Object Properties

When you tie the hash, you also pass it a hashref of extra
information. This can currently include the 'field' parameter.

The 'field' parameter specifies what keys may be used to access data
in the hash. This is to ensure that when you set or retrieve a
property it is properly spelled. For instance:

 my ( %data );
 my $class = 'SPOPS::User';
 tie %data, 'SPOPS::Tie', $class, [ qw/ first_name last_name login / ];
 $data{firstname} = 'Chucky';

would result in a message to STDERR, something like:

 Error setting value for field (firstname): it is not a valid field
 at my_tie.pl line 9

since you have misspelled the property, which should be 'first_name'.

If you do not pass this information, C<SPOPS::Tie> will not do the
checking for you.

=head2 Checking Changed State

You can check whether the data have changed since the last fetch by
either calling the method of the SPOPS object (recommended) or asking
for the '_changed' key:

 # See if this object has changed
 if ( $obj->{_changed} ) {
  ...do stuff...
 }

 # Tell the object that it has changed (force)
 $obj->{_changed} = 1;

Note that this state is automatically tracked based on whether you set
any property of the object, so you should never need to do this. See
L<SPOPS> for more information about the I<changed> methods.

=head2 Tracking Temporary Variables

Note that this section only holds true if you have field-checking
turned on (by passing an arrayref of fields in the 'field' key of the
hashref passed as the second parameter in the C<tie> call).

At times you might wish to keep information with the object that is
only temporary and not supposed to be serialized with the
object. However, the 'valid property' nature of the tied hash prevents
you from storing information in properties with names other than those
you pass into the initial call to tie(). What to do?

Have no fear! Simply prefix the property with 'tmp_' (or something
else, see below) and SPOPS::Tie will keep the information at the ready
for you:

 my ( %data );
 my $class = 'SPOPS::User';
 tie %data, 'SPOPS::Tie', $class, [ qw/ first_name last_name login / ];
 $data{first_name} = 'Chucky';
 $data{last_name}  = 'Gordon';
 $data{login}      = 'chuckg';
 $data{tmp_inoculation} = 'Jan 16, 1981';

For as long as the hash %data is in scope, you can reference the
property 'tmp_inoculation'. However, you can only reference it
directly. You will not see the property if you iterate through hash
using I<keys> or I<each>.

=head2 Storing Information for Internal Use

The final kind of information that can be stored in a SPOPS object is
'internal' information. This is similar to temporary variables, but is
typically only used in the internal SPOPS mechanisms -- temporary
variables are often used to store computed results or other
information for display rather than internal use.

For example, the L<SPOPS::DBI> module allows you to create validating
subroutines to ensure that your data conform to some sort of
specification:

 push @{ $obj->{_internal_validate} }, \&ensure_consistent_date;

Most of the time you will not need to deal with this, but check the
documentation for the object you are using.

=head1 METHODS

See L<Tie::Hash> or L<perltie> for details of what the different
methods do.

=head1 TO DO

B<Benchmarking>

We should probably benchmark this thing to see what it can do

=head1 BUGS

=head1 SEE ALSO

L<perltie>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>


=cut
