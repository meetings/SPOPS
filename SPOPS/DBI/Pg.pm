package SPOPS::DBI::Pg;

# $Id: Pg.pm,v 1.15 2002/01/08 04:31:53 lachoy Exp $

use strict;
use SPOPS qw( _w DEBUG );
use SPOPS::Key::DBI::Sequence;

@SPOPS::DBI::Pg::ISA      = ();
$SPOPS::DBI::Pg::VERSION  = '1.90';
$SPOPS::DBI::Pg::Revision = substr(q$Revision: 1.15 $, 10);


sub sql_quote {
    my ( $class, $value, $type, $db ) = @_;
    $db ||= $class->global_db_handle;
    unless ( ref $db ) {
        SPOPS::Exception->throw( "No database handle could be found!" );
    }
    return $db->quote( $value, $type );
}


sub sql_current_date  { return 'CURRENT_TIMESTAMP()' }


sub pre_fetch_id {
    my ( $item, $p ) = @_;
    return undef if     ( $item->CONFIG->{increment_field} );
    return undef unless ( $p->{sequence_name} = $item->CONFIG->{sequence_name} );
    return SPOPS::Key::DBI::Sequence::retrieve_sequence( $item, $p );
}


sub post_fetch_id {
    my ( $item, $p ) = @_;
    return undef unless ( $item->CONFIG->{increment_field} );
    if ( my $custom_sequence_name = $item->CONFIG->{sequence_name} ) {
        $p->{sequence_name} = $custom_sequence_name;
    }
    unless ( $p->{sequence_name} ) {
        $p->{sequence_name} = join( '_', $item->CONFIG->{base_table}, $item->CONFIG->{id_field}, 'seq' );
    }
    $p->{sequence_call} = q{ SELECT currval( '%s' ) };
    DEBUG() && _w( 1, "Using sequence name of ($p->{sequence_name}) and ",
                      "call of ($p->{sequence_call}) for Pg SERIAL field." );
    return SPOPS::Key::DBI::Sequence::retrieve_sequence( $item, $p );
}

1;

__END__

=pod

=head1 NAME

SPOPS::DBI::Pg -- PostgreSQL-specific routines for the SPOPS::DBI

=head1 SYNOPSIS

 # In your configuration:

 'myspops' => {
     'isa' => [ qw/ SPOPS::DBI::Pg SPOPS::DBI / ],

     # If you have a SERIAL/sequence field, set increment_field to
     # true and name the sequence to be used

     'increment_field' => 1,
     'sequence_name'   => 'myseq',
     ...
 },

=head1 DESCRIPTION

This just implements some Postgres-specific routines so we
can abstract them out.

One of them optionally returns the sequence value of the just-inserted
id field. Of course, this only works if you have a the field marked as
'SERIAL' or using a sequence value in your table:

 CREATE TABLE my_table (
   id  SERIAL,
   ...
 )

B<NOTE>: You also need to let this module know if you are using this
option by setting in your class configuration the key
'increment_field' to a true value:

 $spops = {
    myobj => {
       class => 'My::Object',
       isa   => [ qw/ SPOPS::DBI::Pg  SPOPS::DBI / ],
       increment_field => 1,
       ...
    },
 };

You can also specify the sequence name in the object configuration:

 $spops = {
    myobj => {
       class => 'My::Object',
       isa   => [ qw/ SPOPS::DBI::Pg  SPOPS::DBI / ],
       increment_field => 1,
       sequence_name => 'myobject_sequence',
    },
 };

=head1 METHODS

B<sql_current_date()>

Returns 'CURRENT_TIMESTAMP()', used in PostgreSQL to return the value
for right now.

B<sql_quote( $value, $data_type, [ $db_handle ] )>

C<DBD::Pg> depends on the type of a field if you are quoting values to
put into a statement, so we override the default 'sql_quote' from
C<SPOPS::SQLInterface> to ensure the type of the field is used in the
DBI-E<gt>quote call.

The C<$data_type> should correspond to one of the DBI datatypes (see
the file 'dbi_sql.h' in your Perl library tree for more info). If the
DBI database handle C<$db_handle> is not passed in, we try to find it
with the class method C<global_db_handle()>.

B<pre_fetch_id( \%params )>

We only fetch an ID if 'increment_field' is B<NOT> set and
'sequence_name' B<IS> set in the configuration for the SPOPS object.
This enables you to retrieve an ID value from a sequence before the
insert. Although this should not make any difference to the SPOPS
user, it might make a difference to an application so the option is
here.

Auto-incrementing fields (represented by a trigger or the 'SERIAL'
datatype) are retrieved after the INSERT has been done (see
C<post_fetch_id()> below).

B<post_fetch_id( \%params )>

Retrieve the value just put into the database for the ID field. To use
this you must in the configuration for your object set
'increment_field' to a true value and either specify a 'sequence_name'
or use the SERIAL-default name of:

  <table_name>_<id_field_name>_seq

This is the sequence created by default when you use the 'SERIAL'
datatype.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::Key::DBI::Sequence|SPOPS::Key::DBI::Sequence>

L<DBD::Pg|DBD::Pg>

L<DBI|DBI>

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
