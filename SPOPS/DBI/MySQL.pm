package SPOPS::DBI::MySQL;

# $Id: MySQL.pm,v 1.2 2001/02/20 04:36:58 lachoy Exp $

use strict;
use SPOPS::Key::DBI::HandleField;

@SPOPS::DBI::MySQL::ISA     = ();
$SPOPS::DBI::MySQL::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

sub sql_current_date  { return 'NOW()' }


# Backward compatibility (basically) -- you just have to set a true
# value in the config if you have an auto-increment field in the
# table. If so we call the post_fetch_id method from
# SPOPS::Key::DBI::HandleField.

sub post_fetch_id { 
  my ( $item, @args ) = @_;
  return undef unless ( $item->CONFIG->{increment_field} );
  $item->CONFIG->{handle_field} ||= 'mysql_insertid';
  return SPOPS::Key::DBI::HandleField::post_fetch_id( $item, @args );
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
