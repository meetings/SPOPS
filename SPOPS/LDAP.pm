package SPOPS::LDAP;

# $Id: LDAP.pm,v 1.20 2001/08/28 21:32:45 lachoy Exp $

use strict;
use Data::Dumper     qw( Dumper );
use Net::LDAP        qw();
use Net::LDAP::Entry qw();
use Net::LDAP::Util  qw();
use SPOPS            qw( _w _wm );
use SPOPS::Error     qw();
use SPOPS::Secure    qw( :level );

use constant DEBUG => 0;

@SPOPS::LDAP::ISA       = qw( SPOPS );
$SPOPS::LDAP::VERSION   = '1.8';
$SPOPS::LDAP::Revision  = substr(q$Revision: 1.20 $, 10);


########################################
# CONFIG
########################################

# LDAP config items available from class/object

sub base_dn           { return $_[0]->CONFIG->{ldap_base_dn} || die "No Base DN defined, cannot continue!\n"; }
sub id_value_field    { return $_[0]->CONFIG->{id_value_field} }
sub ldap_object_class { return $_[0]->CONFIG->{ldap_object_class} }
sub ldap_fetch_object_class { return $_[0]->CONFIG->{ldap_fetch_object_class} }

sub get_superuser_id  { return $_[0]->CONFIG->{ldap_root_dn} }
sub get_supergroup_id { return $_[0]->CONFIG->{ldap_root_group_dn} }

sub is_superuser {
    my ( $class, $id ) = @_;
    return ( $id eq $class->get_superuser_id );
}

sub is_supergroup {
    my ( $class, @id ) = @_;
    my $super_gid = $class->get_supergroup_id;
    return grep { $_ eq $super_gid } @id;
}


########################################
# CONNECTION RETRIEVAL
########################################

# Subclass must override -- see POD for info

sub global_datasource_handle { return undef }
sub connection_info          { return undef }


########################################
# CLASS CONFIGURATION
########################################

sub behavior_factory {
    my ( $class ) = @_;
    require SPOPS::ClassFactory::LDAP;
    DEBUG() && _wm( 2, DEBUG, "Installing SPOPS::LDAP behaviors for ($class)" );
    return { has_a    => \&SPOPS::ClassFactory::LDAP::conf_relate_has_a,
             links_to => \&SPOPS::ClassFactory::LDAP::conf_relate_links_to,
             fetch_by => \&SPOPS::ClassFactory::LDAP::conf_fetch_by, };

}


########################################
# CLASS INITIALIZATION
########################################

sub class_initialize {
    my ( $class )  = @_;
    my $C = $class->CONFIG;
    $C->{field_list}  = [ sort{ $C->{field}->{$a} <=> $C->{field}->{$b} }
                          keys %{ $C->{field} } ];
    $class->_class_initialize;
    return 1;
}

sub _class_initialize {}


########################################
# OBJECT INFO
########################################

sub dn {
    my ( $self, $dn ) = @_;
    die "Cannot call dn() as class method\n" unless ( ref $self );
    $self->{tmp_dn} = $dn if ( $dn );
    return $self->{tmp_dn};
}


########################################
# FETCH
########################################

sub fetch {
    my ( $class, $id, $p ) = @_;
    $p ||= {};
    DEBUG() && _wm( 2, DEBUG, "Trying to fetch an item of $class with ID $id and params ",
                      join " // ",
                      map { $_ . ' -> ' . ( defined( $p->{$_} ) ? $p->{$_} : '' ) }
                          keys %{ $p } );
    return undef unless ( $id or $p->{filter} );

    # Let security errors bubble up

    my $level = $p->{security_level};
    unless ( $p->{skip_security} ) {
        $level ||= $class->check_action_security({ id       => $id || $p->{filter},
                                                   required => SEC_LEVEL_READ });
    }

    # Do any actions the class wants before fetching -- note that if
    # any of the actions returns undef (false), we bail.

    return undef unless ( $class->pre_fetch_action( { %{ $p }, id => $id } ) );

    # Run the search

    my $ldap = $p->{ldap} || $class->global_datasource_handle( $p->{connect_key} );
    my $filter = $p->{filter} || join( '=', $class->id_field, $id );
    DEBUG() && _wm( 1, DEBUG, "Base DN (", $class->base_dn( $p->{connect_key} ), ") and filter <<$filter>>",
                      "being used to fetch single object" );
    my $ldap_msg = $ldap->search( base   => $class->base_dn( $p->{connect_key} ),
                                  scope  => 'sub',
                                  filter => $filter );
    $class->_check_error( $ldap_msg, 'Error trying to run LDAP search' );

    # Go ahead and use $count here since we've hopefully only
    # retrieved a single record and don't have to worry about blocking
    # (etc.) for a long time

    my $count = $ldap_msg->count;
    if ( $count > 1 ) {
        SPOPS::Error->set({ user_msg   => "More than one entry retrieved!\n",
                            system_msg => "Trying to retrieve unique record, retrieved ($count)",
                            extra      => { filter => $filter } });
        die $SPOPS::Error::user_msg;
    }

    if ( $count == 0 ) {
        DEBUG() && _wm( 1, DEBUG, "No entry found matching ($id) or filter ($p->{filter})" );
        return undef;
    }
    my $obj = $class->new;
    $obj->_fetch_assign_row( undef, $ldap_msg->entry( 0 ) );
    $obj->_fetch_post_process( $p, $level );
    return $obj;
}


