package SPOPS::DBI;

# $Id: DBI.pm,v 1.62 2002/01/14 02:54:28 lachoy Exp $

use strict;
use Data::Dumper  qw( Dumper );
use DBI           ();
use SPOPS         qw( _wm _w DEBUG );
use SPOPS::Exception::DBI;
use SPOPS::Iterator::DBI;
use SPOPS::Secure qw( :level );
use SPOPS::SQLInterface;
use SPOPS::Tie    qw( $PREFIX_INTERNAL );

@SPOPS::DBI::ISA       = qw( SPOPS  SPOPS::SQLInterface );
$SPOPS::DBI::VERSION   = '1.90';
$SPOPS::DBI::Revision  = substr(q$Revision: 1.62 $, 10);

$SPOPS::DBI::GUESS_ID_FIELD_TYPE = DBI::SQL_INTEGER();

use constant DEBUG_FETCH  => 0;
use constant DEBUG_SAVE   => 0;

########################################
# CONFIGURATION
########################################

# Point by default to configuration values; children
# can override with hardcoded values if desired

sub no_insert_id  { return 0; } # used anymore??
sub field_alter   { return $_[0]->CONFIG->{field_alter} || {}  }
sub base_table    { return $_[0]->CONFIG->{base_table}         }
sub key_table     { return $_[0]->CONFIG->{key_table}   || $_[0]->CONFIG->{base_table} }
sub table_name    { return $_[0]->CONFIG->{table_name}  || $_[0]->CONFIG->{base_table} }
sub no_insert     { return $_[0]->CONFIG->{no_insert}   || {}  }
sub no_update     { return $_[0]->CONFIG->{no_update}   || {}  }
sub skip_undef    { return $_[0]->CONFIG->{skip_undef}  || {}  }
sub no_save_sync  { return $_[0]->CONFIG->{no_save_sync}       }


########################################
# CLASS CONFIGURATION
########################################

sub behavior_factory {
    my ( $class ) = @_;
    require SPOPS::ClassFactory::DBI;
    DEBUG() && _w( 1, "Installing SPOPS::DBI behaviors for ($class)" );
    return { links_to  => \&SPOPS::ClassFactory::DBI::conf_relate_links_to,
             id_method => \&SPOPS::ClassFactory::DBI::conf_multi_field_key_id,
             read_code => \&SPOPS::ClassFactory::DBI::conf_multi_field_key_other };
}


########################################
# CONNECTION RETRIEVAL
########################################

# Override this to get the db handle from somewhere

sub global_datasource_handle { return undef }

# Backward compatible

sub global_db_handle         { my $o = shift; return $o->global_datasource_handle( @_ ) }


########################################
# SQL DEFAULTS
########################################

# This is (I think) an ANSI SQL default for returning
# the current date/datetime; db-specific modules should
# override as needed, although you can also simply call
#
#    my $formatted_date = $obj->now; (or SPOPS::Utility->now)
#
# And format as needed (See SPOPS::Utility->now) for direct insert.

sub sql_current_date  { return 'CURRENT_TIMESTAMP()' }
sub sql_fetch_types   { return "SELECT * FROM $_[1] WHERE 1 = 0" }


########################################
# CLASS INITIALIZATION
########################################

# Make this the default for everyone -- they can override it
# themselves...

sub class_initialize {
    my ( $class, $CONFIG )  = @_;
    $CONFIG ||= {};
    my $C = $class->CONFIG;
    $C->{field_list}  = [ sort{ $C->{field}{$a} <=> $C->{field}{$b} }
                          keys %{ $C->{field} } ];
    $C->{table_owner} = $CONFIG->{db_info}{db_owner};
    $C->{table_name}  = ( $C->{table_owner} )
                          ? "$C->{table_owner}.$C->{base_table}" : $C->{base_table};

    # For databases that cannot respond properly to $sth->{TYPE} commands,
    # users need to specify the type information for their fields
    #
    # Types can be: int, num, float, char, date
    #
    # Currently known offenders: none! (DBD::ASAny was fixed -- hooray
    # for open source!)

    if ( ref $C->{dbi_type_info} eq 'HASH' ) {
        $class->assign_dbi_type_info( $C->{dbi_type_info} );
    }
    $class->_class_initialize( $CONFIG ); # allow subclasses to do their own thing
    return 1;
}


sub _class_initialize { return 1 }


########################################
# OBJECT IDENTIFICATION
########################################

# Generic method to return a SQL clause to identify a particular
# record -- a suitable for a where clause:
#   page_id = 5
#   comment_id = '818172723'

