package SPOPS::DBI::MySQL;

# $Id: MySQL.pm,v 1.16 2001/01/31 02:30:44 cwinters Exp $

use strict;
use SPOPS  qw( _w );

@SPOPS::DBI::MySQL::ISA     = ();
$SPOPS::DBI::MySQL::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

sub sql_current_date  { return 'NOW()' }

sub pre_fetch_id      { return undef }

sub post_fetch_id { 
  my ( $self, $sth )  = @_;
  my $id = $sth->{mysql_insertid};
  _w( 1, "Found inserted ID ($id)" );
  return $id  if ( $id );

  my $msg = 'Record saved, but ID of record unknown';
  SPOPS::Error->set({ user_msg => $msg, type => 'db',
                      system_msg => "Cannot retrieve just-inserted ID from MySQL table $sth->{mysql_table}->[0]",
                      method => 'post_fetch_id' });
 die $msg;
}

1;

__END__

=pod

=head1 NAME

SPOPS::DBI::MySQL -- MySQL-specific code for DBI collections

=head1 SYNOPSIS

 package MySPOPS;

 @MySPOPS::ISA = qw( SPOPS::DBI::MySQL SPOPS::DBI );

=head1 DESCRIPTION

This just implements some MySQL-specific routines so we can abstract
them out.

One of these items is to return the just-inserted ID. Only works for
tables that have at least one auto-increment field:

 CREATE TABLE my_table (
   id  int not null auto_increment,
   ...
 )

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

L<DBD::mysql>, L<DBI>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