# Given a DN, return an object

# TODO: Ensure the DN is correct (in the right place of the hierarchy, etc.)

sub fetch_by_dn {
    my ( $class, $dn, $p ) = @_;
    my ( $filter ) = split /\s*,\s*/, $dn;
    my ( $field, $value ) = split /=/, $filter;
    my $filter_field = $class->CONFIG->{id_value_field} ||
                       $class->CONFIG->{id_field};
    $p->{filter} = "$filter_field=$value";
    DEBUG() && _wm( 1, DEBUG, "Using filter ($filter_field=$value) to find a ($class)\n" );
    return $class->fetch( undef, $p );
}


# Return implementation of SPOPS::Iterator with results

sub fetch_iterator {
    my ( $class, $p ) = @_;
    require SPOPS::Iterator::LDAP;
    DEBUG() && _wm( 1, DEBUG, "Trying to create an Iterator with: ", Dumper( $p ) );
    $p->{class}                    = $class;
    ( $p->{offset}, $p->{max} )    = $class->fetch_determine_limit( $p->{limit} );
    unless ( ref $p->{id_list} ) {
        $p->{ldap_msg} = $class->_execute_multiple_record_query( $p );
        $class->_check_error( $p->{ldap_msg}, 'Error trying to run LDAP search' );
    }
    return SPOPS::Iterator::LDAP->new( $p );
}


# Given a filter, return an arrayref of objects

sub fetch_group {
    my ( $class, $p ) = @_;
    my ( $offset, $max ) = $class->fetch_determine_limit( $p->{limit} );
    my $ldap_msg = $class->_execute_multiple_record_query( $p );
    $class->_check_error( $ldap_msg, 'Error trying to run LDAP search' );

    my $entry_count = 0;
    my @group = ();
ENTRY:
    while ( my $entry = $ldap_msg->shift_entry ) {
        my $obj = $class->new;
        $obj->_fetch_assign_row( undef, $entry );
        my $level = ( $p->{skip_security} )
                      ? SEC_LEVEL_WRITE
                      : eval { $obj->check_action_security({ required => SEC_LEVEL_READ }) };
        if ( $@ ) {
            DEBUG() && _wm( 1, DEBUG, "Security check for object in fetch_group() failed, skipping." );
            next ENTRY;
        }

        if ( $offset and ( $entry_count < $offset ) ) {
            $entry_count++;
            next ENTRY
        }
        last ENTRY if ( $max and ( $entry_count >= $max ) );
        $entry_count++;

        $obj->_fetch_post_process( $p, $level );
        push @group, $obj;
    }
    return \@group;
}


sub _execute_multiple_record_query {
    my ( $class, $p ) = @_;
    my $filter = $p->{where} || $p->{filter} || '';

    # If there is a filter, be sure it's in ()
    if ( $filter and $filter !~ /^\(.*\)$/ ) {
        $filter = "($filter)";
    }

    # Specify an object class in the filter if the filter doesn't
    # already specify an object class and our config says we should

    if ( ( my $fetch_oc = $class->ldap_fetch_object_class ) and $filter !~ /objectclass/ ) {
        my $oc_filter = "(objectclass=$fetch_oc)";
        DEBUG() && _wm( 2, DEBUG, "Adding filter for object class ($fetch_oc)" );
        $filter = ( $filter ) ? "(&$oc_filter$filter)" : $oc_filter;
    }
    my $ldap = $p->{ldap} || $class->global_datasource_handle( $p->{connect_key} );
    DEBUG() && _wm( 1, DEBUG, "Base DN (", $class->base_dn( $p->{connect_key} ), ")\nFilter <<$filter>>\n",
                      "being used to fetch one or more objects" );
    return $ldap->search( base   => $class->base_dn( $p->{connect_key} ),
                          scope  => 'sub',
                          filter => $filter );
}