sub id_clause {
    my ( $item, $id, $opt, $p ) = @_;
    $p->{DEBUG} ||= DEBUG_FETCH;

    $opt ||= '';
    $p   ||= {};

    # If we weren't passed an ID and $item isn't an
    # object, there's a problem

    unless ( $id or ref( $item ) ) {
        _w( 0, "No ID passed in and called as a class method rather than",
               "an object method." );
        return undef;
    }
    $id ||= $item->id;

    my $db = $p->{db} || $item->global_datasource_handle( $p->{connect_key} );
    unless ( $db ) {
        my $error = 'Cannot create ID clause because no database handle accessible.';
        SPOPS::Exception->throw( $error );
    }

    my $id_field  = $item->id_field;
    my $type_info = eval { $item->db_discover_types( $item->base_table,
                                                     { dbi_type_info => $p->{dbi_type_info},
                                                       db            => $db,
                                                       DEBUG         => $p->{DEBUG} } ) };

    # If we cannot get the type via our own system, just guess that the
    # ID field is a number

    if ( $@ ) {
        $type_info->{ $id_field } = $SPOPS::DBI::GUESS_ID_FIELD_TYPE;
        _w( 0, "Likely was not passed sufficient information to ",
               "get infromation requested. Making a 'best guess'" );
    }
    my $use_id_field = ( $opt eq 'noqualify' )
                         ? $id_field
                         : join( '.', $item->table_name, $id_field );
    return join(' = ', $use_id_field, $db->quote( $id, $type_info->{ lc $id_field } ) );
}


########################################
# FETCHING
########################################

# Allows the user to define how fields will be formatted
# in a SELECT (date formatting, substrings, etc)

sub format_select {
    my ( $class, $fields, $conf ) = @_;
    $conf ||= {};
    my $typeof = ref $fields;
    unless ( $typeof eq 'ARRAY' ) {
        my $error = "Fields passed in for referring to format must be " .
                    "an arrayref (Type: $typeof)";
        SPOPS::Exception->throw( $error );
    }
    my @return_fields;
    my $altered = $class->field_alter();
    foreach my $field ( @{ $fields } ) {
        push @return_fields, $conf->{ $field } || $altered->{ $field } || $field;
    }
    return \@return_fields;
}


sub fetch {
    my ( $class, $id, $p ) = @_;
    $p->{DEBUG} ||= DEBUG_FETCH;
    $p->{DEBUG} && _wm( 2, $p->{DEBUG}, "Trying to fetch an item of $class with ID $id and params ",
                           join " // ",
                                map { $_ . ' -> ' . ( defined( $p->{$_} ) ? $p->{$_} : '' ) }
                                    keys %{ $p } );

    # No ID, no object

    return undef  unless ( defined( $id ) and $id !~ /^tmp/ );

    # Security violations bubble up to caller

    my $level = $p->{security_level};
    unless ( $p->{skip_security} ) {
        $level ||= $class->check_action_security({ id       => $id, DEBUG => $p->{DEBUG},
                                                   required => SEC_LEVEL_READ });
    }

    # Do any actions the class wants before fetching -- note that if
    # any of the actions returns undef (false), we bail.

    return undef unless ( $class->pre_fetch_action( { %{ $p }, id => $id } ) );

    my $obj = undef;

    # If we were passed the data for an object, go ahead and create
    # it; if not, check to see if we can whip up a cached object

    if ( ref $p->{data} eq 'HASH' ) {
        $obj = $class->new({ %{ $p->{data} }, skip_default_values => 1 });
    }
    else {
        $obj = $class->get_cached_object({ %{ $p }, id => $id });
        $p->{skip_cache}++;         # Set so we don't re-cache it later
    }

    unless ( ref $obj eq $class ) {
        my ( $raw_fields, $select_fields ) = $class->_fetch_select_fields( $p );
        $p->{DEBUG} && _wm( 1, $p->{DEBUG}, "SELECTing: ", join( "//", @{ $select_fields } ) );

        # Put all the arguments into a hash (so we can reuse them simply
        # later) and grab the record

        my %args = ( from   => [ $class->table_name ],
                     select => $select_fields,
                     where  => $class->id_clause( $id, undef, $p ),
                     db     => $p->{db},
                     return => 'single',
                     DEBUG  => $p->{DEBUG} );
        my $row = eval { $class->db_select( \%args ) };
        if ( $@ ) {
            $class->fail_fetch( \%args );
            die $@;
        }

        # If the row isn't found, return nothing; just as if an incorrect
        # (or nonexistent) ID were passed in

        return undef unless ( $row );

        # Note that we pass $p along to the ->new() method, in case
        # other information was passed in needed by it -- however, we
        # need to be careful that certain parameters used by this
        # method (e.g., the optional 'field_alter') is not the same as
        # a parameter of an object -- THAT would be fun to debug...

        $obj = $class->new({ id => $id, skip_default_values => 1, %{ $p } });
        $obj->_fetch_assign_row( $raw_fields, $row, $p );
    }
    return $obj->_fetch_post_process( $p, $level );
}



sub fetch_iterator {
    my ( $class, $p ) = @_;
    $p->{DEBUG} ||= DEBUG_FETCH;
    $p->{DEBUG} && _wm( 1, $p->{DEBUG}, "Trying to create an Iterator with: ", Dumper( $p ) );
    ( $p->{fields}, $p->{select} ) = $class->_construct_group_select( $p );
    $p->{class}                    = $class;
    ( $p->{offset}, $p->{max} )    = $class->fetch_determine_limit( $p->{limit} );
    unless ( ref $p->{id_list} ) {
        $p->{sth} = $class->_execute_multiple_record_query( $p );
    }
    return SPOPS::Iterator::DBI->new( $p );
}


