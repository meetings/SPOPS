package SPOPS::ClassFactory::DBI;

# $Id: DBI.pm,v 2.0 2002/03/19 04:00:01 lachoy Exp $

use strict;
use SPOPS qw( _w DEBUG );
use SPOPS::ClassFactory qw( OK ERROR DONE );

$SPOPS::ClassFactory::DBI::VERSION  = substr(q$Revision: 2.0 $, 10);

# NOTE: The behavior is installed in SPOPS::DBI


########################################
# MULTIPLE FIELD KEYS
########################################

my $generic_multifield_id = <<'MFID';

    sub %%CLASS%%::id {
        my ( $self, $id ) = @_;
        if ( $id ) {
	        ( %%ID_FIELD_OBJECT_LIST%% )  = split /\s*,\s*/, $id;
	    }
        return wantarray ? ( %%ID_FIELD_OBJECT_LIST%% )
                         : join( ',', %%ID_FIELD_OBJECT_LIST%% );
    }
MFID


# Generate an ID method for classes that have multiple-field primary
# keys

sub conf_multi_field_key_id {
    my ( $class ) = @_;
    my $CONFIG = $class->CONFIG;
    my $id_field = $CONFIG->{id_field};

    return ( OK, undef ) unless ( ref $id_field eq 'ARRAY' );
    if ( scalar @{ $id_field } == 1 ) {
        $CONFIG->{id_field} = $id_field->[0];
        return ( OK, undef );
    }

    my $id_object_reference = join( ', ',
                                    map { '$self->{' . $_ . '}' }
                                        @{ $id_field } );
    my $id_sub = $generic_multifield_id;
    $id_sub =~ s/%%CLASS%%/$class/g;
    $id_sub =~ s/%%ID_FIELD_OBJECT_LIST%%/$id_object_reference/g;
    {
        local $SIG{__WARN__} = sub { return undef };
        eval $id_sub;
    }
    if ( $@ ) {
        warn "Code: $id_sub\n";
        return ( ERROR, "Cannot create 'id()' method for ($class): $@" );
    }
    return ( DONE, undef );
}


my $generic_multifield_etc = <<'MFETC';

    sub %%CLASS%%::clone {
        my ( $self, $p ) = @_;
        my $class = $p->{_class} || ref $self;
        DEBUG() && _w( 1, "Cloning new object of class ($class) from old ",
                          "object of class (", ref $self, ")" );
        my %initial_data = ();

        my %id_field = map { $_ => 1 } $class->id_field;

        while ( my ( $k, $v ) = each %{ $self } ) {
            next unless ( $k );
            next if ( $id_field{ $k } );
            $initial_data{ $k } = $p->{ $k } || $v;
        }

        my $cloned = $class->new({ %initial_data, skip_default_values => 1 });
        if ( $p->{id} ) {
            $cloned->id( $p->{id} );
        }
        else {
            foreach my $field ( keys %id_field ) {
                $cloned->{ $field } = $p->{ $field } if ( $p->{ $field } );
            }
        }
        return $cloned;
    }

    sub %%CLASS%%::id_field {
        return wantarray ? %%ID_FIELD_NAME_LIST%%
                         : join( ',', %%ID_FIELD_NAME_LIST%% );
    }

    sub %%CLASS%%::id_clause {
        my ( $self, $id, $opt, $p ) = @_;
        $opt ||= '';
        $p   ||= {};
        my %val = ();
        my $db = $p->{db} || $self->global_datasource_handle( $p->{connect_key} );
        unless ( $db ) {
            SPOPS::Exception->throw( "Cannot create ID clause: no DB handle available" );
        }

        my $type_info = eval { $self->db_discover_types(
                                             $self->table_name,
                                             { dbi_type_info => $p->{dbi_type_info},
                                               db            => $db,
                                               DEBUG         => $p->{DEBUG} } ) };
        if ( $id ) {
      	    ( %%ID_FIELD_VARIABLE_LIST%% ) = split /\s*,\s*/, $id;
        }
        else {
    	    ( %%ID_FIELD_VARIABLE_LIST%% ) = ( %%ID_FIELD_OBJECT_LIST%% );
        }
        unless ( %%ID_FIELD_BOOLEAN_LIST%% ) {
	        SPOPS::Exception->throw( "Insufficient values for ID (%%ID_FIELD_VARIABLE_LIST%%)" );
        }
    	my @clause     = ();
    	my $table_name = $self->table_name;
    	foreach my $id_field ( %%ID_FIELD_NAME_LIST%% ) {
            my $use_id_field = ( $opt eq 'noqualify' )
                                 ? $id_field
                                 : join( '.', $table_name, $id_field );
    	    push @clause, join( ' = ', $use_id_field,
		                               $self->sql_quote( $val{ $id_field },
                                                         $type_info->{ lc $id_field },
                                                         $db ) );
	    }
        return join( ' AND ', @clause );
    }
