package SPOPS::DBI;

# $Header: /usr/local/cvsdocs/SPOPS/SPOPS/DBI.pm,v 1.52 2000/10/09 15:03:04 cwinters Exp $

use strict;
use SPOPS;
use SPOPS::SQLInterface;
use SPOPS::Secure qw( :level );
use Carp          qw( carp );
use DBI           ();
use Data::Dumper  qw( Dumper );

@SPOPS::DBI::ISA       = qw( SPOPS  SPOPS::SQLInterface );
@SPOPS::DBI::VERSION   = sprintf("%d.%02d", q$Revision: 1.52 $ =~ /(\d+)\.(\d+)/);

$SPOPS::DBI::GUESS_ID_FIELD_TYPE = DBI::SQL_INTEGER();

use constant DEBUG        => 0;
use constant DEBUG_FETCH  => 0;
use constant DEBUG_SAVE   => 0;

# For children to override as needed

# Called by save() and remove(); currently unimplemented
sub log_action    { return 1; }

# Called by save()
sub pre_fetch_id  { return undef; }
sub post_fetch_id { return undef; }

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

# Override this to get the db handle from somewhere
sub global_db_handle   { return undef; }

# This is (I think) an ANSI SQL default for returning
# the current date/datetime; db-specific modules should
# override as needed, although you can also simply call
#  $obj->now 
# And format as needed (See SPOPS->now) for direct insert.
sub sql_current_date  { return 'CURRENT_TIMESTAMP()' }
sub sql_fetch_types   { return "SELECT * FROM $_[1] WHERE 1 = 0" }

# Make this the default for everyone -- they can override it themselves...
sub class_initialize {
 my $class  = shift;
 my $CONFIG = shift || {};
 my $C = $class->CONFIG;
 $C->{field_list}  = [ sort{ $C->{field}->{$a} <=> $C->{field}->{$b} } keys %{ $C->{field} } ];
 $C->{table_owner} = $CONFIG->{db_info}->{db_owner};
 $C->{table_name}  = ( $C->{table_owner} ) ? "$C->{table_owner}.$C->{base_table}" : $C->{base_table};

 # For databases that cannot respond properly to $sth->{TYPE} commands,
 # users need to specify the type information for their fields
 #
 # Types can be: int, num, float, char, date
 #
 # Currently known offenders: DBD::ASAny
 if ( ref $C->{dbi_type_info} eq 'HASH' ) {
   $class->assign_dbi_type_info( $C->{dbi_type_info} );
 }
 $class->_class_initialize( $CONFIG ); # allow subclasses to do their own thing
 return 1;
}

# Dummy method for subclasses to override
sub _class_initialize { return 1; }

# Override the default SPOPS initialize call so
# we can use ->{id} and mixed-case fields
sub initialize {
 my $self = shift;
 my $p    = shift;
 return unless ( ref $p and scalar( keys %{ $p } ) );
 
 # We allow the user to substitute id => value instead for
 # the specific fieldname.
 $p->{ $self->id_field } ||= $p->{id};

 # Use all lowercase to allow people to 
 # give us fieldnames in mixed case (we are very nice)
 my %data = map { lc $_ => $p->{ $_ } } keys %{ $p };
 my $field = $self->field;
 foreach my $key ( keys %data ) {
   $self->{ $key } = $data{ $key } if ( $field->{ $key } );
 }
 return $self;
}

# Typical call:
# $self->check_action_security( { required => SEC_LEVEL_WRITE } );

# Note that we return SEC_LEVEL_WRITE to all requests where the object
# does not have an ID -- meaning that the object has not yet been
# saved, and this object creation security must be handled by the
# application rather than SPOPS

