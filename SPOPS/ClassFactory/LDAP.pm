package SPOPS::ClassFactory::LDAP;

# $Id: LDAP.pm,v 3.1 2003/01/02 06:00:24 lachoy Exp $

use strict;
use SPOPS qw( _w DEBUG );
use SPOPS::ClassFactory qw( OK ERROR DONE );

$SPOPS::ClassFactory::LDAP::VERSION  = sprintf("%d.%02d", q$Revision: 3.1 $ =~ /(\d+)\.(\d+)/);


########################################
# BEHAVIOR: read_code
########################################

my $generic_common_relate = <<'COMMONRELATE';

    sub %%CLASS%%::_ldap_get_linked_objects {
        my ( $self, $item_list, $item_class, $p ) = @_;
        $item_list  = ( ref $item_list ) ? $item_list : [ $item_list ];
        my ( @object_list, @error_list );
LINK_ITEM:
        foreach my $item ( @{ $item_list } ) {
            if ( ref $item ) {
                push @object_list, $item;
                SPOPS::_wm( 2, $p->{DEBUG}, "Found linked object", "(", $item->id, ")" );
                next LINK_ITEM;
            }

            # First fetch the thing we're linking to, then put it in
            # the list

            my $item_obj = eval { $item_class->fetch( $item, $p ) };
            if ( $@ or ! $item_obj ) {
                my $err = ( $@ ) ? $SPOPS::Error::system_msg : 'Object not found';
                my $msg = "Cannot fetch linked object with ID ($item)\nError: $err";
                SPOPS::_wm( 1, $p->{DEBUG}, $msg );
                push @error_list, $msg;
                next LINK_ITEM;
            }
            SPOPS::_wm( 2, $p->{DEBUG}, "Found linked object to ID (", $item_obj->id, ")" );
            push @object_list, $item_obj;
        }
        return ( \@object_list, \@error_list );
    }

COMMONRELATE


sub conf_read_code {
    my ( $class ) = @_;
    my $common_relate = $generic_common_relate;
    $common_relate =~ s/%%CLASS%%/$class/g;
    {
        local $SIG{__WARN__} = sub { return undef };
        eval $common_relate;
    }
    if ( $@ ) {
        return ( ERROR, "Cannot create common relationship routine ($class): $@" );
    }
    DEBUG() && _w( 1, "Finished adding LDAP read_code sub for ($class)" );
    return ( OK, undef );
}


########################################
# BEHAVIOR: has_a
########################################

