package SPOPS::DBI::Sybase;

# $Id: Sybase.pm,v 1.16 2001/01/31 02:30:44 cwinters Exp $

use strict;
use SPOPS  qw( _w );

@SPOPS::DBI::Sybase::ISA     = ();
$SPOPS::DBI::Sybase::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

sub sql_quote {
  my ( $class, $value, $type, $db ) = @_;
  $db ||= $class->global_db_handle;
  return $db->quote( $value, $type );
}

sub sql_current_date  { return 'GETDATE()' }

# Ensure only POST_fetch_id used

sub pre_fetch_id  { return undef }

sub post_fetch_id { 
  my ( $self, $sth, $p ) = @_;
  return unless ( $self->CONFIG->{syb_identity} );
  $sth->finish;

  my $db  = $self->global_db_handle || $p->{db};
  my $sql = 'SELECT @@IDENTITY';
  eval {
    $sth = $db->prepare( $sql );
    $sth->execute;
  };
  
 # Don't clear the error so it will persist from SELECT statement

  if ( $@ ) {   
    $SPOPS::Error::user_msg   = 'Record saved, but ID of record unknown';;
    die $SPOPS::Error::user_msg;
  }
  my $row = $sth->fetchrow_arrayref;
  _w( 1, "Found inserted ID ($row->[0])" );
  return $row->[0];
}

1;

__END__

=pod

=head1 NAME

SPOPS::DBI::Sybase -- Sybase-specific routines for the SPOPS::DBI

=head1 SYNOPSIS

 # Using a class-only defintion
 package MySPOPS;
 @MySPOPS::ISA = qw( SPOPS::DBI::Sybase SPOPS::DBI );

 # Using a config-only definition
 'myspops' => {
     'isa' => [ qw/ SPOPS::DBI::Sybase SPOPS::DBI / ],
     'syb_identity' => 1, # optional
     ...
 },

=head1 DESCRIPTION

This just implements some Sybase-specific routines so we
can abstract them out.

One of them optionally returns the IDENTITY value returned by the last
insert. Of course, this only works if you have an IDENTITY field in
your table:

 CREATE TABLE my_table (
   id    numeric( 8, 0 ) IDENTITY not null,
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

=head1 TO DO

=head1 SEE ALSO

L<DBD::Sybase>, L<DBI>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
