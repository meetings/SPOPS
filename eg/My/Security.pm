package My::Security;

# $Id: Security.pm,v 2.1 2002/04/26 15:35:22 lachoy Exp $

use strict;
use Data::Dumper  qw( Dumper );
use SPOPS         qw( DEBUG );
use SPOPS::Initialize;
use SPOPS::Secure qw( :level :scope );

$My::Security::VERSION = sprintf("%d.%02d", q$Revision: 2.1 $ =~ /(\d+)\.(\d+)/);

use constant DEBUG => 0;

sub _base_config {
    my $config = {
       'security' => {
           class        => 'My::Security',
           isa          => [ 'My::Common' ],
           rules_from   => [ 'SPOPS::Tool::DBI::DiscoverField' ],
           field_discover => 'yes',
           field        => [],
           id_field     => 'sid',
           increment_field => 1,
           sequence_name => 'sp_security_seq',
           no_insert    => [ qw/ sid / ],
           skip_undef   => [ qw/ object_id scope_id / ],
           no_update    => [ qw/ sid object_id class scope scope_id / ],
           base_table   => 'spops_security',
           sql_defaults => [ qw/ object_id scope_id / ],
           alias        => [],
           has_a        => {},
           links_to     => {},
           skip_object_key => 1,
       },
    };
    return $config;
}

sub config_class {
    SPOPS::Initialize->process({ config => [ _base_config() ] });
}

&config_class;


# Pass in:
#  $class->fetch_by_object( $obj, [ { user  => $user_obj,
#                                     group => \@( $group_obj, $group_obj, ... ) } ] );
#
# Returns:
#  hashref with world, group, user as keys (set to SEC_LEVEL_WORLD, ... ?)
#  and permissions as values; group set to hashref (gid => security_level)
#  while world/user are scalars. Note that even if you restrict the results to
#  a user and/or groups, you will always get a result back for WORLD.

sub fetch_by_object {
    my ( $class, $item, $p ) = @_;
    my $object_id = $p->{oid} || $p->{object_id};
    unless ( $item or ( $p->{class} and defined $object_id ) ) {
        my $msg = 'Cannot check security';
        warn " -- Cannot retrieve security since no item passed in to check!\n";
        SPOPS::Exception->throw( 'No item defined to check security for' );
    }

    my ( $obj_class, $oid ) = $class->_get_class_and_oid({
                                          %{ $p },
                                          object_id => $object_id,
                                          item      => $item } );

    my $where = 'class = ? AND object_id = ? AND ( scope = ?';
    my @value = ( $obj_class, $oid, SEC_SCOPE_WORLD );

    # Setup the group and user search clauses

    my ( $group_where, $group_value ) = $class->_build_group_sql( $p );
    if ( $group_where )             { $where .= " OR $group_where " }
    if ( scalar @{ $group_value } ) { push @value, @{ $group_value } }

    my ( $user_where, $user_value )   = $class->_build_user_sql( $p );
    if ( $user_where )              { $where .= " OR $user_where  " }
    if ( scalar @{ $user_value } )  { push @value, @{ $user_value } }

    $where .= ')';
    DEBUG && warn "Searching clause: $where\nwith values ", join( '//', @value ), "\n";

    # Fetch the objects

     my $sec_list = $class->fetch_group({ where => $where,
                                          value => \@value });

    # Setup a hashref where w/u => security_level and g points to a
    # hashref where the key is the group_id value is the security level.

    my %items = ( SEC_SCOPE_WORLD() => undef,
                  SEC_SCOPE_USER()  => undef,
                  SEC_SCOPE_GROUP() => {} );
    my $found_item = 0;
ITEM:
    foreach my $sec ( @{ $sec_list } ) {
        $found_item++;
        if ( $sec->{scope} eq SEC_SCOPE_WORLD || $sec->{scope} eq SEC_SCOPE_USER ) {
            $items{ $sec->{scope} } = $sec->{security_level};
            DEBUG && warn "Assign $sec->{security_level} to $sec->{scope}\n";
        }
        elsif ( $sec->{scope} eq SEC_SCOPE_GROUP ) {
            $items{ $sec->{scope} }->{ $sec->{scope_id} } = $sec->{security_level};
            DEBUG && warn "Assign $sec->{security_level} to $sec->{scope}/$sec->{scope_id}\n";
        }
    }
    DEBUG && warn "All security: ", Dumper( \%items ), "\n";
    return undef unless ( $found_item );
    return \%items;
}


