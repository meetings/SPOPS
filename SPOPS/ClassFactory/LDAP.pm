package SPOPS::ClassFactory::LDAP;

# $Id: LDAP.pm,v 1.12 2001/08/27 15:18:07 lachoy Exp $

use strict;
use SPOPS qw( _w DEBUG );
use SPOPS::ClassFactory qw( OK ERROR DONE );

@SPOPS::ClassFactory::LDAP::ISA      = ();
$SPOPS::ClassFactory::LDAP::VERSION  = '1.8';
$SPOPS::ClassFactory::LDAP::Revision = substr(q$Revision: 1.12 $, 10);


########################################
# BEHAVIOR: has_a
########################################

my $generic_hasa = <<'HASA';

    sub %%CLASS%%::%%HASA_ALIAS%% {
        my ( $self, $p ) = @_;
        die "Cannot call from unsaved object or class!" unless ( $self->dn );
        my @object_list = ();
        my $conf_other = %%HASA_CLASS%%->CONFIG;
        my $hasa_value = $self->{%%HASA_FIELD%%};
        $hasa_value = ( ref $hasa_value eq 'ARRAY' ) ? $hasa_value : [ $hasa_value ];
        foreach my $other_dn ( @{ $hasa_value } ) {
            SPOPS::_wm( 1, $p->{DEBUG}, "Trying to retrieve linked %%HASA_ALIAS%% with DN ($other_dn)" );
            my $object = %%HASA_CLASS%%->fetch_by_dn( $other_dn );
            push @object_list, $object if ( $object );
        }
        return \@object_list;
    }
HASA


# Process the 'has_a' aliases -- pretty straightforward (see pod)

sub conf_relate_has_a {
    my ( $class ) = @_;

    my $config = $class->CONFIG;
    my $has_a = $config->{has_a};
    return ( OK, undef ) unless ( $has_a and ref $has_a eq 'HASH' );

    foreach my $hasa_class ( keys %{ $has_a } ) {
        my $field_list = ( ref $has_a->{ $hasa_class } eq 'ARRAY' )
                           ? $has_a->{ $hasa_class }
                           : [ $has_a->{ $hasa_class } ];
        my $hasa_config   = $hasa_class->CONFIG;
        my $hasa_alias    = $hasa_config->{main_alias};
        foreach my $hasa_field ( @{ $field_list } ) {
            my $hasa_sub = $generic_hasa;
            $hasa_sub =~ s/%%CLASS%%/$class/g;
            $hasa_sub =~ s/%%HASA_CLASS%%/$hasa_class/g;
            $hasa_sub =~ s/%%HASA_ALIAS%%/$hasa_alias/g;
            $hasa_sub =~ s/%%HASA_FIELD%%/$hasa_field/g;
            DEBUG() && _w( 2, "Now going to eval the routine:\n$hasa_sub" );
            {
                local $SIG{__WARN__} = sub { return undef };
                eval $hasa_sub;
            }
            if ( $@ ) {
                return ( ERROR, "Cannot create 'has_a' routine in ($class): $@" );
            }
        }
    }
    DEBUG() && _w( 1, "Finished adding LDAP has_a relationships for ($class)" );
    return ( DONE, undef );
}


########################################
# BEHAVIOR: links_to
########################################

# EVAL'D SUBROUTINES

