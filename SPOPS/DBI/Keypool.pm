package SPOPS::DBI::Keypool;

# $Id: Keypool.pm,v 1.16 2001/01/31 02:30:44 cwinters Exp $

use strict;
use SPOPS qw( _w );

@SPOPS::DBI::Keypool::ISA     = ();
$SPOPS::DBI::Keypool::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

# Ensure only PRE_fetch_id works.

sub post_fetch_id { return undef }

sub pre_fetch_id  {
  my ( $class, $p ) = @_;
  my $db    = $p->{db} || $class->global_db_handle;

  my $table = $class->key_table;
  unless ( $table ) {
    my $msg   = 'Cannot retrieve ID to insert record';
    SPOPS::Error->set( { user_msg => $msg, type => 'db',
                         system_msg => "No table specified using class $class",
                         method => 'pre_fetch_id', type => 'db' } );
    die $msg;
  }
  
  my $loc   = $class->global_config->{replication_location};
  unless ( $loc ) {
    my $msg   = 'Cannot retrieve ID to insert record';
    SPOPS::Error->set( { user_msg => $msg, type => 'db',
                         system_msg => "No location specified using class $class and table $table",
                         method => 'pre_fetch_id' } );
    die $msg;
  }
 _w( 1, "Getting ID w/ <<$table>> and <<$loc>>" );

 $table = $db->quote( $table );
 $loc   = $db->quote( $loc );
 my $row = eval { $class->db_select({
                             sql => qq(exec new_key $table, $loc), 
                             return => 'single' }) };
  if ( $@ ) { 
    $SPOPS::Error::user_msg = 'Cannot retrieve ID to insert record';
    die $SPOPS::Error::user_msg;
  }   
  _w( 1, "Returned <<$row->[0]>> for ID" );
  return $row->[0];
}

1;

__END__

=pod

=head1 NAME

SPOPS::DBI::Keypool -- Retrieves ID field information from a pool

=head1 SYNOPSIS

 package MySPOPS;

 @MySPOPS::ISA = qw( SPOPS::DBI::Keypool SPOPS::DBI );

=head1 DESCRIPTION

This module retrieves a value from a pool of key values 
matched up to tables. It is not as fast as IDENTITY fields, 
auto_incrementing values or sequences, but it is portable
among databases and, most importantly, works in a replicated
environment. It also has the benefit of being fairly simple 
to understand.

Currently, the key fetching procedure is implemented via a
stored procedure for portability among tools in different
languages, but it does not have to remain this way. It is 
perfectly feasible to program the entire procedure in perl.

=head1 BUGS

B<Put this class before others in ISA>

Not really a bug, but you must put this class before any
database-specific ones in your @ISA, otherwise you will not see 
the results of this class and likely get very confused.

=head1 TO DO

B<Make option for perl implementation>

Allow authors to use a perl implementation of a key pool rather than
relying on a stored procedure (particularly for those databases
without stored procedures...).

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>


=cut