# TODO: Put the pre_fetch_action in here

sub fetch_group {
    my ( $class, $p ) = @_;
    $p->{DEBUG} ||= DEBUG_FETCH;
    ( $p->{raw_fields}, $p->{select} ) = $class->_construct_group_select( $p );
    my $sth              = $class->_execute_multiple_record_query( $p );
    my ( $offset, $max ) = $class->fetch_determine_limit( $p->{limit} );
    my @obj_list = ();

    my $row_count = 0;
ROW:
    while ( my $row = $sth->fetchrow_arrayref ) {
        my $obj = $class->new({ skip_default_values => 1 });
        $obj->_fetch_assign_row( $p->{raw_fields}, $row, $p );
        next ROW unless ( $obj );

        # Check security on the row unless overridden by
        # 'skip_security'. If the security check fails that's ok, just
        # skip the row and move on

        my $sec_level = SEC_LEVEL_WRITE;
        unless ( $p->{skip_security} ) {
            $sec_level = eval { $obj->check_action_security({
                                          required => SEC_LEVEL_READ }) };
            if ( $@ ) {
                $p->{DEBUG} && _wm( 1, $p->{DEBUG}, "Security check for object in ",
                                          "fetch_group() failed, skipping." );
                next ROW;
            }
        }

        # Not to the offset yet, so go to the next row but still increment
        # the counter so we calculate limits properly

        if ( $offset and ( $row_count < $offset ) ) {
            $row_count++;
            next ROW;
        }
        last ROW if ( $max and ( $row_count >= $max ) );
        $row_count++;

        # If we've made it down to here, we're home free; just call the
        # post_fetch callback

        next ROW unless ( $obj->_fetch_post_process( $p, $sec_level ) );
        push @obj_list, $obj;
    }
    $sth->finish;
    return \@obj_list;
}


# Take the fields that are just columns and prepend them with the
# table name; other columns are assumed to be taken care of

sub _construct_group_select {
    my ( $class, $p ) = @_;
    my $table_name = $class->table_name;
    my ( $raw_fields, $select_fields ) = $class->_fetch_select_fields( $p );
    my @select = ();
    for ( my $i = 0; $i < scalar @{ $raw_fields }; $i++ ) {
        if ( $raw_fields->[ $i ] ne $select_fields->[ $i ] ) {
            push @select, $select_fields->[ $i ];
        }
        elsif ( $raw_fields->[ $i ] =~ /^$table_name\./ ) {
            push @select, $select_fields->[ $i ];
        }
        else {
            push @select, join( '.', $table_name, $raw_fields->[ $i ] );
        }
    }
    return ( $raw_fields, \@select );
}


# Find the number of objects that would have been returned from a
# query, including security. Note that we only fetch the ID field
# here...

sub fetch_count {
    my ( $class, $p ) = @_;
    $p->{select} = [ $class->id_field ];
    my $sth = $class->_execute_multiple_record_query( $p );
    my $row_count = 0;
    while ( my $row = $sth->fetch ) {
        eval { $class->check_action_security({ id       => $row->[0],
                                               required => SEC_LEVEL_READ }) };
        next if ( $@ );
        $row_count++;
    }
  return $row_count;
}


sub _execute_multiple_record_query {
    my ( $class, $p ) = @_;
    $p->{from}   ||= [ $class->table_name ];
    $p->{select} ||= $class->_fetch_select_fields( $p );
    $p->{return}   = 'sth';
    $p->{DEBUG}  ||= DEBUG_FETCH;
    $p->{db}     ||= $class->global_datasource_handle( $p->{connect_key} );

    # We return a DBI statement handle here so we can scroll through the
    # rows without assigning them all.

    return $class->db_select( $p );
}


# field_list has precedence, then column_group, then 'all'

sub _fetch_select_fields {
    my ( $class, $p ) = @_;
    my $field_list = $p->{field_list};

    # If we were given a column group then grab its fields, ensuring
    # that the ID field is in there as well. If the column group
    # specified doesn't exist, then the $field_list is empty and will be
    # filled with all the fields below.

    if ( ! $field_list and $p->{column_group} ) {
        DEBUG() && _w( 1, "Trying to retrieve fields for column group ($p->{column_group})" );
        if ( $p->{column_group} eq '_id_field' ) {
            $field_list = [ scalar $class->id_field ];
        }
        else {
            my $column_defs = $class->CONFIG->{column_group} || {};
            $field_list = $column_defs->{ $p->{column_group} };
            if ( ref $field_list eq 'ARRAY' and scalar @{ $field_list } ) {
                my %field_hash = map { $_ => 1 } @{ $field_list }, $class->id_field;
                $field_list = [ keys %field_hash ];
            }
        }
        DEBUG() && _w( 2, "Found field list from column group: ", Dumper( $field_list ) );
    }

    # If the fields weren't passed in and we're not using a column
    # group, then use all the fields

    $field_list ||= $class->field_list;
    my @alter_field_list = @{ $field_list };

    # If the user passed in extra fields for the SELECT (for
    # instances, if 'having' criteria is used) then they always go on
    # the end of the SELECT

    if ( $p->{field_extra} ) {
        push @alter_field_list, ( ref $p->{field_extra} eq 'ARRAY' )
                                  ? @{ $p->{field_extra} } : $p->{field_extra};
    }
    return ( $field_list, $class->format_select( \@alter_field_list, $p->{field_alter} ) );
}


