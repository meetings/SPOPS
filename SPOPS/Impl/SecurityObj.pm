package SPOPS::Impl::Security;

# $Id: SecurityObj.pm,v 1.24 2001/01/31 02:30:44 cwinters Exp $

use strict;
use SPOPS::Secure qw( :all );
use Data::Dumper  qw( Dumper );

$SPOPS::Impl::Security::VERSION = sprintf("%d.%02d", q$Revision: 1.24 $ =~ /(\d+)\.(\d+)/);

use constant DEBUG => 0;

# Pass in:
#  $class->fetch_match( $obj, { scope => SCOPE, scope_id => $id } );
#
# Returns
#  security object that matches the object, scope and scope_id,
#  undef if no match

sub fetch_match {
 my $class = shift;
 my $item  = shift;
 my $p     = shift;
 return undef  unless ( $p->{scope} );
 return undef  if ( $p->{scope} ne SEC_SCOPE_WORLD and ! $p->{scope_id} );

 $p->{scope_id} = 'world'  if ( $p->{scope} eq SEC_SCOPE_WORLD );

 my ( $obj_class, $oid ) = $class->_get_class_and_oid( { %{ $p }, item => $item } );
 
 warn "Try to find match for $obj_class ($oid) ", "scope $p->{scope} ($p->{scope_id})\n";
 my $where  = " class = ? AND oid = ? AND scope = ? AND scope_id = ? ";
 my @values = ( $obj_class, $oid, $p->{scope}, $p->{scope_id} );

 # Note that we want to keep most of the db settings from SQLInterface
 # if there's an error, so we just override the user_msg with the
 # canned error message below.

 my $row = eval { $class->db_select( { select => [ $class->id_field ],
                                       from   => [ $class->table_name ],
                                       where  => $where, 
				       value  => \@values,
                                       return => 'single' } ); };
 my $error_msg = 'Failure when retrieving existing security settings';
 if ( $@ ) {
   $SPOPS::Error::user_msg = $error_msg;
   die $SPOPS::Error::user_msg;
 }
 return undef unless ( $row->[0] );
 my $obj =  eval { $class->fetch( $row->[0] ) };
 if ( $@ ) {
   $SPOPS::Error::user_msg = $error_msg;
   die $SPOPS::Error::user_msg;
 }
 return $obj;
}


# Pass in: 
#  $class->fetch_by_object( $obj, { user  => $user_obj,
#                                   group => [ $group_obj, $group_obj, ... ] } );
#
# Returns:
#  hashref with world, group, user as keys (set to SEC_LEVEL_WORLD, ... ?)
#  and permissions as values; group set to hashref (gid => level)
#  while world/user are scalars. Note that even if you restrict the results to
#  a user and/or groups, you will always get a result back for WORLD.

sub fetch_by_object {
 my $class = shift;
 my $item  = shift;
 my $p     = shift;
 unless ( $item or ( $p->{class} and $p->{oid} ) ) {
   my $msg = 'Cannot check security';
   warn "--Cannot retrieve security since no item passed in to check!\n";
   SPOPS::Error->set( { user_msg => $msg, type => 'security',
                        system_msg => 'No item passed into SecurityObj/fetch_by_object to check!',
                        method => 'fetch_by_object' } );
   die $msg;
 }

 my ( $obj_class, $oid ) = $class->_get_class_and_oid( { %{ $p }, item => $item } );

 my $where = 'class = ? AND oid = ? AND ( scope = ?';
 my @value = ( $obj_class, $oid, SEC_SCOPE_WORLD ); 

 my ( $group_where, $user_where );

 # Setup the SQL for the groups passed in

 # Include the overall group clause unless
 # we specified we want 'none' of the groups

 if ( $p->{group} and $p->{group} ne 'none' ) {
   $group_where = ' ( scope = ? ';
   push @value, SEC_SCOPE_GROUP;
 }

 # Only specify the actual groups we want if
 # $p->{group} is either a group object or an 
 # arrayref of group objects

 if ( ref $p->{group} ) {
   my $group_list = ( ref $p->{group} eq 'ARRAY' ) ? $p->{group} : [ $p->{group} ];
   if ( scalar @{ $group_list } ) {
	 warn scalar @{ $group_list }, " groups found passed in";
	 $group_where .= ' AND ( ';
	 foreach my $group ( @{ $group_list } ) {	 
	   next if ( ! $group );
	   $group_where .= ' scope_id = ? OR ';
	   my $gid = ( ref $group ) ? $group->id : $group;
	   push @value, $gid;
	 }
	 $group_where =~ s/ OR $/\) /;   
	 $group_where =~ s/AND \(\s*$//;
   }   
 }
 $group_where .= ' ) '  if ( $group_where );
 warn "Group WHERE clause: { $group_where }";

 # Setup the SQL for the user passed in
 #
 # Note that we can only do one user at a time unless
 # we specifically pass the 'all' parameter

 my $multiple_user = 0;
 if ( $p->{user} ) { 
   $user_where = ' ( scope = ? ';
   push @value, SEC_SCOPE_USER;
   if ( $p->{user} ne 'all' ) {     
     $user_where .= ' AND scope_id = ? ';
     my $uid = ( ref $p->{user} ) ? $p->{user}->id : $p->{user};
     push @value, $uid;
   }
   else {
     $multiple_user++;
   }
 }
 $user_where .= ')'     if  ( $user_where );
 warn "User WHERE clause: { $user_where }";

 # Now setup the final statement with all the
 # scope clauses put in

 $where .= " OR $group_where "  if ( $group_where );
 $where .= " OR $user_where  "  if ( $user_where );
 $where .= ')';
 warn "Searching clause: $where\nwith values ", join( '//', @value );
 
 # Fetch the objects

 my $sec_list = eval { $class->fetch_group( { where => $where, value => \@value } ) };
 if ( $@ ) {
   $SPOPS::Error::user_msg = 'Cannot retrieve security settings';
   die $SPOPS::Error::user_msg;
 }

 # Setup a hashref where w/u => level and g points to a hashref where
 # the key is the group_id value is the security level.

 my %items = ( SEC_SCOPE_WORLD() => undef, 
               SEC_SCOPE_USER()  => undef,
               SEC_SCOPE_GROUP() => {} );
 my $found_item = 0;
ITEM:
 foreach my $sec ( @{ $sec_list } ) {
   $found_item++;
   if ( $sec->{scope} eq SEC_SCOPE_WORLD ) {
	 $items{ $sec->{scope} } = $sec->{level};
	 warn "Assign $sec->{level} to $sec->{scope}";
   }
   elsif ( $sec->{scope} eq SEC_SCOPE_USER and ! $multiple_user ) {
	 $items{ $sec->{scope} } = $sec->{level};
	 warn "Assign $sec->{level} to $sec->{scope}";
   }
   else {
     $items{ $sec->{scope} }->{ $sec->{scope_id} } = $sec->{level};
     warn "Assign $sec->{level} to $sec->{scope}/$sec->{scope_id}";
   }
 }
 warn "All security: ", Dumper( \%items );
 return undef unless ( $found_item );
 return \%items;
}

