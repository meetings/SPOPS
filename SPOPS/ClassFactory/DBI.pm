package SPOPS::ClassFactory::DBI;

# $Id: DBI.pm,v 1.6 2001/08/27 03:55:57 lachoy Exp $

use strict;
use SPOPS qw( _w DEBUG );
use SPOPS::ClassFactory qw( OK ERROR );;

@SPOPS::ClassFactory::DBI::ISA      = ();
$SPOPS::ClassFactory::DBI::VERSION  = '1.8';
$SPOPS::ClassFactory::DBI::Revision = substr(q$Revision: 1.6 $, 10);

# NOTE: The behavior is installed in SPOPS::DBI


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
        my $rows = eval { %%CLASS%%->db_select( $p ) };
        if ( $@ ) {
            $SPOPS::Error::user_msg = 'Cannot retrieve %%LINKSTO_ALIAS%% object(s)';
            warn "$SPOPS::Error::user_msg -- $@";
            die $SPOPS::Error::user_msg;
        }
        my @obj = ();
        foreach my $info ( @{ $rows } ) {
            my $item = eval { %%LINKSTO_CLASS%%->fetch( $info->[0], $p ) };
            if ( $@ ) {
                warn " --Cannot fetch linked object %%LINKSTO_ALIAS%% => $SPOPS::Error::system_msg ($@)\n";
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
        my @error_list = ();
        foreach my $link_id ( @{ $link_id_list } ) {
            SPOPS::_wm( 1, $p->{DEBUG}, "Trying to add link to ID ($link_id)" );
            eval { %%CLASS%%->db_insert({ table => '%%LINKSTO_TABLE%%',
                                          field => [ '%%ID_FIELD%%', '%%LINKSTO_ID_FIELD%%' ],
                                          value => [ $self->{%%ID_FIELD%%}, $link_id ],
                                          db    => $p->{db},
                                          DEBUG => $p->{DEBUG} }) };
            if ( $@ ) {
                my $count = scalar @error_list + 1;
                my $value_list = ( ref $SPOPS::Error::extra->{value} ) 
                                   ? join( ' // ', @{ $SPOPS::Error::extra->{value} } )
                                   : 'none reported';
                my $error_msg = "Error $count\n$@\n$SPOPS::Error::system_msg\n" .
                                "SQL: $SPOPS::Error::extra->{sql}\nValues: $value_list";
                push @error_list, $error_msg; 
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

        # Allow user to pass only one ID to remove (scalar) or an
        # arrayref (ref)

        $link_id_list = ( ref $link_id_list ) ? $link_id_list : [ $link_id_list ];
        my $removed = 0;
        my @error_list = ();
        foreach my $link_id ( @{ $link_id_list } ) {
            SPOPS::_wm( 1, $p->{DEBUG}, "Trying to remove link to ID ($link_id)" );
            my $from_id_clause = $self->id_clause( undef, 'noqualify', $p  );
            my $to_id_clause   = %%LINKSTO_CLASS%%->id_clause( $link_id, 'noqualify', $p );
            eval { %%CLASS%%->db_delete({ table => '%%LINKSTO_TABLE%%',
                                          where => join( ' AND ', $from_id_clause, $to_id_clause ),
                                          db    => $p->{db},
                                          DEBUG => $p->{DEBUG} }) };
            if ( $@ ) {
                my $count = scalar @error_list + 1;
                my $value_list = ( ref $SPOPS::Error::extra->{value} ) 
                                   ? join( ' // ', @{ $SPOPS::Error::extra->{value} } )
                                   : 'none reported';
                my $error_msg = "Error $count\n$@\n$SPOPS::Error::system_msg\n" .
                                "SQL: $SPOPS::Error::extra->{sql}\nValues: $value_list";
                push @error_list, $error_msg;
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
            DEBUG() && _w( 1, "Aliasing $linksto_alias, ${linksto_alias}_add and ",
                              "${linksto_alias}_remove in $class"  );
            my $linksto_sub = $generic_linksto;
            $linksto_sub =~ s/%%ID_FIELD%%/$this_id_field/g;
            $linksto_sub =~ s/%%CLASS%%/$class/g;
            $linksto_sub =~ s/%%LINKSTO_CLASS%%/$linksto_class/g;
            $linksto_sub =~ s/%%LINKSTO_ALIAS%%/$linksto_alias/g;
            $linksto_sub =~ s/%%LINKSTO_ID_FIELD%%/$linksto_id_field/g;
            $linksto_sub =~ s/%%LINKSTO_TABLE%%/$table/g;
            DEBUG() && _w( 2, "Now going to eval the routine:\n$linksto_sub" );
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
in L<SPOPS::ClassFactory>.

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
        class => 'My::SPOPS',
        isa   => [ 'SPOPS::DBI::Pg', 'SPOPS::DBI' ],
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

=head1 CONFIGURATION FIELDS EXPLAINED

B<base_table> ($) (used by SPOPS::DBI)

Table name for data to be stored.

B<sql_defaults> (\@) (used by SPOPS::DBI)

List of fields that have defaults defined in the SQL table. For
instance:

   active   CHAR(3) DEFAULT 'yes',

After L<SPOPS::DBI> fetches a record, it then checks to see if there
are any defaults for the record and if so it refetches the object to
ensure that the data in the object and the data in the database are
synced.

B<field_alter> (\%) (used by SPOPS::DBI)

Allows you to define different formatting behaviors for retrieving
fields. For instance, if you want dates formatted in a certain manner
in MySQL, you can do something like:

 field_alter => { posted_on => q/DATE_FORMAT( posted_on, '%M %e, %Y (%h:%i %p)' )/ }

Which instead of the default time format:

 2000-09-26 10:29:00

will return something like:

 September 26, 2000 (10:29 AM)

These are typically database-specific.

=head2 Relationship Fields

B<links_to> (\%)

The 'links_to' field allows you to specify a SPOPS alias and specify
which table is used to link the objects:

 {
    'SPOPS-class' => 'table_name',
 }

Note that this relationship assumes a link table that joins two
separate tables. When you sever a link between two objects, you are
only deleting the link rather than deleting an object. See L<TO DO>
for another proposal.

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

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

See the L<SPOPS> module for the full author list.

=cut