my $generic_linksto = <<'LINKSTO';

    sub %%CLASS%%::%%LINKSTO_ALIAS%% {
        my ( $self ) = @_;
        my $filter = "(%%LINKSTO_FIELD%%=" . $self->dn . ")";
        return %%LINKSTO_CLASS%%->fetch_group({ filter => $filter });
    }


    sub %%CLASS%%::%%LINKSTO_ALIAS%%_add {
        my ( $self, $link_id_list, $p ) = @_;

        # Allow user to pass only one ID to add (scalar) or an arrayref (ref)

        $link_id_list  = ( ref $link_id_list ) ? $link_id_list : [ $link_id_list ];
        my $link_dn    = $self->dn;
        my $added      = 0;
        my @error_list = ();

LINK_ITEM:
        foreach my $link_id ( @{ $link_id_list } ) {
            SPOPS::_wm( 1, $p->{DEBUG}, "Trying to add link to ID ($link_id)" );

            # First fetch the thing we're linking to

            my $link_to = eval { %%LINKSTO_CLASS%%->fetch( $link_id, $p ) };
            if ( $@ or ! $link_to ) {
               my $err = ( $@ ) ? $SPOPS::Error::system_msg : 'Object not found';
               push @error_list, "Could not fetch link object with ID ($link_id)\n" .
                                 "Error: $err";
               next LINK_ITEM;
            }

            # Now add the DN for the linker -- this should work
            # whether it's multivalue or not

            $link_to->{%%LINKSTO_FIELD%%} = $link_dn;
            eval { $link_to->save( $p ) };
            if ( $@ ) {
                push @error_list, "Could not save link object ($link_id)\n" .
                                  "Error: $@ / $SPOPS::Error::system_msg";
            }
            else {
                $added++;
            }
        }
        if ( scalar @error_list ) {
            $SPOPS::Error::system_msg = join "\n\n", @error_list;
            die 'Add %%LINKSTO_ALIAS%% failed for one or more items';
        }
        return $added;
    }


    sub %%CLASS%%::%%LINKSTO_ALIAS%%_remove {
        my ( $self, $link_id_list, $p ) = @_;

        # Allow user to pass only one ID to add (scalar) or an arrayref (ref)

        $link_id_list  = ( ref $link_id_list ) ? $link_id_list : [ $link_id_list ];
        my $link_dn    = $self->dn;
        my $removed    = 0;
        my @error_list = ();

LINK_ITEM:
        foreach my $link_id ( @{ $link_id_list } ) {
            SPOPS::_wm( 1, $p->{DEBUG}, "Trying to remove link to ID ($link_id)" );

            # First fetch the thing we're removing the link from

            my $link_to = eval { %%LINKSTO_CLASS%%->fetch( $link_id, $p ) };
            if ( $@ or ! $link_to ) {
               my $err = ( $@ ) ? $SPOPS::Error::system_msg : 'Object not found';
               push @error_list, "Could not fetch link object with ID ($link_id)\n" .
                                 "Error: $err";
               next LINK_ITEM;
            }

            # Now remove the DN for the linker

            my $current_value = $link_to->{%%LINKSTO_FIELD%%};
            if ( ref $current_value ) {
                $link_to->{%%LINKSTO_FIELD%%} = { remove => $link_dn };
            }
            else {
                $link_to->{%%LINKSTO_FIELD%%} = undef;
            }
            eval { $link_to->save( $p ) };
            if ( $@ ) {
                push @error_list, "Could not save link object ($link_id)\n" .
                                  "Error: $SPOPS::Error::system_msg";
            }
            else {
                $removed++;
            }
        }
        if ( scalar @error_list ) {
            $SPOPS::Error::system_msg = join "\n\n", @error_list;
            die 'Remove %%LINKSTO_ALIAS%% failed for one or more items';
        }
        return $removed;
    }
LINKSTO



sub conf_relate_links_to {
    my ( $class ) = @_;

    my $config = $class->CONFIG;
    my $links_to = $config->{links_to};
    return ( OK, undef ) unless ( $links_to and ref $links_to eq 'HASH' );

    foreach my $linksto_class ( keys %{ $links_to } ) {
        my $field_list = ( ref $links_to->{ $linksto_class } eq 'ARRAY' ) 
                           ? $links_to->{ $linksto_class }
                           : [ $links_to->{ $linksto_class } ];
        my $linksto_config   = $linksto_class->CONFIG;
        my $linksto_alias    = $linksto_config->{main_alias};
        foreach my $linksto_field ( @{ $field_list } ) {
            my $linksto_sub = $generic_linksto;
            $linksto_sub =~ s/%%CLASS%%/$class/g;
            $linksto_sub =~ s/%%LINKSTO_CLASS%%/$linksto_class/g;
            $linksto_sub =~ s/%%LINKSTO_ALIAS%%/$linksto_alias/g;
            $linksto_sub =~ s/%%LINKSTO_FIELD%%/$linksto_field/g;
            DEBUG() && _w( 2, "Now going to eval the routine:\n$linksto_sub" );
            {
                local $SIG{__WARN__} = sub { return undef };
                eval $linksto_sub;
            }
            if ( $@ ) {
                return ( ERROR, "Cannot create 'links_to' routine in ($class): $@" );
            }

        }
    }
    DEBUG() && _w( 1, "Finished adding LDAP links_to relationships for ($class)" );
    return ( DONE, undef );
}

# Empty method that halts the process -- don't use the 'fetch_by' from
# SPOPS

