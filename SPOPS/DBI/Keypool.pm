package SPOPS::DBI::Keypool;

# $Header: /usr/local/cvsdocs/SPOPS/SPOPS/DBI/Keypool.pm,v 1.13 2000/10/27 04:05:45 cwinters Exp $

use strict;

@SPOPS::DBI::Keypool::ISA     = ();
$SPOPS::DBI::Keypool::VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

use constant DEBUG => 0;

# Ensure only PRE_fetch_id works.
sub post_fetch_id { return undef }

sub pre_fetch_id  {
 my $class = shift;
 my $p     = shift;
 my $db    = $p->{db} || $class->global_db_handle;

 my $table = $class->key_table;
 if ( ! $table ) {
   my $msg   = 'Cannot retrieve ID to insert record';
   SPOPS::Error->set( { user_msg => $msg, type => 'db',
                        system_msg => "No table specified using class $class",
                        method => 'pre_fetch_id', type => 'db' } );
   die $msg;
 }

 my $loc   = $class->global_config->{replication_location};
 if ( ! $loc ) {
   my $msg   = 'Cannot retrieve ID to insert record';
   SPOPS::Error->set( { user_msg => $msg, type => 'db',
                        system_msg => "No location specified using class $class and table $table",
                        method => 'pre_fetch_id' } );
   die $msg;
 }
 warn " (Keypool/pre_fetch_id): Getting ID w/ <<$table>> and <<$loc>>\n"   if ( DEBUG );

 $table = $db->quote( $table );
 $loc   = $db->quote( $loc );
 my $row = eval { $class->db_select( sql => qq(exec new_key $table, $loc), return => 'single' ); };
 if ( $@ ) { 
   $SPOPS::Error::user_msg = 'Cannot retrieve ID to insert record';
   die $SPOPS::Error::user_msg;
 }   
 warn " (Keypool/pre_fetch_id): Returned <<$row->[0]>> for ID\n"           if ( DEBUG );
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

Copyright (c) 2000 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <cwinters@intes.net>


=cut