sub _get_class_and_oid {
 my $class = shift;
 my $p     = shift;
 # Assume it's a class we're passed in to check

 my $obj_class = $p->{class} || $p->{item};
 my $oid       = $p->{oid} || '0';

 # If this is an object, modify lines accordingly

 if ( ref $p->{item} ) {
   $oid        = $p->{item}->id;
   $obj_class  = ref $p->{item};
 }
 return ( $obj_class, $oid );
}

1;

__END__

=pod

=head1 NAME

SPOPS::Impl::Security - Implement a security object and basic operations

=head1 SYNOPSIS

 use SPOPS::Secure qw( :all );
 my $sec_class = 'SPOPS::Impl::Security';

 # Create a security object with level WRITE
 # for user $user on object $obj
 my $sec = $sec_class->new();
 $sec->{class}    = ref $obj;
 $sec->{oid}      = $obj->id;
 $sec->{scope}    = SEC_SCOPE_USER;
 $sec->{scope_id} = $user->id;
 $sec->{level}    = SEC_LEVEL_WRITE;
 $sec->save;

 # Clone that object and change its scope to 
 # GROUP and level to READ
 my $secg = $sec->clone( scope => SEC_SCOPE_GROUP, 
                         scope_id => $group->id,
                         level => SEC_LEVEL_READ );
 $secg->save;

=head1 DESCRIPTION

This class works a little behind-the-scenes, so you probably will
not deal directly with it very much. Instead, check out L<SPOPS::Secure>
for module developer (and other) information.

Each security setting to an object is itself an object. In this manner
we can use the SPOPS framework to create/edit/remove security
settings. (Note that if you modify the 'SPOPS::Impl::SecurityObj'
class to use 'SPOPS::Secure' in its @ISA, you will probably collapse
the Earth -- or at least your system -- in a self-referential object
definition cycle. Do not do that.)

=head1 METHODS

B<fetch_match( $obj, scope => SCOPE, scope_id => $ );

Returns a security object matching the $obj for the scope 
and scope_id passed in, undef if none found.

Examples:

 my $sec_class = 'SPOPS::Impl::SecurityObj';

 # Returns security object matching $obj with a scope of WORLD
 my $secw = $sec_class->fetch_match( $obj, scope => SEC_SCOPE_WORLD );

 # Returns security object matching $obj with a scope of GROUP
 # matching the ID from $group
 my $secg = $sec_class->fetch_match( $obj, scope => SEC_SCOPE_GROUP,
                                     scope_id => $group->id );

 # Returns security object matching $obj with a scope of USER
 # matching the ID from $user
 my $secg = $sec_class->fetch_match( $obj, scope => SEC_SCOPE_USER,
                                     scope_id => $user->id );

B<fetch_by_object( $obj, { user => \@, group => \@ ... } )>

Returns a hashref with security information for a particular
object. The keys of the hashref are SEC_SCOPE_WORLD, 
SEC_SCOPE_USER, and SEC_SCOPE_GROUP as exported by SPOPS::Secure. 

You can restrict the security returned for USER and/or GROUP by
passing a hashref of objects or ID values under the 'user' or 'group'
keys.

You can also pass in a 'class' and 'oid' value to use that for the
object identifier for the lookup.

Examples:

 my \%info = $sec->fetch_by_object( $obj );

Returns all security information for $obj.

 my \%info = $sec->fetch_by_object( $obj, { user => [ 1, 2, 3 ] } );

Returns $obj security information for WORLD, all GROUPs but
only USERs with ID 1, 2 or 3.

 my \%info = $sec->fetch_by_object( $obj, { user => [ 1, 2, 3 ],
                                            group => [ 817, 901, 716 ] } );

Returns $obj security information for WORLD, USERs 1, 2 and 3
and GROUPs 817, 901, 716.

=head1 TO DO

=head1 BUGS

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