MFETC


sub conf_multi_field_key_other {
    my ( $class ) = @_;
    my $CONFIG = $class->CONFIG;
    my $id_field = $CONFIG->{id_field};

    return ( OK, undef ) unless ( ref $id_field eq 'ARRAY' );
    if ( scalar @{ $id_field } == 1 ) {
        $CONFIG->{id_field} = $id_field->[0];
        return ( OK, undef );
    }

    my $id_object_reference    = join( ', ',
				       map { '$self->{' . $_ . '}' }
				           @{ $id_field } );
    my $id_variable_reference  = join( ', ', map { "\$val{$_}" } @{ $id_field } );
    my $id_boolean_reference   = join( ' and ', map { "\$val{$_}" } @{ $id_field } );
    my $id_field_reference     = 'qw( ' . join( ' ', @{ $id_field } ) . ' )';
    my $id_sub = $generic_multifield_etc;
    $id_sub =~ s/%%CLASS%%/$class/g;
    $id_sub =~ s/%%ID_FIELD_OBJECT_LIST%%/$id_object_reference/g;
    $id_sub =~ s/%%ID_FIELD_VARIABLE_LIST%%/$id_variable_reference/g;
    $id_sub =~ s/%%ID_FIELD_BOOLEAN_LIST%%/$id_boolean_reference/g;
    $id_sub =~ s/%%ID_FIELD_NAME_LIST%%/$id_field_reference/g;
    {
        local $SIG{__WARN__} = sub { return undef };
        eval $id_sub;
    }
    if ( $@ ) {
        warn "Code: $id_sub\n";
        return ( ERROR, "Cannot create 'id_clause() and id_fields()'" .
                        "methods for ($class): $@" );
    }
    return ( OK, undef );
}


########################################
# links_to
########################################

# EVAL'D SUBROUTINES
#
# This is the routine we'll be putting in the namespace of all the
# classes that have asked to be linked to other classes; obviously,
# the items marked like this: %%KEY%% will be replaced before the eval
# is done.

