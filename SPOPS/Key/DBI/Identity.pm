package SPOPS::Key::DBI::Identity;

# $Id: Identity.pm,v 1.7 2001/06/03 22:43:34 lachoy Exp $

use strict;
use SPOPS  qw( _w DEBUG );

@SPOPS::Key::DBI::Identity::ISA      = ();
$SPOPS::Key::DBI::Identity::VERSION  = '1.7';
$SPOPS::Key::DBI::Identity::Revision = substr(q$Revision: 1.7 $, 10);

# Ensure only POST_fetch_id used

sub pre_fetch_id  { return undef }


# Retrieve the IDENTITY value

sub post_fetch_id { 
  my ( $self, $p ) = @_;
  eval { $p->{statement}->finish };
  my $sql = 'SELECT @@IDENTITY';
  my ( $sth );
  eval {
    $sth = $p->{db}->prepare( $sql );
    $sth->execute;
  };
  
  # Don't clear the error so it will persist from SELECT statement

  if ( $@ ) {   
    $SPOPS::Error::user_msg   = 'Record saved, but ID of record unknown';;
    die $SPOPS::Error::user_msg;
  }
  my $row = $sth->fetchrow_arrayref;
  DEBUG() && _w( 1, "Found inserted ID ($row->[0])" );
  return $row->[0];
}

1;

__END__

=pod

=head1 NAME

SPOPS::Key::DBI::Identity -- Retrieve IDENTITY values from a supported DBI database 

=head1 SYNOPSIS

 # In your SPOPS configuration
 $spops  = {
   'myspops' => {
       'isa' => [ qw/ SPOPS::Key::DBI::Identity  SPOPS::DBI / ],
       ...
   },
 };

=head1 DESCRIPTION

This class enables a just-created object to the IDENTITY value
returned by its last insert. Of course, this only works if you have an
IDENTITY field in your table, such as:

 CREATE TABLE my_table (
   id    NUMERIC( 8, 0 ) IDENTITY NOT NULL,
   ...
 )

This method is typically used in Sybase and Microsoft SQL Server
databases. The client library (Open Client, FreeTDS, ODBC) should not
make a difference to this module since we perform a SELECT statement
to retrieve the value rather than relying on a property of the
database/statement handle.

=head1 METHODS

B<post_fetch_id()>

Retrieve the IDENTITY value after inserting a row.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<DBD::Sybase>, L<DBI>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