# Returns the security level if ok, die()s with an error message if not
sub check_action_security {
 my $self = shift;
 my $p    = shift;

 # If the class has told us they're not using security, then 
 # everyone can do everything
 return SEC_LEVEL_WRITE if ( $self->no_security );
 my $class = ref $self || $self;
 my $id    = ( ref $self ) ? $self->id : $p->{id};
 return SEC_LEVEL_WRITE unless ( $id ); 
 warn " (DBI/check_action_security): Checking action on $class ",
      "($id) and required level is ($p->{required})\n"                     if ( DEBUG );

 # Calls to SPOPS::Secure->... note that we do not need to explicitly pass in
 # group/user information, since SPOPS::Secure will retrieve it for us.
 my $level = eval { $class->check_security( { class => $class, oid => $id } ) };
 if ( $@ ) {
   $SPOPS::Error::user_msg = "Cannot check security on for $class ($id)";
   die $SPOPS::Error::user_msg;
 }

 warn " (DBI/check_action_security): Found security level of ($level)\n"   if ( DEBUG );

 # If the level is below what is necessary, set an error message and die with a 
 # general one.
 if ( $level < $p->{required} ) {
   carp " (DBI/check_action_security): Cannot access $class record with ID $id; ", 
        "access: $level while $p->{required} is required."                 if ( DEBUG );
   my $msg = "Action prohibited due to security. Insufficient access for requested action";
   SPOPS::Error->set( { user_msg => $msg, type => 'security',
                        system_msg => "Required access: $p->{required}; retrieved access: $level",
                        extra => { security => $level } } );
   die $msg;
 }
 return $level; # security checks out, we're golden
}

# Return a snippet suitable for a where clause: page_id = 5 or
# comment_id = '818172723'
sub id_clause {
 my $item = shift;
 my $id   = shift;
 my $opt  = shift || '';
 my $p    = shift || {};
 # If we weren't passed an ID and $item isn't an 
 # object, there's a problem
 return undef unless ( $id or ref( $item ) );

 $id     ||= $item->id;
 my $db    = $p->{db} || $item->global_db_handle;
 unless ( $db ) {
   my $msg = 'Cannot create ID clause';
   SPOPS::Error->set( { user_msg => $msg, 
                        system_msg => 'No db handle available when id_clause routine entered',
                        method => 'id_clause', type => 'db' } );
   die $msg;
 }
 my $id_field  = $item->id_field;
 my $type_info = eval { $item->db_discover_types( $item->base_table, { dbi_type_info => $p->{dbi_type_info},
                                                                       db => $db } ); };

 # If we cannot get the type via our own system,
 # just guess that the ID field is a number
 if ( $@ ) {
   $type_info->{ $id_field } = $SPOPS::DBI::GUESS_ID_FIELD_TYPE;
   carp " (DBI/id_clause): Likely was not passed sufficient information to ",
        "get infromation requested. Making a 'best guess'";
 }
 my $use_id_field = ( $opt eq 'noqualify' ) 
                     ? $id_field 
                     : join( '.', $item->table_name, $id_field );
 return join(' = ', $use_id_field, $db->quote( $id, $type_info->{ $id_field } ) );
}

# Allows the user to define how fields will be formatted
# in a SELECT (date formatting, substrings, etc)
sub format_select {
 my $class   = shift;
 my $fields  = shift;
 my $conf    = shift;
 my @return_fields;
 my $altered = $class->field_alter;
 foreach my $field ( @{ $fields } ) {
   push @return_fields, $conf->{ $field } || $altered->{ $field } || $field;
 }
 return \@return_fields;
}

sub get_cached_object {
 my $class = shift;
 my $p     = shift;
 return undef unless ( $p->{id} );
 return undef unless ( $class->use_cache( $p ) );

 # If we can retrieve an item from the cache, then create a new object
 # and assign the values from the cache to it.
 if ( my $item_data = $class->global_cache->get( { class => $class, id => $p->{id} } ) ) {
   warn " (DBI/get_cached_object): Retrieving from cache...\n"             if ( DEBUG );
   return $class->new( $item_data );
 }
 warn " (DBI/get_cached_object): Cached data not found.\n"                 if ( DEBUG );
 return undef;
}