my $generic_linksto = <<'LINKSTO';

    sub %%CLASS%%::%%LINKSTO_ALIAS%% {
        my ( $self, $p ) = @_;
        $p->{select} = [ '%%LINKSTO_ID_FIELD%%' ];
        $p->{from}   = [ '%%LINKSTO_TABLE%%' ];
        my $id_clause = $self->id_clause( $self->id, 'noqualify', $p );
        $p->{where}  = ( $p->{where} )
                         ? join ( ' AND ', $p->{where}, $id_clause ) : $id_clause;
        $p->{return} = 'list';
        $p->{db}   ||= %%LINKSTO_CLASS%%->global_datasource_handle;
        my $rows = %%LINKSTO_CLASS%%->db_select( $p );
        my @obj = ();
        foreach my $info ( @{ $rows } ) {
            my $item = eval { %%LINKSTO_CLASS%%->fetch( $info->[0], $p ) };
            if ( $@ ) {
                SPOPS::_w( 0, " Cannot fetch linked object %%LINKSTO_ALIAS%% => ",
                              "[$@]. Continuing with others..." );
                next;
            }
            push @obj, $item if ( $item );
        }
        return \@obj;
    }

    sub %%CLASS%%::%%LINKSTO_ALIAS%%_add {
        my ( $self, $link_id_list, $p ) = @_;

        # Allow user to pass only one ID to add (scalar) or an arrayref (ref)

        $link_id_list = ( ref $link_id_list ) ? $link_id_list : [ $link_id_list ];
        my $added = 0;
        $p->{db} ||= %%LINKSTO_CLASS%%->global_datasource_handle;
        foreach my $link_id ( @{ $link_id_list } ) {
            SPOPS::_wm( 1, $p->{DEBUG}, "Trying to add link to ID ($link_id)" );
            %%LINKSTO_CLASS%%->db_insert({ table => '%%LINKSTO_TABLE%%',
                                           field => [ '%%ID_FIELD%%', '%%LINKSTO_ID_FIELD%%' ],
                                           value => [ $self->{%%ID_FIELD%%}, $link_id ],
                                           db    => $p->{db},
                                           DEBUG => $p->{DEBUG} });
            $added++;
        }
        return $added;
    }

    sub %%CLASS%%::%%LINKSTO_ALIAS%%_remove {
        my ( $self, $link_id_list, $p ) = @_;

        # Allow user to pass only one ID to remove (scalar) or an
        # arrayref (ref)

        $link_id_list = ( ref $link_id_list ) ? $link_id_list : [ $link_id_list ];
        my $removed = 0;
        $p->{db} ||= %%LINKSTO_CLASS%%->global_datasource_handle;
        foreach my $link_id ( @{ $link_id_list } ) {
            SPOPS::_wm( 1, $p->{DEBUG}, "Trying to remove link to ID ($link_id)" );
            my $from_id_clause = $self->id_clause( undef, 'noqualify', $p  );
            my $to_id_clause   = %%LINKSTO_CLASS%%->id_clause( $link_id, 'noqualify', $p );
            %%LINKSTO_CLASS%%->db_delete({ table => '%%LINKSTO_TABLE%%',
                                           where => join( ' AND ', $from_id_clause, $to_id_clause ),
                                           db    => $p->{db},
                                           DEBUG => $p->{DEBUG} });
            $removed++;
        }
        return $removed;
    }

LINKSTO


#
# ACTUAL SUBROUTINE
#

sub conf_relate_links_to {
    my ( $class ) = @_;
    my $config = $class->CONFIG;
    DEBUG() && _w( 1, "Adding DBI relationships for: ($class)" );

    # Grab the information for the class we're modifying

    my $this_id_field = $config->{id_field};
    my $this_alias    = $config->{main_alias};

    # Process the 'links_to' aliases -- pretty straightforward (see pod)

    if ( my $links_to = $config->{links_to} ) {
        while ( my ( $linksto_class, $table ) = each %{ $links_to } ) {
            my $linksto_config   = $linksto_class->CONFIG;
            my $linksto_alias    = $linksto_config->{main_alias};
            my $linksto_id_field = $linksto_config->{id_field};
            my $linksto_sub = $generic_linksto;
            $linksto_sub =~ s/%%ID_FIELD%%/$this_id_field/g;
            $linksto_sub =~ s/%%CLASS%%/$class/g;
            $linksto_sub =~ s/%%LINKSTO_CLASS%%/$linksto_class/g;
            $linksto_sub =~ s/%%LINKSTO_ALIAS%%/$linksto_alias/g;
            $linksto_sub =~ s/%%LINKSTO_ID_FIELD%%/$linksto_id_field/g;
            $linksto_sub =~ s/%%LINKSTO_TABLE%%/$table/g;
            DEBUG() && _w( 2, "Trying to create links_to routines with ($class) links_to",
                              "($linksto_class) using table ($table)" );
            DEBUG() && _w( 5, "Now going to eval the routine:\n$linksto_sub" );
            {
                local $SIG{__WARN__} = sub { return undef };
                eval $linksto_sub;
            }
            if ( $@ ) {
                return ( ERROR, "Cannot create 'links_to' methods for ($class): $@" );
            }
        }
    }
    DEBUG() && _w( 1, "Finished adding DBI relationships for ($class)" );
    return ( OK, undef );
}