sub conf_fetch_by {
    my ( $class ) = @_;
    if ( ref $class->CONFIG->{fetch_by} and scalar @{ $class->CONFIG->{fetch_by} } ) {
        warn "SPOPS::LDAP does not currently implement the 'fetch_by' ",
             "mechanism of SPOPS, so methods for the fetch_by fields\n(",
             join( ', ', @{ $class->CONFIG->{fetch_by} } ),
             ") will not be created for class $class.\n";
    }
    return ( DONE, undef );
}

1;

__END__

=pod

=head1 NAME

SPOPS::ClassFactory::LDAP - Create relationships among LDAP objects

=head1 SYNOPSIS

In configuration:

 my $config = {
    object => {
      class    => 'My::Object',
      isa      => [ 'SPOPS::LDAP' ],
      has_a    => { 'My::OtherObject'   => 'field' },
      links_to => { 'My::AnotherObject' => 'uniquemember',
                    'My::YAObject'      => 'myfield', },
    },
 };

=head1 DESCRIPTION

This class implements two types of relationships: 'has_a' and 'links_to'.

The 'has_a' relationship exists where one object has the information
for one or more objects of another type in its own properties. The
DN(s) for the other object(s) are held in one of the object
properties.

For instance, one of the objects represented in the standard LDAP
schema is a group. This has the object class 'groupOfUniqueNames' and
a property 'uniquemember' which may have zero, one or more DNs for
member objects.

The 'links_to' relationship exists where one object is related to one
or more objects of another type, but the information is held in the
property of the other object. So a member of one or more groups would
use a 'links_to' relationship to find all the groups to which the
member belongs.

As an example of both of these, take the canonical relationship of
users to groups. The group object 'has_a' zero or more user objects
since it is a 'groupOfUniqueNames' and has the property
'uniquemember'. So we would define it:

 group => {
    class    => 'My::Group',
    isa      => [ 'SPOPS::LDAP' ],
    has_a    => { 'My::User' => 'uniquemember' },
 },

So a group that had the following DNs in its 'uniquemember' field:

  cn=Fred Flintstone,ou=People,dc=hanna-barberra,dc=com
  cn=Wilma Flintstone,ou=People,dc=hanna-barberra,dc=com
  cn=Dino,ou=People,dc=hanna-barberra,dc=com

would return user objects for Fred, Wilma and Dino.

The user object might be defined:

 user => {
    class    => 'My::User',
    isa      => [ 'SPOPS::LDAP' ],
    links_to => { 'My::Group' => 'uniquemember' },
 },

And would find all groups that had its DN in the field 'uniquemember'
of the group objects.

This is generally more straightforward than the DBI equivalent.

=head1 METHODS

Note: Even though the first parameter for all behaviors is C<$class>,
they are not class methods. The parameter refers to the class into
which the behaviors will be installed.

B<conf_relate_has_a( $class )>

See above for an explanation of how to configure this.

The 'a' part of the 'has_a' term is a bit of a misnomer -- this works
whether the property has one or more DNs. It creates a single method
named for the alias of the class to which it is linking. So:

  group => {
      class => 'My::Group',
      isa   => [ 'SPOPS::LDAP' ],
      has_a => { 'My::User' => 'uniquemember' },
  },
  user => {
      class => 'My::User',
  },

Would create a method 'user' so you could do:

  my $user_list = $group->user;
  foreach my $user ( @{ $user_list } ) {
      print "DN: ", $user->dn, "\n";
  }

B<conf_relate_links_to( $class )>

This creates three methods for every entry.

=over 4

=item *

C<$alias>: Returns an arrayref of objects to which this object is linked.

=item *

C<$alias_add( \@id_list )>: Adds links for this object to every object
specified in C<\@id_list>.

=item *

C<$alias_remove>: Removes links to this object from every object
specified in C<\@id_list>.

=back

B<conf_fetch_by( $class )>

Do not use the 'fetch_by' implemented by SPOPS (yet), so stop the
processing of this slot here.

=head1 BUGS

None known.

=head1 TO DO

B<Implement 'fetch_by'>

Implement 'fetch_by' functionality.

=head1 SEE ALSO

L<SPOPS::LDAP>

L<Net::LDAP>

L<SPOPS>

=head1 COPYRIGHT

Copyright (c) 2001 MSN Marketing Services Nordwest, GmbH. All rights
reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