sub set_cached_object {
 my $self = shift;
 my $p    = shift;
 return undef unless ( ref $self );
 return undef unless ( $self->id );
 return undef unless ( $self->use_cache( $p ) );
 return  $self->global_cache->set( { data => $self } );
}

# Return 1 if we're using the cache; 0 if not
sub use_cache {
 my $class = shift;
 my $p     = shift;
 return 0 if ( $p->{skip_cache} );
 return 0 if ( $class->no_cache );
 my $C = $class->global_config;
 return 0 unless ( ref $C eq 'HASH' );
 return 0 unless ( $C->{cache}->{data}->{SPOPS} );
 return 1;
}

sub fetch {
 my $class = shift;
 my $id    = shift;
 my $p     = shift;

 warn " (DBI/fetch): Trying to fetch an item of $class with ID $id ",
       "and params ", join( " // ", map { $_ . ' -> ' . $p->{$_} } keys %{ $p } )  if ( DEBUG_FETCH > 1 ); 
 
 # Return nothing if we are not passed an ID or if the 
 # ID passed is a temporary one.
 return undef   unless ( $id and $id !~ /^tmp/ );

 # Do *not* wrap this in an eval {}, since we want the 
 # die to propogate up to the caller if the security
 # does not check out; if the procedure does not die, 
 # the security is ok.
 my ( $level );
 unless ( $p->{skip_security} ) {
   $level = $class->check_action_security( { id => $id, required => SEC_LEVEL_READ } );
 }

 # Do any actions the class wants before fetching -- note that if any
 # of the actions returns undef (false), we bail.
 return undef unless ( $class->pre_fetch_action( { id => $id } ) );

 my $obj = undef;

 # If we were passed the data for an object, go ahead and create it;
 # if not, check to see if we can whip up a cached object
 if ( $p->{data} ) {
   $obj = $class->new( $p->{data} );
 }
 else {
   $obj = $class->get_cached_object( { %{ $p }, id => $id } );
   $p->{skip_cache}++; # Set so we don't re-cache it later
 }
 
 unless ( $obj ) {
 
   # Get the basic fields; note that we use this arrayref below
   # and it's not just a temporary variable for the next statement :)
   my $fields = $class->field_list;

   # Format the fields as the class wants; note that fields
   # passed into the method (in $p->{field_alter}) override 
   # anything in the configuration
   my $field_select = $class->format_select( $fields, $p->{field_alter} );
   warn " (DBI/fetch): SELECTing: ", join( "//", @{ $field_select } ), "\n"  if ( DEBUG_FETCH );

   # Put all the arguments into a hash (so we can reuse them simply 
   # later) and Select the record
   my %args = ( from => [ $class->table_name ],
                select => $field_select,
                where => $class->id_clause( $id, undef, $p ),
                db => $p->{db},
                return => 'single' );
   my $row = eval { $class->db_select( \%args ); };
 
   # Keep the SQLInterface error messages in place
   if ( $@ ) {
     $class->fail_fetch( \%args );   
     $SPOPS::Error::user_msg = 'Error retrieving record from database';
     die $SPOPS::Error::user_msg;
   }

   # If the row isn't found, return nothing; just as if an incorrect (or nonexistent)
   # ID were passed in 
   return undef unless ( $row );

   # Note that we pass $p along to the ->new() method, in case
   # other information was passed in needed by it -- however, 
   # we need to be careful that certain parameters used by this method
   # (e.g., the optional 'field_alter') is not the same as a parameter
   # of an object -- THAT would be fun to debug...
   $obj = $class->new( { id => $id, %{ $p } } );

   # Go through each of the fields and set information.
   warn " (DBI/fetch): Setting the following fields from row:\n"             if ( DEBUG_FETCH ); 
   for ( my $i = 0; $i < scalar @{ $row }; $i++ ) {
     warn sprintf( " --%-18s: %s\n", $fields->[ $i ], $row->[ $i ])          if ( DEBUG_FETCH );
     $obj->{ $fields->[ $i ] } = $row->[ $i ];
   }

 }

 # Create an entry for this object in the cache unless either the
 # class or this call to fetch() doesn't want us to.
 $obj->set_cached_object( $p );

 # Execute any actions the class (or any parent) wants after 
 # creating the object (see SPOPS.pm)
 return undef unless ( $obj->post_fetch_action );

 # Clear the 'changed' flag
 $obj->clear_change;

 # Set the security fetched from above into this object
 # as a temporary property (see SPOPS::Tie for more info 
 # on temporary properties); note that this is set whether
 # we retrieve a cached copy or not
 $obj->{tmp_security_level} = $level;
 return $obj;
}