# Assign the fetched values to an object. Note that we clear all the
# 'loaded' flags first.

sub _fetch_assign_row {
    my ( $self, $fields, $row, $p ) = @_;
    $p->{DEBUG} ||= DEBUG_FETCH;
    $p->{DEBUG} && _wm( 1, $p->{DEBUG}, "Setting data from row into", ref $self );
    $self->clear_all_loaded();
    foreach my $i ( 0 .. ( scalar @{ $row } - 1 ) ) {
        $p->{DEBUG} && _wm( 1, $p->{DEBUG}, sprintf( " %-20s --> %s", $fields->[ $i ], substr( $row->[ $i ], 0, 10 ) ) );
        $self->{ $fields->[ $i ] } = $row->[ $i ];
        $self->set_loaded( $fields->[ $i ] );
    }
}


sub _fetch_post_process {
    my ( $self, $p, $level ) = @_;

    # Create an entry for this object in the cache unless either the
    # class or this call to fetch() doesn't want us to.

    $self->set_cached_object( $p );

    # Execute any actions the class (or any parent) wants after
    # creating the object (see SPOPS.pm)

    return undef unless ( $self->post_fetch_action( $p ) );

    # Clear the 'changed' flag

    $self->clear_change;

    # Mark this as being a saved object

    $self->has_save;

    # Set the security fetched from above into this object
    # as a temporary property (see SPOPS::Tie for more info
    # on temporary properties); note that this is set whether
    # we retrieve a cached copy or not

    $self->{tmp_security_level} = $level;
    $p->{DEBUG} && _wm( 1, $p->{DEBUG},
                    ref $self, "(", $self->id, ") : cache set (if available),",
                    "post_fetch_action() done, change flag cleared and save ",
                    "flag set. Security: $level" );
    return $self;
}


########################################
# LAZY LOADING
########################################

# This is to be passed to SPOPS::Tie as a coderef so it can do a
# lazy-load a field that hasn't yet been loaded (fetched) so instead
# of having an inner (unnamed) sub doing the work, we just create a
# wrapper.

sub get_lazy_load_sub {
    return \&perform_lazy_load;
}

sub perform_lazy_load {
    my ( $class, $data, $field ) = @_;
    DEBUG() && _w( 3, "Performing lazy load for $class -> $field" );
    unless ( ref $data eq 'HASH' ) {
        SPOPS::Exception->throw( 'No object data given -- cannot lazy load!' );
    }
    unless ( $field ) {
        SPOPS::Exception->throw( 'No field given -- cannot lazy load!' );
    }
    my %args = ( from   => [ $class->table_name ],
                 select => [ $field ],
                 where  => $class->id_clause( $data->{ $class->id_field } ),
                 return => 'single',
                 DEBUG  => DEBUG );
    my $row = $class->db_select( \%args );
    return $row->[0];
}


########################################
# SAVING
########################################