1;

__END__

=pod

=head1 NAME

SPOPS::ClassFactory::DBI - Define additional configuration methods

=head1 SYNOPSIS

 # Put SPOPS::DBI in your isa
 my $config = {
       class => 'My::SPOPS',
       isa   => [ 'SPOPS::DBI::Pg', 'SPOPS::DBI' ],
 };

=head1 DESCRIPTION

This class implements a behavior for the 'links_to' slot as described
in L<SPOPS::ClassFactory|SPOPS::ClassFactory>.

It is possible -- and perhaps desirable for the sake of clarity -- to
create a method within I<SPOPS::DBI> that does all the work that this
behavior does, then we would only need to create a subroutine that
calls that subroutine.

However, creating routines with the values embedded directly in them
should be quicker and more efficient. So we will try it this way.

=head1 METHODS

Note: Even though the first parameter for all behaviors is C<$class>,
they are not class methods. The parameter refers to the class into
which the behaviors will be installed.

B<conf_relate_links_to( $class )>

Slot: links_to

Get the config for C<$class> and find the 'links_to' configuration
information. If defined, we auto-generate subroutines to implement the
linking functionality.

Typical configuration:

  my $config = {
        class    => 'My::SPOPS',
        isa      => [ 'SPOPS::DBI::Pg', 'SPOPS::DBI' ],
        links_to => { 'My::Group' => 'link-table' },
  };

This assumes that 'My::OtherClass' has already been created or will be
part of the same configuration sent to C<SPOPS::ClassFactory> (or more
likely C<SPOPS::Initialize>).

All subroutines generated use the alias used by SPOPS for the class
specified in the key. For instance, in the above configuration example
we give 'My::Group' as the class specified in the key. So to get the
alias for this class we do:

 my $alias = My::Group->CONFIG->{main_alias};

We then use C<$alias> to define our method names.

The first method generated is simply named C<$alias>. The method
returns an arrayref of objects that the main object links to. For
instance:

Example:

 # $links_to = 'My::Group' => 'link-table'
 # Alias for 'My::Group' = 'group'

 my $object = My::SPOPS->fetch( $id );
 my $group_list = eval { $object->group };

The second is named '${alias}_add' (e.g., 'group_add') and links the
object to any number of other objects. The return value is the number
of successful links.

The third is named '${alias}_remove' (e.g., 'group_remove') and
removes links from the object to any number of other objects. The
return value is the number of successful removals.

Examples:

 # First retrieve all groups
 my $object = My::SPOPS->fetch( $id );
 my $group_list = eval { $object->group };
 print "Group list: ", join( ' // ', map { $_->{group_id} } @{ $group_list } );

 >> 2 // 3 // 5

 # Now add some more, making the thingy a member of these new groups

 my $added = eval { $object->group_add( [ 7, 9, 21, 23 ] ) };
 print "Group list: ", join( ' // ', map { $_->{group_id} } @{ $group_list } );

 >> 2 // 3 // 5 // 7 // 9 // 21 // 23

 # Now remove two of them

 my $removed = eval { $object->group_remove( [ 2, 21 ] ) };
 print "Group list: ", join( ' // ', map { $_->{group_id} } @{ $group_list } );

 >> 3 // 5 // 7 // 9 // 23

=head1 TO DO

B<Make 'links_to' more flexible>

We need to account for different types of linking; this may require an
additional field beyond 'links_to' that has a similar effect but works
differently.

For instance, Table-B might have a 'has_a' relationship with Table-A,
but Table-A might have a 'links_to' relationship with Table-B. (Themes
in OpenInteract work like this.) We need to be able to specify that
when Table-A severs its relationship with one or more objects from
Table-B, the actual B<object> is removed rather than just a link
between them.

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

See the L<SPOPS|SPOPS> module for the full author list.

=cut