my $generic_hasa = <<'HASA';
    sub %%CLASS%%::%%HASA_ALIAS%% {
        my ( $self, $p ) = @_;
        unless ( $self->dn ) { SPOPS::Exception->throw( "Cannot call from unsaved object or class!" ) }
        my @object_list = ();
        my $conf_other = %%HASA_CLASS%%->CONFIG;
        my $hasa_value = $self->{%%HASA_FIELD%%};
        $hasa_value = ( ref $hasa_value eq 'ARRAY' )
                        ? $hasa_value : [ $hasa_value ];
        foreach my $other_dn ( @{ $hasa_value } ) {
            SPOPS::_wm( 2, $p->{DEBUG}, "Trying to retrieve linked %%HASA_ALIAS%%",
                                        "with DN ($other_dn)" );
            my $object = eval { %%HASA_CLASS%%->fetch_by_dn( $other_dn, $p ) };
            if ( $@ ) {
                SPOPS::_w( 1, "Could not retrieve linked %%HASA_ALIAS%% with DN ($other_dn): $@" );
                next;
            }
            SPOPS::_wm( 2, $p->{DEBUG}, "Fetched: ", ( ref $object )
                                                       ? "object with ID (" . $object->id . ")"
                                                       : "nothing" );
            push @object_list, $object if ( $object );
        }
        return \@object_list;
    }


    sub %%CLASS%%::%%HASA_ALIAS%%_add {
        my ( $self, $link_item_list, $p ) = @_;
        my ( $has_a_objects, $error_list ) =
                         $self->_ldap_get_linked_objects( $link_item_list,
                                                          '%%HASA_CLASS%%', $p );
        my $link_dn = $self->dn;
        my $added   = 0;

        foreach my $has_a ( @{ $has_a_objects } ) {
            $self->{%%HASA_FIELD%%} = $has_a->dn;
            $added++;
            SPOPS::_wm( 2, $p->{DEBUG}, "Will add has_a object:", $has_a->dn );
        }
        $self->save( $p );
        return $added;
    }


    sub %%CLASS%%::%%HASA_ALIAS%%_remove {
        my ( $self, $link_item_list, $p ) = @_;
        my ( $has_a_objects, $error_list ) =
                         $self->_ldap_get_linked_objects( $link_item_list,
                                                          '%%HASA_CLASS%%', $p );
        my $link_dn = $self->dn;
        my $removed = 0;

        my $old_members = ( ref $self->{%%HASA_FIELD%%} )
                            ? $self->{%%HASA_FIELD%%} : [ $self->{%%HASA_FIELD%%} ];
        foreach my $has_a ( @{ $has_a_objects } ) {
            $self->{%%HASA_FIELD%%} = ( ref $self->{%%HASA_FIELD%%} )
                                        ? { remove => $has_a->dn } : undef;
            $removed++;
            SPOPS::_wm( 2, $p->{DEBUG}, "Will remove has_a object:", $has_a->dn );

        }
        $self->save( $p );
        return $removed;
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
            DEBUG() && _w( 2, "Trying to create has_a routines with ($class) has_a",
                              "($hasa_class) using field ($hasa_field)" );
            DEBUG() && _w( 5, "Now going to eval the routine:\n$hasa_sub" );
#            warn "Trying\n$hasa_sub";
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
        my ( $self, $p ) = @_;
        $p ||= {};
        $p->{filter} = "(%%LINKSTO_FIELD%%=" . $self->dn . ")";
        return %%LINKSTO_CLASS%%->fetch_group( $p );
    }


    sub %%CLASS%%::%%LINKSTO_ALIAS%%_add {
        my ( $self, $link_item_list, $p ) = @_;
        my ( $link_to_objects, $error_list ) =
                         $self->_ldap_get_linked_objects( $link_item_list,
                                                          '%%LINKSTO_CLASS%%', $p );
        my $link_dn = $self->dn;
        my $added   = 0;

        foreach my $link_to ( @{ $link_to_objects } ) {

            # Now add the DN for the linker -- this should work
            # whether it's multivalue or not

            $link_to->{%%LINKSTO_FIELD%%} = $link_dn;
            $link_to->save( $p );
            $added++;
        }
        return $added;
    }


    sub %%CLASS%%::%%LINKSTO_ALIAS%%_remove {
        my ( $self, $link_item_list, $p ) = @_;
        my ( $link_to_objects, $error_list ) =
                         $self->_ldap_get_linked_objects( $link_item_list,
                                                          '%%LINKSTO_CLASS%%', $p );
        my $link_dn = $self->dn;
        my $removed = 0;

        foreach my $link_to ( @{ $link_to_objects } ) {
            my $current_value = $link_to->{%%LINKSTO_FIELD%%};
            if ( ref $current_value ) {
                $link_to->{%%LINKSTO_FIELD%%} = { remove => $link_dn };
            }
            else {
                $link_to->{%%LINKSTO_FIELD%%} = undef;
            }
            $link_to->save( $p );
            $removed++;
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
            DEBUG() && _w( 2, "Trying to create links_to routines with ($class) links_to",
                              "($linksto_class) using field ($linksto_field)" );
            DEBUG() && _w( 5, "Now going to eval the routine:\n$linksto_sub" );
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

See L<SPOPS::Manual::Configuration|SPOPS::Manual::Configuration> for a
discussion of the configuration parameters.

=head1 METHODS

Note: Even though the first parameter for all behaviors is C<$class>,
they are not class methods. The parameter refers to the class into
which the behaviors will be installed.

B<conf_relate_has_a( $class )>

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

=over 4

=item *

C<$alias>: Returns an arrayref of objects to which this object is linked.

=item *

C<$alias_add( \@item_list )>: Adds links for this object to every
object specified in C<\@item_list>.

=item *

C<$alias_remove>: Removes links to this object from every object
specified in C<\@item_list>.

=back

B<conf_relate_links_to( $class )>

This creates three methods for every entry -- note that C<\@item_list>
can be either ID values of objects to add/remove or the objects
themselves.

=over 4

=item *

C<$alias>: Returns an arrayref of objects to which this object is linked.

=item *

C<$alias_add( \@item_list )>: Adds links for this object to every
object specified in C<\@item_list>.

=item *

C<$alias_remove>: Removes links to this object from every object
specified in C<\@item_list>.

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

L<SPOPS::Manual::Relationships|SPOPS::Manual::Relationships>

L<SPOPS::LDAP|SPOPS::LDAP>

L<Net::LDAP|Net::LDAP>

L<SPOPS|SPOPS>

=head1 COPYRIGHT

Copyright (c) 2001-2002 MSN Marketing Services Nordwest, GmbH. All rights
reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