sub save {
    my ( $self, $p ) = @_;
    $p->{DEBUG} ||= DEBUG_SAVE;
    $p->{DEBUG} && _wm( 1, $p->{DEBUG}, "Trying to save a (", ref $self, ")" );

    # We can force save() to be an INSERT by passing in a true value
    # for the is_add parameter; otherwise, we rely on the flag within
    # SPOPS::Tie to reflect whether an object has been saved or not.

    my $is_add = ( $p->{is_add} or ! $self->saved );

    # If this is an update and it hasn't changed, we don't need to do
    # anything.

    unless ( $is_add or $self->changed ) {
        $p->{DEBUG} && _wm( 1, $p->{DEBUG}, "This object exists and has not changed. Exiting." );
        return $self;
    }

    # Check security for create/update

    my $action = ( $is_add ) ? 'create' : 'update';
    my ( $level );
    unless ( $p->{skip_security} ) {
        $level = $self->check_action_security({ required => SEC_LEVEL_WRITE,
                                                is_add   => $is_add });
    }
    $p->{DEBUG} && _wm( 1, $p->{DEBUG}, "Security check passed ok. Continuing." );

    # Callback for objects to do something before they're saved

    return undef unless ( $self->pre_save_action({ %{ $p },
                                                   is_add => $is_add }) );

    # Do not include these fields in the insert/update at all

    my $not_included = ( $is_add ) ? $self->no_insert : $self->no_update;

    # Do not include these fields in the insert/update if they're not defined
    # (note that this includes blank/empty)

    my $skip_undef   = $self->skip_undef;

FIELD:
    foreach my $field ( keys %{ $self->field } ) {
        next FIELD if ( $not_included->{ $field } );
        my $value = $self->{ $field };
        next FIELD if ( ! defined $value and $skip_undef->{ $field } );
        push @{ $p->{field} }, $field;
        push @{ $p->{value} }, $value;
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

    unless ( $p->{skip_log} ) {
        $self->log_action( $action, scalar $self->id );
    }

    # Set flags and return the object so we can do chained method calls

    $self->has_save;
    $self->clear_change;
    return $self;
}

# Called by _save_insert()

sub pre_fetch_id  { return undef }
sub post_fetch_id { return undef }

sub _save_insert {
    my ( $self, $p ) = @_;
    $p ||= {};
    $p->{DEBUG} ||= DEBUG_SAVE;
    $p->{DEBUG} && _wm( 1, $p->{DEBUG}, "Treating the save as an INSERT." );

    my $db = $p->{db} || $self->global_datasource_handle( $p->{connect_key} );

    # Ability to get the ID you want before the insert statement
    # is executed. If something is returned, push the value
    # plus the ID field onto the appropriate stack.

    my $pre_id = $self->pre_fetch_id( { %{ $p }, db => $db } );
    if ( $pre_id ) {
        $self->id( $pre_id );
        push @{ $p->{field} }, $self->id_field;
        push @{ $p->{value} }, $self->id;
        $p->{DEBUG} && _wm( 1, $p->{DEBUG}, "Retrieved ID before insert: $pre_id" );
    }

    # Do the insert; ask DB to return the statement handle
    # if we need it for getting the just-inserted ID; note that
    # both 'field' and 'value' are in $p, so we do not need to
    # specify them in the %args
    #
    # Note also that we pass \%p in just in case we want to tell
    # db_insert not to quote anything from the original call.

    my %args = ( table      => $self->table_name,
                 return_sth => 1,
                 db         => $db,
                 %{ $p } );
    my $sth = $self->db_insert( \%args );
    if ( $@ ) {
        _w( 0, "Insert failed! Args: ", Dumper( \%args ), $@ );
        $self->fail_save( \%args );
        die $@;
    }

    # Ability to get the ID from the statement just inserted
    # via an overridden subclass method; if something is
    # returned, set the ID in the object.

    my $post_id = $self->post_fetch_id( { %{ $p }, db => $db,
                                          statement => $sth } );
    if ( $post_id ) {	
        $self->id( $post_id );
        $p->{DEBUG} && _wm( 1, $p->{DEBUG}, "ID fetched after insert: $post_id" );
    }

    # Here we actually re-fetch any new information from the database
    # since on an insert any DEFAULT values might have kicked in. The config
    # of the object should include a list called 'sql_defaults' that have
    # all the fields defined something like this:
    #   expired    char(3) default 'no'
    # so that we can match up what's in the db with the object.

    unless ( $p->{no_sync} or $self->no_save_sync ) {
        my $fill_in_fields = $self->CONFIG->{sql_defaults} || [];
        if ( scalar @{ $fill_in_fields } ) {
            $p->{DEBUG} && _wm( 1, $p->{DEBUG}, "Fetching defaults for fields ",
                              join( ' // ', @{ $fill_in_fields } ), " after insert." );
            my $row = eval { $self->db_select({
                                 from   => [ $self->table_name ],
                                 select => $fill_in_fields,
                                 where  => $self->id_clause( undef, undef, $p ),
                                 db     => $p->{db},
                                 return => 'single',
                                 DEBUG  => $p->{DEBUG} }) };

            # Even though there was an error, we probably want to continue
            # processing... I'm ambivalent about this.

            if ( $@ ) {
                _w( 0, "Cannot refetch row: $@" );
            }
            else {
                for ( my $i = 0; $i < scalar @{ $fill_in_fields }; $i++ ) {
                    $p->{DEBUG} && _wm( 2, $p->{DEBUG}, "Setting $fill_in_fields->[$i] to $row->[$i]" );
                    $self->{ $fill_in_fields->[ $i ] } = $row->[ $i ];
                }
            }
        }
    }

    # Now create the initial security for this object unless
    # we have requested to skip it

    # TODO: Check this -- should skip_security only mean that we don't
    # want to check security for saving? Should it mean we skip it
    # ENTIRELY, as if it's not there? (I suspect not...)

    unless ( $p->{skip_security} ) {
        $self->create_initial_security({ object_id => scalar $self->id });
    }
    return 1;
}


sub _save_update {
    my ( $self, $p ) = @_;
    $p->{DEBUG} ||= DEBUG_SAVE;

    # If the ID of the object is changing, we still need to be able to
    # refer to the row with its old ID; allow the user to pass in the old
    # ID in this case so we can create the ID clause with it

    my $id_clause = ( $p->{use_id} )
                      ? $self->id_clause( $p->{use_id}, undef, $p )
                      : $self->id_clause( undef, undef, $p );
    $p->{DEBUG} && _wm( 1, $p->{DEBUG}, "Processing save as UPDATE with clause ($id_clause)" );

    # Note that the 'field' and 'value' parameters are in $p and
    # exist when the hashref is expanded into %args

    my %args = ( where => $id_clause,
                 table => $self->table_name,
                 %{ $p } );
    my $rv =  eval { $self->db_update( \%args ); };
    if ( $@ ) {
        _w( 0, "Update failed! Args: ", Dumper( \%args ), $@ );
        $self->fail_save( \%args );
        die $@;
    }
    return 1;
}


########################################
# REMOVING
########################################

sub remove {
    my ( $self, $p ) = @_;

    # Don't remove it unless it's been saved already

    return undef   unless ( $self->is_saved );
    $p->{DEBUG} ||= DEBUG;

    my $level = SEC_LEVEL_WRITE;
    unless ( $p->{skip_security} ) {
        $level = $self->check_action_security({ required => SEC_LEVEL_WRITE });
    }

    $p->{DEBUG} && _wm( 1, $p->{DEBUG}, "Security check passed ok. Continuing." );

    # Allow members to perform an action before getting removed

    return undef unless ( $self->pre_remove_action( $p ) );

    # Do the removal, building the where clause if necessary

    my $where = $p->{where} || $self->id_clause( undef, undef, $p );
    my $id = $self->id;
    my $rv = eval { $self->db_delete({
                            table => $self->table_name,
                            where => $where,
                            value => $p->{value},
                            db    => $p->{db},
                            DEBUG => $p->{DEBUG} }) };

    if ( $@ ) {
        $self->fail_remove;
        die $@
    }

    # Otherwise...
    # ... remove this item from the cache

    if ( $self->use_cache( $p ) ) {
        $self->global_cache->clear({ data => $self });
    }

    # ... execute any actions after a successful removal

    return undef unless ( $self->post_remove_action( $p ) );

    # ... and log the deletion

    $self->log_action( 'delete', $id ) unless ( $p->{skip_log} );

    # Clear out the 'changed' and 'saved' flags

    $self->clear_change;
    $self->clear_save;
    return 1;
}

1;

__END__

=pod

=head1 NAME

SPOPS::DBI -- Implement SPOPS class, serializing into a DBI database

=head1 SYNOPSIS

 use SPOPS::DBI;
 @ISA = qw( SPOPS::DBI );
 ...

=head1 DESCRIPTION

This SPOPS class is not meant to be used directly.  Instead, you
inherit certain methods from it while implementing your own. Your
module should implement:

=over 4

=item *

(optional) Methods to sort member objects or perform operations on
groups of them at once.

=item *

(optional) Methods to relate an object of this class to objects of
other classes -- for instance, to find all users within a group.

=item *

(optional) The initialization method (I<_class_initialize()>), which
should create a I<config()> object stored in the package variable and
initialize it with configuration information relevant to the class.

=item *

(optional) Methods to accomplish actions before/after many of the
actions implemented here: fetch/save/remove.

=item *

(optional) Methods to accomplish actions before/after saving or
removing an object from the cache.

=back

Of course, these methods can also do anything else you like. :-)