# Setup the SQL for the groups passed in

sub _build_group_sql {
    my ( $class, $p ) = @_;

    # See if we were actually given any groups or the instruction to
    # get ALL group security

    my $num_groups = ( ref $p->{group} eq 'ARRAY' )
                       ? scalar @{ $p->{group} } : 0;
    unless ( $num_groups or $p->{group} eq 'all' ) {
        DEBUG && warn "No groups passed in, returning empty info\n";
        return ( undef, [] );
    }

    # Include the overall group clause unless we specified we want
    # 'none' of the groups

    my $where = ' ( scope = ? ';
    my @value = ( SEC_SCOPE_GROUP );

  # Only specify the actual groups we want if $p->{group} is either a
  # group object or an arrayref of group objects

    if ( ref $p->{group} ) {
        my $group_list = ( ref $p->{group} eq 'ARRAY' )
                           ? $p->{group} : [ $p->{group} ];
        if ( scalar @{ $group_list } ) {
            DEBUG && warn scalar @{ $group_list }, " groups found passed in\n";
            $where .= ' AND ( ';
            foreach my $group ( @{ $group_list } ) {
                next unless ( $group );
                $where .= ' scope_id = ? OR ';
                my $gid = ( ref $group ) ? $group->id : $group;
                push @value, $gid;
            }
            $where =~ s/ OR $/\) /;
            $where =~ s/AND \(\s*$//;
        }
    }
    $where .= ' ) '  if ( $where );
    DEBUG && warn "Group WHERE clause: { $where }\n";
    return ( $where, \@value );
}


# Setup the SQL for the user passed in

sub _build_user_sql {
    my ( $class, $p ) = @_;
    my ( $where );
    my ( @value );
    return ( $where, \@value ) unless ( $p->{user} );

    # Note that we can only do one user at a time. The caller of this
    # routine should ensure that $p->{user} is a single user object or
    # user_id.

    my $uid = ( ref $p->{user} ) ? $p->{user}->id : $p->{user};
    $where = ' ( scope = ? AND scope_id = ? )';
    push @value, SEC_SCOPE_USER, $uid;

    DEBUG && warn "User WHERE clause: { $where }\n";
    return ( $where, \@value );
}


# Pass in:
#  $class->fetch_match( $obj, { scope => SCOPE, scope_id => $id } );
#
# Returns
#  security object that matches the object, scope and scope_id,
#  undef if no match

sub fetch_match {
    my ( $class, $item, $p ) = @_;
    return undef  unless ( $p->{scope} );
    return undef  if ( $p->{scope} ne SEC_SCOPE_WORLD and ! $p->{scope_id} );

    $p->{scope_id} = 'world'  if ( $p->{scope} eq SEC_SCOPE_WORLD );

    my ( $obj_class, $oid ) = $class->_get_class_and_oid( { %{ $p }, item => $item } );

    DEBUG && warn "Try to find match for $obj_class ($oid) ",
                  "scope $p->{scope} ($p->{scope_id})\n";
    my $where  = " class = ? AND object_id = ? AND scope = ? AND scope_id = ? ";
    my @values = ( $obj_class, $oid, $p->{scope}, $p->{scope_id} );

    # Note that we want to keep most of the db settings from SQLInterface
    # if there's an error, so we just override the user_msg with the
    # canned error message below.

    my $row = $class->db_select({ select => [ $class->id_field ],
                                  from   => [ $class->table_name ],
                                  where  => $where,
                                  value  => \@values,
                                  return => 'single' });
    return undef unless ( $row->[0] );
    return $class->fetch( $row->[0] );
}


