package SPOPS::Key::DBI::Pool;

# $Id: Pool.pm,v 2.0 2002/03/19 04:00:03 lachoy Exp $

use strict;
use SPOPS qw( _w DEBUG );

$SPOPS::Key::DBI::Pool::VERSION  = substr(q$Revision: 2.0 $, 10);


# Ensure only PRE_fetch_id works.

sub post_fetch_id { return undef }

sub pre_fetch_id  {
    my ( $class, $p ) = @_;

    my $pool_sql = eval { $class->CONFIG->{pool_sql} };
    unless ( $pool_sql ) {
        SPOPS::Exception->throw( "Cannot retrieve pool value; no SQL specified " .
                                 "in key 'pool_sql'" );
    }
    DEBUG() && _w( 1, "Getting ID with SQL:\n$pool_sql" );

    my $params = { sql => $pool_sql, db => $p->{db} };
    my $values = eval { $class->CONFIG->{pool_value} };
    my $quote  = eval { $class->CONFIG->{pool_quote} };

    if ( $values ) {
        my $value_type = ref $values;
        if ( $value_type ne 'ARRAY' and $value_type ) {
            SPOPS::Exception->throw( "Cannot retrieve pool value; key 'pool_value' " .
                                     "must be scalar or arrayref" );
        }

        my $list_values = ( $value_type eq 'ARRAY' ) ? $values : [ $values ];
        if ( $quote ) {
            $params->{sql} = sprintf( $params->{sql}, @{ $list_values } );
        }
        else {
            $params->{value} = $list_values;
        }
    }

    $params->{return} = 'single';
    my $row = SPOPS::SQLInterface->db_select( $params );
    DEBUG() && _w( 1, "Returned <<$row->[0]>> for ID" );
    return $row->[0];
}

1;

__END__

=pod

=head1 NAME

SPOPS::Key::DBI::Pool -- Retrieves ID field information from a pool

=head1 SYNOPSIS

 # In your configuration file

 # Bind the value 'unique_value' to the field 'table'

 my $spops = {
   isa => [ qw/ SPOPS::Key::DBI::Pool SPOPS::DBI / ],
   pool_sql   => 'select my_key from key_pool where table = ?',
   pool_value => [ 'unique_value' ],
   ...
 };


 # Use the values 'unique_value' and 'my_location' but use quoting
 # rather than binding (some DBDs don't let you use bound values with
 # stored procedures)

 my $spops = {
   isa => [ qw/ SPOPS::Key::DBI::Pool SPOPS::DBI / ],
   pool_sql   => 'exec new_key %s, %s',
   pool_value => [ 'unique_value', 'my_location' ],
   pool_quote => 1,
   ...
 };

=head1 DESCRIPTION

This module retrieves a value from a pool of key values matched up to
tables. It is not as fast as IDENTITY fields
(L<SPOPS::Key::DBI::Identity|SPOPS::Key::DBI::Identity>,
auto_incrementing values or sequences, but can be portable among
databases and, most importantly, works in a replicated environment. It
also has the benefit of being fairly simple to understand.

Currently, the key fetching procedure is implemented via a
stored procedure for portability among tools in different
languages, but it does not have to remain this way. It is 
perfectly feasible to program the entire procedure in perl.

=head1 BUGS

B<Put this class before others in ISA>

Not really a bug, but you must put this class before any
database-specific ones (like 'SPOPS::DBI::Sybase' or whatnot) in your
@ISA, otherwise this class will not be able to do its work.

=head1 TO DO

It might be a good idea to subclass this with a pure Perl solution.

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