sub fetch_group {
 my $class = shift;
 my $p     = shift;

 # Not sure what $p->{select} can be used for here;
 # perhaps allow the user to pass option to return just
 # the list of rows returned and do whatever desired with them...
 my @select = ( join( '.', $class->table_name, $class->id_field ) );
 push @select, @{ $p->{select} } if ( ref $p->{select} eq 'ARRAY' );

 # Some databases have difficulty sorting by a value not
 # specified in the SELECT clause (particularly with the 
 # DISTINCT modifier we use), so fix that. Note that we need
 # to strip out any modifiers (ASC, DESC, etc.) so they don't
 # accidentally get added.
 if ( $p->{order} ) {
   my $field_order = $p->{order};
   $field_order =~ s/\bASC\b//gi;
   $field_order =~ s/\bDESC\b//gi;
   push @select, split /\s*,\s*/, $field_order;
 }

 $p->{from} ||= [ $class->table_name ];
 $p->{select} = \@select;
 $p->{return} = 'list';
 $p->{select_modifier} = 'DISTINCT';
 my $rows = eval { $class->db_select( $p ); };
 if ( $@ ) {
   $SPOPS::Error::user_msg = 'Error retrieving records from database';
   die $SPOPS::Error::user_msg;
 }
 my @obj_list = ();
 foreach my $row_info  ( @{ $rows } ) {

   # We break this up into two statements to ensure
   # that any 'undef's being returned (for security reasons) 
   # don't get pushed into the list of objects
   my $obj = eval { $class->fetch( $row_info->[0], { db => $p->{db},
                                                     field_alter => $p->{field_alter}, 
                                                     skip_security => $p->{skip_security},
                                                     skip_cache => $p->{skip_cache} } ); };
   carp " (DBI/fetch_group): Cannot fetch $row_info->[0] from $class: $@"  if ( $@ );
   push @obj_list, $obj  if ( $obj );
 }
 return \@obj_list;
}

sub save {
 my $self = shift;
 my $p    = shift;
 
 my $DEBUG = DEBUG_SAVE || $p->{DEBUG};
 warn " (DBI/save): Trying to save a <<", ref $self, ">>\n"                if ( $DEBUG );
 my $id = $self->id;

 # We can force save() to be an INSERT by passing in a true value for the 
 # is_add parameter; otherwise, we rely on there being either no
 # value for the ID or a temporary value for the ID
 my $is_add = ( $p->{is_add} or ! $id or $id =~ /^tmp/ );
 
 # If this is an update and it hasn't changed,
 # we don't need to do anything.
 unless ( $is_add or $self->changed ) {
   warn " (DBI/save): This object exists and has not changed. Exiting.\n"  if ( $DEBUG );
   return $id;
 }

 # First ensure that we are allowed to create this object
 # Note that the security object needs to be able to 
 # say whether a user can create ANY of a particular
 # type of object, likely by specifying a class
 # and oid of '0'
 my $action = ( $is_add ) ? 'create' : 'update';
 my ( $level );
 unless ( $p->{skip_security} ) {
   $level = $self->check_action_security( { required => SEC_LEVEL_WRITE } );
 }
 warn " (DBI/save): Security check passed ok. Continuing.\n"               if ( $DEBUG );

 # Callback for objects to do something before they're saved
 return undef unless ( $self->pre_save_action( { is_add => $is_add } ) );

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
 return undef unless ( $self->post_save_action( { is_add => $is_add } ) );

 # Save the newly-created/updated object to the cache
 $self->set_cached_object( $p );

 # Note the action that we've just taken (opportunity for subclasses)
 unless ( $p->{skip_log} ) {
   $self->log_action( $action, $self->id );
 }

 # Being newly-created/updated, there are no changes
 $self->clear_change;

 # Return this object's ID
 return $self->id;
}