As you can see, all the methods are optional. Along with
L<SPOPS::ClassFactory|SPOPS::ClassFactory>, you can create an entirely virtual class
consisting only of configuration information. So you can actually
create the implementation for a new object in two steps:

=over 4

=item 1.

Create the configuration file (or add to the existing one)

=item 2.

Create the database table the class depends on.

=back

Complete!

=head1 DATABASE HANDLE

This package requires access to a database handle. We do not keep a
reference of the database handle with the object for complexity
reasons (but you can actually implement this if you would
like). Instead you either need to pass a database handle to a method
using the C<db> parameter or define a method in your object
C<global_datasource_handle()> which returns an appropriate database
handle. (Note: the old C<global_db_handle()> method is deprecated and
will be removed eventually.)

The latter sounds more difficult than it is. And if you have many
objects using the same handle it is definitely the way to go. For
instance, your database handle class could look like:

 package My::Object::DBI;

 use strict;

 # These next two are optional but enable you to change databases for
 # lots of objects very quickly.

 use SPOPS::DBI;
 use SPOPS::DBI::Pg;
 @My::Object::DBI::ISA = qw( SPOPS::DBI::Pg SPOPS::DBI );

 use constant DBI_DSN  => 'DBI:Pg:dbname=postgres';
 use constant DBI_USER => 'postgres';
 use constant DBI_PASS => 'postgres';

 my ( $DB );

 sub global_datasource_handle {
   unless ( ref $DB ) {
     $DB = DBI->connect( DBI_DSN, DBI_USER, DBI_PASS,
                         { RaiseError => 1, LongReadLen => 65536, LongTruncOk => 0 } )
               || SPOPS::Exception->throw( "Cannot connect! $DBI::errstr" );
   }
   return $DB;
 }

 1;

And all your objects can use this method simply by putting the class
in their 'isa' configuration key:

 $conf = {
    myobj => {
       isa => [ qw/ My::Object::DBI / ],
    },
 };

Now, your objects will have transparent access to a DBI data source.

=head1 DATA ACCESS METHODS

The following methods access configuration information about the class
but are specific to the DBI subclass. You can call all of them from
either the class (or subclass) or an instantiated object.

B<base_table> (Returns: $)

Just the table name, no owners or db names prepended.

B<table_name> (Returns: $)

Fully-qualified table name

B<field> (Returns: \%)

Hashref of fields/properties (field is key, value is true)

B<field_list> (Returns: \@)

Arrayref of fields/propreties