sub _fetch_assign_row {
    my ( $self, $field_list, $entry ) = @_;
    DEBUG() && _wm( 1, DEBUG, "Setting data from row into", ref $self, "using DN of entry ", $entry->dn  );
    $self->clear_all_loaded();
    my $CONF = $self->CONFIG;
    $field_list ||= $self->field_list;
    foreach my $field ( @{ $field_list } ) {
        my @values = $entry->get_value( $field );
        if ( $CONF->{multivalue}->{ $field } ) {
            $self->{ $field } = \@values;
            DEBUG() && _wm( 1, DEBUG, sprintf( " ( multi) %-20s --> %s", $field, join( '||', @values ) ) );
        }
        else {
            $self->{ $field } = $values[0];
            DEBUG() && _wm( 1, DEBUG, sprintf( " (single) %-20s --> %s", $field, $values[0] ) );
        }
        $self->set_loaded( $field );
    }
    $self->dn( $entry->dn );
    return $self;
}


sub _fetch_post_process {
    my ( $self, $p, $security_level ) = @_;

    # Create an entry for this object in the cache unless either the
    # class or this call to fetch() doesn't want us to.

    $self->set_cached_object( $p );

    # Execute any actions the class (or any parent) wants after 
    # creating the object (see SPOPS.pm)

    return undef unless ( $self->post_fetch_action( $p ) );

    # Set object flags

    $self->clear_change;
    $self->has_save;

    # Set the security fetched from above into this object
    # as a temporary property (see SPOPS::Tie for more info 
    # on temporary properties); note that this is set whether
    # we retrieve a cached copy or not

    $self->{tmp_security_level} = $security_level;
    DEBUG() && _wm( 1, DEBUG, ref $self, "(", $self->id, ") : cache set (if available),",
                      "post_fetch_action() done, change flag cleared and save ",
                      "flag set. Security: $security_level" );
    return $self;
}


########################################
# SAVE
########################################

sub save {
    my ( $self, $p ) = @_;
    my $id = $self->id;
    DEBUG && _wm( 1, DEBUG, "Trying to save a (", ref $self, ") with ID ($id)" );

    # We can force save() to be an INSERT by passing in a true value
    # for the is_add parameter; otherwise, we rely on the flag within
    # SPOPS::Tie to reflect whether an object has been saved or not.

    my $is_add = ( $p->{is_add} or ! $self->saved );

    # If this is an update and it hasn't changed, we don't need to do
    # anything.

    unless ( $is_add or $self->changed ) {
        DEBUG && _wm( 1, DEBUG, "This object exists and has not changed. Exiting." );
        return $self;
    }

    # Check security for create/update

    my ( $level );
    unless ( $p->{skip_security} ) {
        $level = $self->check_action_security({ required => SEC_LEVEL_WRITE,
                                                is_add   => $is_add });
    }
    DEBUG && _wm( 1, DEBUG, "Security check passed ok. Continuing." );

    # Callback for objects to do something before they're saved

    return undef unless ( $self->pre_save_action({ %{ $p }, 
                                                   is_add => $is_add }) );

    # Gather up the values currently in the object into a hash,
    # particularly since we're doing a 'replace' with the update.

    $p->{data} = {};
    foreach my $field ( @{ $self->field_list } ) {
        my $value = $self->{ $field };
        $p->{data}->{ $field } = ( ref $value ) 
                                   ? $value 
                                   : ( defined $value ) 
                                       ? [ $value ] : [];
    }

    # Do the insert/update based on whether the object is new; don't
    # catch the die() that might be thrown -- let that percolate

    if ( $is_add ) { $self->_save_insert( $p )  } 
    else           { $self->_save_update( $p )  }

    # Do any actions that need to happen after you save the object

    return undef unless ( $self->post_save_action({ %{ $p }, 
                                                    is_add => $is_add }) );

    # Save the newly-created/updated object to the cache

    $self->set_cached_object( $p );

    # Note the action that we've just taken (opportunity for subclasses)

    my $action = ( $is_add ) ? 'create' : 'update';
    unless ( $p->{skip_log} ) {
        $self->log_action( $action, $self->id );
    }

    # Set object flags and we're done

    $self->has_save;
    $self->clear_change;
    return $self;
}