sub _save_insert {
 my $self = shift;
 my $p    = shift;

 my $DEBUG = DEBUG_SAVE || $p->{DEBUG};
 warn " (DBI/save): Treating the save as an INSERT.\n"                     if ( $DEBUG );

 # Ability to get the ID you want before the insert statement
 # is executed. If something is returned, push the value
 # plus the ID field onto the appropriate stack.
 my $pre_id = $self->pre_fetch_id;
 if ( $pre_id ) {
   $self->id( $pre_id );
   push @{ $p->{field} }, $self->id_field;
   push @{ $p->{value} }, $pre_id;
   warn " (DBI/save): Retrieved ID before insert: $pre_id\n"               if ( $DEBUG );
 }

 # Do the insert; ask DB to return the statement handle
 # if we need it for getting the just-inserted ID; note that
 # both 'field' and 'value' are in $p, so we do not need to
 # specify them in the %args
 #
 # Note also that we pass \%p in just in case we want to tell
 # db_insert not to quote anything from the original call.
 my %args = ( table => $self->table_name, return_sth => 1, %{ $p } );
 my $sth = eval { $self->db_insert( \%args ); };

 # Don't overwrite the values in $SPOPS::Error that 
 # were already set by SPOPS::SQLInterface
 if ( $@ ) {
   warn " (DBI/save): Insert failed! Args: ", Dumper( \%args ), "$SPOPS::Error::system_msg\n";
   $self->fail_save( \%args );
   $SPOPS::Error::user_msg = 'Error saving record to database';
   warn " >> Failed to insert data: $@\n", Dumper( \%args ), "\n";
   die $SPOPS::Error::user_msg;
 }
   
 # Ability to get the ID from the statement just inserted
 # via an overridden subclass method; if something is
 # returned, set the ID in the object.
 my $post_id = $self->post_fetch_id( $sth, $p );
 if ( $post_id ) {	 
   $self->id( $post_id );
   warn " (DBI/save): ID fetched after insert: $post_id\n"                 if ( $DEBUG );
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
     warn " (DBI/save): Fetching defaults for fields ", 
          join( ' // ', @{ $fill_in_fields } ), " after insert.\n"         if ( $DEBUG );
     my $row = eval { $self->db_select( { from   => [ $self->table_name ],
                                          select => $fill_in_fields,
                                          where  => $self->id_clause( undef, undef, $p ),
                                          db     => $p->{db},
                                          return => 'single' } ); };
     
     # Even though there was an error, we probably (?)
     # want to continue processing... I'm ambivalent about this,
     # however...
     if ( $@ ) {
       $SPOPS::Error::user_msg = 'Cannot re-fetch row. Continuing with normal process';
     }
     else {
       for ( my $i = 0; $i < scalar @{ $fill_in_fields }; $i++ ) {
         warn " (DBI/save): Setting $fill_in_fields->[$i] to $row->[$i]\n" if ( $DEBUG );
         $self->{ $fill_in_fields->[ $i ] } = $row->[ $i ];
       }
     }
   }
 }

 # Now create the initial security for this object unless
 # we have requested to skip it
 unless ( $p->{skip_security} ) {
   eval { $self->create_initial_security( { oid => $self->id } ); };
   warn " (DBI/save): Error creating initial security: $@"  if ( $@ );
 }
 return 1; 
}