B<no_insert> (Returns: \%)

Hashref of fields not to insert (field is key, value is true)

B<no_update> (Returns: \%)

Hashref of fields not to update (field is key, value is true)

B<skip_undef> (Returns: \%)

Hashref of fields to skip update/insert if they are undefined (field
is key, value is true)

B<field_alter> (Returns: \%)

Hashref of data-formatting instructions (field is key, instruction is
value)

=head1 OBJECT METHODS

B<id_clause( [ $id, [ $opt, \%params ] )>

Returns a snippet of SQL suitable for identifying this object in the
database.

This can be called either from the class or from a particular
object. If called from a class, the $id value B<must> be passed
in. Examples:

 my $id = 35;
 my $sql = qq/
   DELETE FROM $table
    WHERE @{[ $class->id_clause( $id ) ]}
 /;
 print "SQL: $sql";

 >> SQL:
      DELETE FROM this_table
       WHERE this_table.this_id = 35

 $class->db_select( ... where => $class->id_clause( 15 ), ... )

If the system cannot determine the data type of the id field, it makes
a best guess based on the package variable GUESS_ID_FIELD_TYPE. It
defaults to SQL_INTEGER (as set by DBI), but you can set it
dynamically as well:

 $SPOPS::DBI::GUESS_ID_FIELD_TYPE = SQL_VARCHAR;

Note that the default behavior is to create a fully-qualified ID
field. If you do not wish to do this (for instance, if you need to use
the ID field for a lookup into a link table), just pass 'noqualify' as
the second argument. To use the example from above:

 my $id = 35;
 my $sql = qq/
   DELETE FROM $table
    WHERE @{[ $class->id_clause( $id, 'noqualify' ) ]}
 /;
 print "SQL: $sql";

 >> SQL:
      DELETE FROM this_table
       WHERE this_id = 35

B<fetch( $id, \%params )>

Fetches the information for an object of type class from the data
store, creates an object with the data and returns the object. Any
failures result in either an L<SPOPS::Exception|SPOPS::Exception> or
an L<SPOPS::Exception::DBI|SPOPS::Exception::DBI> object being thrown,
depending on the source of the error.

If you have security turned on for the object class, the system will
first check if the currently-configured user is allowed to fetch the
object. If the user has less that SEC_LEVEL_READ access, the fetch is
denied and a L<SPOPS::Exception::Security|SPOPS::Exception::Security>
object thrown.

Note that if the fetch is successful we store the access level of this
object within the object itself. Check the temporary property
{tmp_security_level} of any object and you will find it.

Parameters:

=over 4

=item *

B<column_group> ($) (optional)

Name a group of columns you want to fetch. Only the values for these
columns will be retrieved, and an arrayref of

=item *

B<field_alter> (\%) (optional)

fields are keys, values are database-dependent formatting strings. You
can accomplish different types of date-formatting or other
manipulation tricks.

=item *

B<DEBUG> (bool) (optional)

You can also pass a DEBUG value to get debugging information for that
particular statement dumped into the error log:

 my $obj = eval { $class->fetch( $id, { DEBUG => 1 } ); };

=back

B<fetch_group( \%params )>

Returns an arrayref of objects that meet the criteria you
specify.

This is actually fairly powerful. Examples:

 # Get all the user objects and put them in a hash
 # indexed by the id
 my %uid = map { $_->id => $_ } @{ $R->user->fetch_group({ order => 'last_name' }) };

 # Get only those user objects for people who have
 # logged in today
 my $users = $R->user->fetch_group( {
               where => 'datediff( dd, last_login, get_date() ) = 0',
               order => 'last_name'
             } );
 foreach my $user ( @{ $users } ) {
   print "User: $user->{login_name} logged in today.\n";
 }

Note that you can also return objects that match the results of a
join query:

 my $list = eval { $class->fetch_group({
                               order => 'item.this, item.that',
                               from => [ 'item', 'modifier' ],
                               where => 'modifier.property = ? AND ' .
                                        'item.item_id = modifier.item_id',
                               value => [ 'property value' ] } ) };

And you can use parameters found in C<fetch()>:

 my $list = eval { $class->fetch_group({ column_group => 'minimal' }) };

Parameters:

=over 4

=item *

B<where> ($)

A WHERE clause; leave this blank and you will get all entries

=item *

B<value> (\@)

If you use placeholders in your WHERE clause, put the values in order
in this parameter and they will be properly quoted.

=item *

B<order> ($)

An ORDER BY clause; leave this blank and the order is arbitrary
(whatever is normally returned by your database). Note that you can
have ORDER BY clauses that use more than one field, such as:

 order => 'active_date, updated_date DESC'

=item *

B<limit> ($)

You can limit the number of objects returned from this method. For
example, you might run a search but allow the user to specify a
maximum of 50 results per page. For each successive page displayed you
can retrieve only those specific results.

For instance, the following will return the first 10 records of a
result set:

 my $records = eval { $object_class->fetch_group({ where => "field = ?",
                                                   value => [ 'foo' ],
                                                   limit => '10' }) };

You can also return a particular number of records offset from the
beginning. The following will return results 21-30 of the result set.

 my $records = eval { $object_class->fetch_group({ where => "field = ?",
                                                   value => [ 'foo' ],
                                                   limit => '20,10' }) };

Other parameters get passed onto the fetch() statement when the
records are being retrieved.

=back

B<fetch_iterator \%params )>