sub _save_insert {
    my ( $self, $p ) = @_;
    $p ||= {};
    DEBUG && _wm( 1, DEBUG, 'Treating save as INSERT' );
    my $ldap = $p->{ldap} || $self->global_datasource_handle( $p->{connect_key} );
    $self->dn( $self->build_dn );
    unless ( ref $p->{data}->{object_class} eq 'ARRAY' and 
             scalar @{ $p->{data}->{object_class} } > 0) {
        $self->{objectclass} = $p->{data}->{objectclass} = $self->ldap_object_class;
        DEBUG && _w( 1, "Using object class from config in new object (",
                        join( ', ', @{ $p->{data}->{objectclass} } ), ")" );
    }
    DEBUG && _wm( 1, DEBUG, "Trying to create record with DN: (", $self->dn, ")" );
    DEBUG && _wm( 3, DEBUG, "Attributes for creation: ", Dumper( [ %{ $p->{data} } ] ) );
    my $ldap_msg = $ldap->add( dn   => $self->dn, 
                               attr => [ %{ $p->{data} } ]);
    $self->_check_error( $ldap_msg, 'Cannot create new LDAP record' );
}


sub _save_update {
    my ( $self, $p ) = @_;
    $p ||= {};
    DEBUG && _wm( 1, DEBUG, "Treating save as UPDATE with DN: (", $self->dn, ")" );
    my $ldap = $p->{ldap} || $self->global_datasource_handle( $p->{connect_key} );
    DEBUG && _wm( 3, DEBUG, "Attributes for creation: ", Dumper( $p->{data} ) );
    my $entry = Net::LDAP::Entry->new;
    $entry->changetype( 'modify' );
    foreach my $attr ( keys %{ $p->{data} } ) {
        $entry->replace( $attr, $p->{data}->{ $attr } );
    }
    $entry->dn( $self->dn );
    my $ldap_msg = $entry->update( $ldap ); 
    $self->_check_error( $ldap_msg, 'Cannot update existing record' );
}


########################################
# REMOVE
########################################

sub remove {
    my ( $self, $p ) = @_;

    # Don't remove it unless it's been saved already

    return undef   unless ( $self->is_saved );

    my $level = SEC_LEVEL_WRITE;
    unless ( $p->{skip_security} ) {
        $level = $self->check_action_security({ required => SEC_LEVEL_WRITE });
    }

    DEBUG && _wm( 1, DEBUG, "Security check passed ok. Continuing." );

    # Allow members to perform an action before getting removed

    return undef unless ( $self->pre_remove_action( $p ) );

    # Do the removal, building the where clause if necessary

    my $id = $self->id;
    my $dn = $self->dn;
    my $ldap = $p->{ldap} || $self->global_datasource_handle( $p->{connect_key} );;
    my $ldap_msg = $ldap->delete( $dn );
    $self->_check_error( $ldap_msg, 'Failed to remove object from datastore' );

    # Otherwise...
    # ... remove this item from the cache

    if ( $self->use_cache( $p ) ) {
        $self->global_cache->clear({ data => $self });
    }

    # ... execute any actions after a successful removal

    return undef unless ( $self->post_remove_action( $p ) );

    # ... and log the deletion

    $self->log_action( 'delete', $id ) unless ( $p->{skip_log} );

    # Clear flags

    $self->clear_change;
    $self->clear_save;
    return 1;
}


########################################
# INTERNAL METHODS
########################################

# Error consolidation routine

sub _check_error {
    my ( $class, $ldap_msg, $user_msg ) = @_;
    return undef unless ( $ldap_msg->code );
    my $system_msg = Net::LDAP::Util::ldap_error_desc( $ldap_msg->code );
    _w( 1, "\nLDAP error desc: (", $ldap_msg->error, ") $system_msg",
           "\nLDAP error text: ", Net::LDAP::Util::ldap_error_text( $ldap_msg->code ),
           "\nLDAP error name: ", Net::LDAP::Util::ldap_error_name( $ldap_msg->code ),
           "\nLDAP error code: ", $ldap_msg->code );
    SPOPS::Error->set({ user_msg   => $user_msg,
                        system_msg => $system_msg,
                        type       => 'db',
                        extra      => { code => $ldap_msg->code } });
    die "$SPOPS::Error::user_msg\n";
}


# Build the full DN