sub _save_update {
 my $self = shift;
 my $p    = shift;
 
 my $DEBUG = DEBUG_SAVE || $p->{DEBUG};

 # If the ID of the object is changing, we still need to be able to 
 # refer to the row with its old ID; allow the user to pass in the old
 # ID in this case so we can create the ID clause with it
 my $id_clause = ( $p->{use_id} ) 
                  ? $self->id_clause( $p->{use_id}, undef, $p ) 
                  : $self->id_clause( undef, undef, $p );
 warn " (DBI/save): Processing save as UPDATE with clause ($id_clause)\n"  if ( $DEBUG );

 # Note that the 'field' and 'value' parameters are in $p and 
 # exist when the hashref is expanded into %args
 my %args = ( where => $id_clause, table => $self->table_name, %{ $p } );
 my $rv =  eval { $self->db_update( \%args ); };
 if ( $@ ) {
   warn " (DBI/save): Update failed! Args: ", Dumper( \%args ), "$SPOPS::Error::system_msg\n";
   $self->fail_save( \%args );
   $SPOPS::Error::user_msg = 'Error saving record to database';
   die $SPOPS::Error::user_msg;
 }
 return 1;
}

# Remove one or more objects
sub remove {
 my $self = shift;
 my $p    = shift;
 my $id = $self->id;
 return undef   unless ( $id and $id !~ /^tmp/ );
 my $DEBUG = DEBUG || $p->{DEBUG};

 my $level = SEC_LEVEL_WRITE;
 unless ( $p->{skip_security} ) {
   $level = $self->check_action_security( { required => SEC_LEVEL_WRITE } );
 }
 warn " (DBI/remove): Security check passed ok. Continuing.\n"             if ( $DEBUG );

 # Allow members to perform an action before getting removed
 return undef unless ( $self->pre_remove_action );

 # Do the removal, building the where clause if necessary
 my $where = ( $p->{where} ) ? $p->{where} : $self->id_clause( undef, undef, $p );
 my $rv = eval { $self->db_delete( { table => $self->table_name,
                                     where => $where,
                                     value => $p->{value},
                                     db    => $p->{db},
                                     DEBUG => $DEBUG } ) };

 # Throw the error if it occurs
 if ( $@ ) {
   $self->fail_remove;
   $SPOPS::Error::user_msg = 'Error removing record from database';
   die $SPOPS::Error::user_msg;
 }

 # Otherwise...
 # ... remove this item from the cache
 $self->global_cache->clear( { data => $self } ) if ( $self->use_cache( $p ) );

 # ... execute any actions after a successful removal
 return undef unless ( $self->post_remove_action );
 
 # ... and log the deletion
 $self->log_action( 'delete', $id );
 return 1;
}

1;

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

=item * (optional) Methods to sort member objects or perform
operations on groups of them at once.

=item * (optional) Methods to relate an object of this class to
objects of other classes -- for instance, to find all users within a
group.

=item * (optional) The initialization method (I<_class_initialize()>),
which should create a I<config()> object stored in the package
variable and initialize it with configuration information relevant to
the class.

=item * (optional) Methods to accomplish actions before/after many of
the actions implemented here: fetch/save/remove.

=item * (optional) Methods to accomplish actions before/after saving
or removing an object from the cache.

=back

Of course, these methods can also do anything else you like. :)

As you can see, all the methods are optional. Along with
L<SPOPS::Configure> and L<SPOPS::Configure::DBI>, you can create an
entirely virtual class consisting only of configuration
information. So you can actually create the implementation for a new
object in two steps:

=over 4

=item 1. Create the configuration file (or add to the existing one)

=item 2. Create the database table the class depends on.