Uses the same parameters as C<fetch_group()> but instead of returning
an arrayref with all the objects, it returns an
L<SPOPS::Iterator::DBI|SPOPS::Iterator::DBI> object. You can use this object to step
through the objects one at a time, which can be an enormous resource
savings if you are retrieving large groups of objects.

Example:

  my $iter = My::SPOPS->fetch_iterator({
                             where         => 'package = ?',
                             value         => [ 'base_theme' ],
                             order         => 'name' });
  while ( my $template = $iter->get_next ) {
      print "Item ", $iter->position, ": $template->{package} / $template->{name}";
      print " (", $iter->is_first, ") (", $iter->is_last, ")\n";
  }

All security restrictions are still upheld -- if a user cannot
retrieve an object with C<fetch()> or C<fetch_group()>, the user
cannot retrieve it with C<fetch_iterator()> either.

Parameters: see C<fetch_group()>.

B<fetch_count( \%params )>

Returns the number of objects that would have been returned from a
query. Note that this B<INCLUDES SECURITY CHECKS>. So running:

 my $query = { where => 'field = ?',
               value => 'broom' };
 my $just_count = $class->fetch_count( $query );
 $query->{order} = 'other_thingy';
 my $rows = $class->fetch_group( $query );
 print ( $just_count == scalar @{ $rows } )
       ? "Equal!"
       : "Not equal -- something's wrong!";

Should print "Equal!"

This method takes mostly the same parameters as C<fetch_group()>,
although ones like 'order' will not any functionality to the query but
will add time.

Parameters not used: 'limit'

B<save( [ \%params ] )>

Object method that saves this object to the data store.  Returns the
new ID of the object if it is an add; returns the object ID if it is
an update. As with other methods, any failures trigger an exception

Example:

 my $obj = $class->new;
 $obj->{param1} = $value1;
 $obj->{param2} = $value2;
 my $new_id = eval { $obj->save };
 if ( $@ ) {
   print "Error inserting object: $@\n";
 }
 else {
   print "New object created with ID: $new_id\n";
 }

The object can generally tell whether it should be created in the data
store or whether it should update the data store values. Currently it
determines this by the presence of an ID value. If an ID value exists,
this is probably an update; if it does not exist, it is probably a
save.

You can give SPOPS hints otherwise. If you are controlling ID values
yourself and an ID value exists in your object, you can do:

 $obj->save({ is_add => 1 });

to tell SPOPS to treat the request as a creation rather than an update.

One other thing to note if you are using L<SPOPS::Secure|SPOPS::Secure> for
security: SPOPS assumes that your application determines whether a
user can create an object. That is, all requests to create an object
are automatically approved. Once the object is created, the initial
security logic kicks in and any further actions (fetch/save/remove)
are controlled by C<SPOPS::Secure>.

Note that if your database schema includes something like:

 CREATE TABLE my_table (
  my_id      int,
  created_on datetime default today(),
  table_legs tinyint default 4
 )

and your object had the following values:

 my_id      => 10,
 created_on => undef,
 table_legs => undef

The only thing your object would reflect after inserting is the ID,
since the other values are filled in by the database. The I<save()>
method tries to take this into account and syncs the object up with
what is in the database once the record has been successfully
inserted. If you want to skip this step, either pass a positive value
for the 'no_sync' key or set 'no_save_sync' to a positive value in the
CONFIG of the implementing class.

B<remove( [ \%params ] )>

Note that you can only remove a saved object (duh). Also tries to
remove the object from the cache. The object will not actually be
destroyed until it goes out of scope, so do not count on its DESTROY
method being called exactly when this happens.

Returns 1 on success, throws exception on failure. Example:

 eval { $obj->remove };
 if ( $@ ) {
   print "Object not removed. Error: $@";
 }
 else {
   print "Object removed properly.";
 }

B<log_action( $action, $id )>

Implemented by subclass.

This method is passed the action performed upon an object ('create',
'update', 'remove') and the ID. SPOPS::DBI comes with an empty method,
but you can subclass it and do what you wish

=head1 LAZY LOADING

This class supports lazy loading, available in SPOPS 0.40 and
later. All you need to do is define one or more 'column_group' entries
in the configuration of your object and L<SPOPS|SPOPS> will do the rest.

If you are interested: the method C<perform_lazy_load()> does the
actual fetch of the field value.

B<Important Note>: If you use lazy loading, you B<must> define a
method C<global_datasource_handle()> (see L<DATABASE HANDLE> above)
for your object -- otherwise the C<perform_lazy_load()> method will
not be able to get it.

=head1 TO DO

B<Consistent Field Handling>

Since we use the {field_alter} directive to modify what is actually
selected from the database and use the _fetch_assign_row() to map
fieldnames to field positions, we need to have a generic way to map
these two things to each other. (It is not that difficult, just making
a note to deal with it later.)

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