sub build_dn {
    my ( $item, $p ) = @_;
    my $base_dn        = $p->{base_dn}  || $item->base_dn( $p->{connect_key} );
    my $id_field       = $p->{id_field} || $item->id_field;
    my $id_value_field = $p->{id_value_field} || $item->id_value_field;
    my $id_value       = $p->{id};
    unless ( $id_value ) {
        unless ( ref $item ) {
            die "Cannot create DN for object without an ID value as parameter ",
                "when called as class method\n";
        }
        $id_value = $item->{ $id_value_field } || $item->id;
        unless ( $id_value ) {
            die "Cannot create DN for object without an ID value\n";
        }
    }
    unless ( $id_field and $id_value and $base_dn ) {
        die "Cannot create Base DN without all parts\n",
            "ID field: ($id_field); ID: ($id_value); Base DN: ($base_dn)\n";
    }
    return join( ',', join( '=', $id_field, $id_value ), $base_dn );
}

1;

__END__

=pod

=head1 NAME

SPOPS::LDAP - Implement object persistence in an LDAP datastore

=head1 SYNOPSIS

 use strict;
 use SPOPS::Initialize;

 # Normal SPOPS configuration

 my $config = {
    class      => 'My::LDAP',
    isa        => [ qw/ SPOPS::LDAP / ],
    field      => [ qw/ cn sn givenname displayname mail
                        telephonenumber objectclass uid ou / ],
    id_field   => 'uid',
    ldap_base_dn => 'ou=People,dc=MyCompany,dc=com',
    multivalue => [ qw/ objectclass / ],
    creation_security => {
                 u => undef,
                 g   => { 3 => 'WRITE' },
                 w   => 'READ',
    },
    track        => { create => 0, update => 1, remove => 1 },
    display      => { url => '/Person/show/' },
    name         => 'givenname',
    object_name  => 'Person',
 };

 # Minimal connection handling...

 sub My::LDAP::global_datasource_handle {
     my $ldap = Net::LDAP->new( 'localhost' );
     $ldap->bind;
     return $ldap;
 }

 # Create the class

 SPOPS::Initialize->process({ config => $config });

 # Search for a group of objects and display information

 my $ldap_filter = '&(objectclass=inetOrgPerson)(mail=*cwinters.com)';
 my $list = My::LDAP->fetch_group({ where => $ldap_filter });
 foreach my $object ( @{ $list } ) {
     print "Name: $object->{givenname} at $object->{mail}\n";
 }

 # The same thing, but with an iterator

 my $ldap_filter = '&(objectclass=inetOrgPerson)(mail=*cwinters.com)';
 my $iter = My::LDAP->fetch_iterator({ where => $ldap_filter });
 while ( my $object = $iter->get_next ) {
     print "Name: $object->{givenname} at $object->{mail}\n";
 }

=head1 DESCRIPTION

This class implements object persistence in an LDAP datastore. It is
similar to L<SPOPS::DBI> but with some important differences -- LDAP
gurus can certainly find more:

=over 4

=item *

LDAP supports multiple-valued properties.

=item *

Rather than tables, LDAP supports a hierarchy of data information,
stored in a tree. An object can be at any level of a tree under a
particular branch.

=item *

LDAP supports referrals, or punting a query off to another
server. (SPOPS does not support referrals yet, but we fake it with
L<SPOPS::LDAP::MultiDatasource>.)

=back

=head1 CONFIGURATION

Configuration of an C<SPOPS::LDAP> data object is similar to that of
other SPOPS objects, with a few modifications.

=over 4

=item *

B<isa> (\@)

Same as a normal SPOPS field, but it must have C<SPOPS::LDAP> in it.

=item *

B<base_dn> ($)

DN in an LDAP tree where this object is located. For instance, the
common 'inetOrgPerson' type of object might be located under:

  base_dn  => 'ou=People,dc=MyCompany,dc=com'

While 'printer' objects might be located under:

  base_dn  => 'ou=Equipment,dc=MyCompany,dc=com'

Note that L<SPOPS::LDAP::MultiDatasource> allows you to specify a
partial DN on a per-datasource basis.

=item *

B<ldap_object_class> (\@)

When you create a new object you can specify the LDAP object class
yourself when creating the object or C<SPOPS::LDAP> can do it for you
behind the scenes. If you specify one or more LDAP object class
strings here they will be used whenever you create a new object and
save it.

Example:

 ldap_object_class => [ 'top', 'person', 'inetOrgPerson',
                        'organizationalPerson' ]

=item *

B<ldap_fetch_object_class> ($) (optional)

Specify an objectclass here to ensure your results are restricted
properly. This is also used to do an 'empty' search and find all
records of a particular class.