=back

Complete!

=head1 DATA ACCESS METHODS

The following methods access configuration information about
the class but are specific to the DBI subclass.

=over 4

=item * base_table ($): Just the table name, no owners or db names
prepended.

=item * table_name ($): Fully-qualified table name

=item * field (\%): Hashref of fields/properties (field is key, value
is true)

=item * field_list (\@): Arrayref of fields/propreties

=item * no_insert (\%): Hashref of fields not to insert (field is key,
value is true)

=item * no_update (\%): Hashref of fields not to update (field is key,
value is true)

=item * skip_undef (\%): Hashref of fields to skip update/insert if
they are undefined (field is key, value is true)

=item * field_alter (\%): Hashref of data-formatting instructions
(field is key, instruction is value)

=back

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
failures trigger a die with pertinent information as described in
L<ERROR HANDLING>.

If you have security turned on for the object class, the system will
first check if the currently-configured user is allowed to fetch the
object. If the user has less that SEC_LEVEL_READ access, the fetch is
denied and a die() triggered.

Note that if the fetch is successful we store the access level of this
object within the object itself. Check the temporary property
{tmp_security_level} of any object and you will find it.

Parameters:

 field_alter - (\%) fields are keys, values are database-dependent
  formatting strings. You can accomplish different types of
  date-formatting or other manipulation tricks.

You can also pass a DEBUG value to get debugging information for that
particular statement dumped into the error log:

 my $obj = eval { $class->fetch( $id, { DEBUG => 1 } ); };

B<fetch_group( \%params )>

Returns an arrayref of objects that meet the criteria you 
specify.

Parameters: 

 where - a WHERE clause; leave this blank and you will get all entries

 order - an ORDER BY clause; leave this blank and the order is
  arbitrary

 other parameters get passed onto the fetch() statement when the
 records are being retrieved.

This is actually fairly powerful. Examples:

 # Get all the user objects and put them in a hash
 # indexed by the id
 my %uid = map { $_->id => $_ } @{ $R->user->fetch_group( { order => 'last_name' } ) }; 

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

 my $list = eval { $class->fetch_group( { order => 'item.this, item.that',
                                          from => [ 'item', 'modifier' ],
                                          where => 'modifier.property = ? AND ' .
                                                   'item.item_id = modifier.item_id',
                                          value => [ 'property value' ], } ); };

B<save()>

Object method that saves this object to the data store.  Returns the
new ID of the object if it is an add; returns the object ID if it is
an update. As with other methods, any failures trigger a die().

Example:

 my $obj = $class->new;
 $obj->{param1} = $value1;
 $obj->{param2} = $value2;
 my $new_id = eval { $obj->save };
 if ( $@ ) {
   print "Error inserting object: $@->{error}\n";
 }
 else {
   print "New object created with ID: $new_id\n";
 }

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

B<remove()>

Note that you can only remove a saved object (duh). Also tries to
remove the object from the cache. The object will not actually be
destroyed until it goes out of scope, so do not count on its DESTROY
method being called exactly when this happens.

Returns 1 on success, die() with hashref on failure. Example:

 eval { $obj->remove };
 if ( $@ ) {
   print "Object not removed. Error: $@->{error}";
 }
 else {
   print "Object removed properly.";
 }

B<log_action( $action, $id )>

Implemented by subclass.

This method is passed the action performed upon an object ('create',
'update', 'remove') and the ID. SPOPS::DBI comes with an empty method,
but you can subclass it and do what you wish

=head1 ERROR HANDLING

Like all SPOPS classes, any errors encountered will be tossed up to
the application using a die() and a simple string as a message. We
also set more detailed information in a number of L<SPOPS::Error>
package variables; see that module for more details.

=head1 TO DO

=head1 BUGS

=head1 COPYRIGHT

Copyright (c) 2000 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

 Chris Winters (cwinters@intes.net)

=cut