sub _get_class_and_oid {
    my ( $class, $p ) = @_;

    # Assume it's a class we're passed in to check

    my $obj_class = $p->{class} || $p->{item};
    my $oid       = $p->{object_id} || $p->{oid} || '0';

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

My::Security - Implement a security object and basic operations

=head1 SYNOPSIS

 use My::Security;
 use SPOPS::Secure qw( :all );

 # Create a security object with security level WRITE for user $user
 # on object $obj

 my $sec = My::Security->new();
 $sec->{class}          = ref $obj;
 $sec->{object_id}      = $obj->id;
 $sec->{scope}          = SEC_SCOPE_USER;
 $sec->{scope_id}       = $user->id;
 $sec->{security_level} = SEC_LEVEL_WRITE;
 $sec->save;

 # Clone that object and change its scope to GROUP and level to READ

 my $secg = $sec->clone({ scope          => SEC_SCOPE_GROUP,
                          scope_id       => $group->id,
                          security_level => SEC_LEVEL_READ });
 $secg->save;

 # Find security settings for a particular object ($spops) and user

 my $settings = My::Security->fetch_by_object(
                                        $spops,
                                        { user => [ $user ] } );
 foreach my $scope ( keys %{ $settings } ) {
   print "Security for scope $scope: $settings{ $scope }\n";
 }

 # See if there are any security objects protecting a particular SPOPS
 # object ($spops) related to a particular user (this isn't used as
 # often as 'fetch_by_object')

 use SPOPS::Secure qw( SEC_SCOPE_USER );

 my $sec_obj = My::Security->fetch_match( $spops,
                                          { scope    => SEC_SCOPE_USER,
                                            scope_id => $user->id } );

=head1 DESCRIPTION

This class works a little behind-the-scenes, so you probably will not
deal directly with it very much. Instead, check out
L<SPOPS::Secure|SPOPS::Secure> for module developer (and other)
information.

Each security setting to an object is itself an object. In this manner
we can use the SPOPS framework to create/edit/remove security
settings. (Note that if you modify this class to use 'SPOPS::Secure'
in its @ISA, you will probably collapse the Earth -- or at least your
system -- in a self-referential object definition cycle. Do not do
that.)

=head1 METHODS

B<fetch_match( $obj, { scope => SCOPE, scope_id => $ } );

Returns a security object matching the $obj for the scope and scope_id
passed in, undef if none found.

Examples:

 my $sec_class = 'My::Security';

 # Returns security object matching $obj with a scope of WORLD

 my $secw = $sec_class->fetch_match( $obj,
                                     { scope => SEC_SCOPE_WORLD } );

 # Returns security object matching $obj with a scope of GROUP
 # matching the ID from $group
 my $secg = $sec_class->fetch_match( $obj,
                                     { scope    => SEC_SCOPE_GROUP,
                                       scope_id => $group->id } );

 # Returns security object matching $obj with a scope of USER
 # matching the ID from $user
 my $secg = $sec_class->fetch_match( $obj, scope => SEC_SCOPE_USER,
                                     scope_id => $user->id );

B<fetch_by_object( $obj, [ { user => \@, group => \@ } ] )>

Returns a hashref with security information for a particular
object. The keys of the hashref are SEC_SCOPE_WORLD, 
SEC_SCOPE_USER, and SEC_SCOPE_GROUP as exported by SPOPS::Secure. 

You can restrict the security returned for USER and/or GROUP by
passing an arrayref of objects or ID values under the 'user' or
'group' keys.

Examples:

 my \%info = $sec->fetch_by_object( $obj );

Returns all security information for $obj.

 my \%info = $sec->fetch_by_object( $obj, { user => [ 1, 2, 3 ] } );

Returns $obj security information for WORLD, all GROUPs but
only USERs with ID 1, 2 or 3.

 my \%info = $sec->fetch_by_object( $obj, { user  => [ 1, 2, 3 ],
                                            group => [ 817, 901, 716 ] } );

Returns $obj security information for WORLD, USERs 1, 2 and 3
and GROUPs 817, 901, 716.

=head1 TO DO

Nothing known.

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