NOTE: This is B<only> used with the C<fetch_group()> and
C<fetch_iterator()> methods.

Example:

 ldap_fetch_object_class => 'person'

=item *

B<multivalue> (\@) (optional)

You B<must> list the fields here that may have multiple values in the
directory. Otherwise the object will have only one of the values and,
on saving the object, will probably wipe out all the others.

Example:

 multivalue  => [ 'objectclass', 'cn' ]

=item *

B<id_value_field> ($) (optional)

Returns the field used for the ID value (a string) in this object. By
default this is the value stored in 'id_field', but there are cases
where you may wish to use a particular fieldname for the DN of an
object and the value from another field.

=back

=head1 METHODS

=head2 Configuration Methods

See relevant discussion for each of these items under L<CONFIGURATION>
(configuration key name is the same as the method name).

B<base_dn> (Returns: $)

B<ldap_objectclass> (Returns: \@) (optional)

B<id_value_field> (Returns: $) (optional)

=head2 Datasource Methdods

B<global_datasource_handle( [ $connect_key ] )>

You need to create a method to return a datasource handle for use by
the various methods of this class. You can also pass in a handle
directory using the parameter 'ldap':

 # This object has a 'global_datasource_handle' method

 my $object = My::Object->fetch( 'blah' );

 # This object does not

 my $object = Your::Object->fetch( 'blah', { ldap => $ldap });

Should return: L<Net::LDAP> (or compatible) connection object that
optionally maps to C<$connect_key>.

You can configure your objects to use multiple datasources when
certain conditions are found. For instance, you can configure the
C<fetch()> operation to cycle through a list of datasources until an
object is found -- see L<SPOPS::LDAP::MultiDatasource> for an example.

=head2 Class Initialization

B<class_initialize()>

Just create the 'field_list' configuration parameter.

=head2 Object Information

B<dn( [ $new_dn ] )>

Retrieves and potentially sets the DN (distinguished name) for a
particular object. This is done automatically when you call C<fetch()>
or C<fetch_group()> to retrieve objects so you can always access the
DN for an object. If the DN is empty the object has not yet been
serialized to the LDAP datastore. (You can also call the SPOPS method
C<is_saved()> to check this.)

Returns: DN for this object

B<build_dn()>

Builds a DN from an object -- you should never need to call this and
it might disappear in future versions, only to be used internally.

=head2 Object Serialization

Note that you can pass in the following parameters for any of these
methods:

=over 4

=item *

B<ldap>: A L<Net::LDAP> connection object.

=item *

B<connect_key>: A connection key to use for a particular LDAP
connection.

=back

B<fetch( $id, \%params )>

Retrieve an object with ID C<$id> or matching other specified
parameters.

Parameters:

=over 4

=item *

B<filter> ($)

Use the given filter to find an object. Note that the method will die
if you get more than one entry back as a result.

(Synonym: 'where')

=back

B<fetch_by_dn( $dn, \%params )>

Retrieve an object by a full DN (C<$dn>).

B<fetch_group( \%params )>

Retrieve a group of objects

B<fetch_iterator( \%params )>

Instead of returning an arrayref of results, return an object of class
L<SPOPS::Iterator::LDAP>.

Parameters are the same as C<fetch_group()>.

B<save( \%params )>

Save an LDAP object to the datastore. This is quite straightforward.

B<remove( \%params )>

Remove an LDAP object to the datastore. This is quite straightforward.

=head1 BUGS

B<Renaming of DNs not supported>

Moving an object from one DN to another is not currently supported.

=head1 TO DO

B<More Usage>

I have only tested this on an OpenLDAP (version 2.0.11) server. Since
we are using L<Net::LDAP> for the interface, we should (B<in theory>)
have no problems connecting to other LDAP servers such as iPlanet
Directory Server, Novell NDS or Microsoft Active Directory.

It would also be good to test with a wider variety of schemas and
objects.

B<Expand LDAP Interfaces>

Currently we use L<Net::LDAP> to interface with the LDAP directory,
but Perl/C libraries may be faster and provide different
features. Once this is needed, we will probably need to create
implementation-specific subclasses. This should not be very difficult
-- the actual calls to C<Net::LDAP> are minimal and straightforward.

=head1 SEE ALSO

L<Net::LDAP>

L<SPOPS::Iterator::LDAP>

L<SPOPS>

=head1 COPYRIGHT

Copyright (c) 2001 MSN Marketing Service Nordwest, GmbH. All rights
reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
