package SPOPS::DBI::Sybase;

# $Id: Sybase.pm,v 2.0 2002/03/19 04:00:01 lachoy Exp $

use strict;
use SPOPS::Key::DBI::Identity;

$SPOPS::DBI::Sybase::VERSION  = substr(q$Revision: 2.0 $, 10);

sub sql_quote {
    my ( $class, $value, $type, $db ) = @_;
    $db ||= $class->global_db_handle;
    return $db->quote( $value, $type );
}

sub sql_current_date  { return 'GETDATE()' }


# Backward compatibility and convenience, so you don't have to specify
# another item in the isa -- instead just set 'syb_identity' or
# 'increment_field' to true.

sub post_fetch_id { 
    my ( $item, @args ) = @_;
    return undef unless ( $item->CONFIG->{increment_field} or $item->CONFIG->{syb_identity} );
    return SPOPS::Key::DBI::Identity::post_fetch_id( $item, @args );
}


1;

__END__

=pod

=head1 NAME

SPOPS::DBI::Sybase -- Sybase-specific routines for the SPOPS::DBI

=head1 SYNOPSIS

 # In your configuration:

 'myspops' => {
     'isa' => [ qw/ SPOPS::DBI::Sybase SPOPS::DBI / ],

     # If you have an IDENTITY field, set syb_identity to true
     'syb_identity' => 1,
     ...
 },

=head1 DESCRIPTION

This just implements some Sybase-specific routines so we
can abstract them out.

One of them optionally returns the IDENTITY value returned by the last
insert. Of course, this only works if you have an IDENTITY field in
your table:

 CREATE TABLE my_table (
   id  numeric( 8, 0 ) IDENTITY not null,
   ...
 )

B<NOTE>: You also need to let this module know if you are using this
IDENTITY option by setting in your class configuration the key
'syb_identity' to a true value.

=head1 METHODS

B<sql_quote>

C<DBD::Sybase> depends on the type of a field if you are quoting
values to put into a statement, so we override the default 'sql_quote'
from C<SPOPS::SQLInterface> to ensure the type of the field is used in
the DBI-E<gt>quote call.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::Key::DBI::Identity|SPOPS::Key::DBI::Identity>

L<DBD::Sybase|DBD::Sybase>

L<DBI|DBI>

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

See the L<SPOPS|SPOPS> module for the full author list.

=cut
