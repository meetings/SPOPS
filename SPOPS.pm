package SPOPS;

# $Id: SPOPS.pm,v 1.65 2002/02/23 00:59:09 lachoy Exp $

use strict;
use Data::Dumper    qw( Dumper );
require Exporter;
use SPOPS::Exception;
use SPOPS::Tie      qw( IDX_CHANGE IDX_SAVE IDX_CHECK_FIELDS IDX_LAZY_LOADED );
use SPOPS::Secure   qw( SEC_LEVEL_WRITE );
use SPOPS::Utility  qw();
use Storable        qw( store retrieve nstore );

$SPOPS::AUTOLOAD  = '';
@SPOPS::ISA       = qw( Exporter Storable );
@SPOPS::EXPORT_OK = qw( _w _wm DEBUG );
$SPOPS::VERSION   = '0.57';
$SPOPS::Revision  = substr(q$Revision: 1.65 $, 10);

# Note that switching on DEBUG will generate LOTS of messages, since
# many SPOPS classes import this constant

use constant DEBUG => 0;


########################################
# CLASS CONFIGURATION
########################################

# These are default configuration behaviors -- all SPOPS classes have
# the option of using them or of halting behavior before they're
# called

sub behavior_factory {
    my ( $class ) = @_;
    require SPOPS::ClassFactory::DefaultBehavior;
    DEBUG() && _w( 1, "Installing SPOPS default behaviors for ($class)" );
    return { manipulate_configuration =>
                    \&SPOPS::ClassFactory::DefaultBehavior::conf_modify_config,
             read_code                =>
                    \&SPOPS::ClassFactory::DefaultBehavior::conf_read_code,
             id_method                =>
                    \&SPOPS::ClassFactory::DefaultBehavior::conf_id_method,
             has_a                    =>
                    \&SPOPS::ClassFactory::DefaultBehavior::conf_relate_hasa,
             fetch_by                 =>
                    \&SPOPS::ClassFactory::DefaultBehavior::conf_relate_fetchby,
             add_rule                 =>
                    \&SPOPS::ClassFactory::DefaultBehavior::conf_add_rules, };
}


########################################
# CLASS INITIALIZATION
########################################

# Subclasses should almost certainly define some behavior here by
# overriding this method

sub class_initialize {}


########################################
# OBJECT CREATION/DESTRUCTION
########################################

# Constructor

sub new {
    my ( $pkg, $p ) = @_;
    my $class = ref $pkg || $pkg;
    my $params = {};
    my $tie_class = 'SPOPS::Tie';

    my $CONFIG = $class->CONFIG;

    # Setup field checking if specified

    if ( $CONFIG->{strict_field} ) {
        my $fields = $class->field;
        if ( keys %{ $fields } ) {
            $params->{field} = [ keys %{ $fields } ];
            require SPOPS::Tie::StrictField;
            $tie_class = 'SPOPS::Tie::StrictField'
        }
    }

    # Setup lazy loading if specified

    if ( ref $CONFIG->{column_group} eq 'HASH' and
         keys %{ $CONFIG->{column_group} } ) {
        $params->{is_lazy_load}  = 1;
        $params->{lazy_load_sub} = $class->get_lazy_load_sub;
    }

    # Setup field mapping if specified

    if ( ref $CONFIG->{field_map} eq 'HASH' and
         scalar keys %{ $CONFIG->{field_map} } ) {
        $params->{is_field_map} = 1;
        $params->{field_map} = \%{ $CONFIG->{field_map} };
    }

    # Setup multivalue fields if specified

    my $multivalue_ref = ref $CONFIG->{multivalue};
    if ( $multivalue_ref eq 'HASH' or $multivalue_ref eq 'ARRAY' ) {
        my $num = ( $multivalue_ref eq 'HASH' )
                    ? scalar keys %{ $CONFIG->{multivalue} }
                    : scalar @{ $CONFIG->{multivalue} };
        if ( $num > 0 ) {
            $params->{is_multivalue} = 1;
            $params->{multivalue} = ( $multivalue_ref eq 'HASH' )
                                      ? \%{ $CONFIG->{multivalue} }
                                      : \@{ $CONFIG->{multivalue} };
        }
    }

    DEBUG() && _w( 1, "Creating new object of class ($class) with tie class ",
                      "($tie_class); lazy loading ($params->{is_lazy_load});",
                      "field mapping ($params->{is_field_map})" );

    my ( %data );
    my $internal = tie %data, $tie_class, $class, $params;
    DEBUG() && _w( 4, "Internal tie structure of new object: ", Dumper( $internal ) );
    my $self = bless( \%data, $class );

    # Set defaults if set, unless NOT specified

    my $defaults = $p->{default_values} || $CONFIG->{default_values};
    if ( ref $defaults eq 'HASH' and ! $p->{skip_default_values} ) {
        foreach my $field ( keys %{ $defaults } ) {
            if ( ref $defaults->{ $field } eq 'HASH' ) {
                my $default_class  = $defaults->{ $field }{class};
                my $default_method = $defaults->{ $field }{method};
                unless ( $default_class and $default_method ) {
                    _w( 0, "Cannot set default for ($field) without a class ",
                           "AND method being defined." );
                    next;
                }
                $self->{ $field } = eval { $default_class->$default_method( $field ) };
                if ( $@ ) {
                    _w( 0, "Cannot set default for ($field) in ($class) using",
                           "($default_class) ($default_method): $@" );
                }
            }
            elsif ( $defaults->{ $field } eq 'NOW' ) {
                $self->{ $field } = SPOPS::Utility->now;
            }
            else {
                $self->{ $field } = $defaults->{ $field };
            }
        }
    }

    $self->initialize( $p );
    return $self;
}


sub DESTROY {
    my ( $self ) = @_;
    DEBUG() && _w( 2, "Destroying SPOPS object (". ref( $self ) . ") ID: " .
                      "(" . $self->id . ") at time: ", scalar localtime );
}


# Create a new object from an old one, allowing any passed-in
# values to override the ones from the old object

sub clone {
    my ( $self, $p ) = @_;
    my $class = $p->{_class} || ref $self;
    DEBUG() && _w( 1, "Cloning new object of class ($class) from old ",
                      "object of class (", ref $self, ")" );
    my %initial_data = ();

    my $id_field = $class->id_field;
    if ( $id_field ) {
        $initial_data{ $id_field } = $p->{ $id_field } || $p->{id};
    }

    while ( my ( $k, $v ) = each %{ $self } ) {
        next unless ( $k );
        next if ( $id_field and $k eq $id_field );
        $initial_data{ $k } = exists $p->{ $k } ? $p->{ $k } : $v;
    }

    return $class->new({ %initial_data, skip_default_values => 1 });
}


# Simple initialization: subclasses can override for
# field validation or whatever.

sub initialize {
    my ( $self, $p ) = @_;
    $p ||= {};

    # Creating a new object, all fields are set to 'loaded' so we don't
    # try to lazy-load a field when the object hasn't even been saved

    $self->set_all_loaded();

    # We allow the user to substitute id => value instead for the
    # specific fieldname.

    $self->id( $p->{id} )  if ( $p->{id} );
    #$p->{ $self->id_field } ||= $p->{id};

    # Go through the data passed in and set data for fields used by
    # this class

    my $class_fields = $self->field || {};
    while ( my ( $field, $value ) = each %{ $p } ) {
        next unless ( $class_fields->{ $field } );
        $self->{ $field } = $value;
    }
}


########################################
# CONFIGURATION
########################################

# If a class doesn't define a config method then something is seriously wrong

sub CONFIG {
    require Carp;
    Carp::croak "SPOPS class not created properly, since CONFIG being called ",
                "from SPOPS.pm rather than your object class.";
}


# Some default configuration methods that all SPOPS classes use

sub field               { return $_[0]->CONFIG->{field} || {}              }
sub field_list          { return $_[0]->CONFIG->{field_list} || []         }
sub id_field            { return $_[0]->CONFIG->{id_field}                 }
sub timestamp_field     { return $_[0]->CONFIG->{timestamp_field}          }
sub creation_security   { return $_[0]->CONFIG->{creation_security} || {}  }
sub no_security         { return $_[0]->CONFIG->{no_security}              }


########################################
# RULESET METHODS
########################################

# So all SPOPS classes have a ruleset_add in their lineage

sub ruleset_add     { return __PACKAGE__ }
sub ruleset_factory {}

# These are actions to do before/after a fetch, save and remove; note
# that overridden methods must return a 1 on success or the
# fetch/save/remove will fail; this allows any of a number of rules to
# short-circuit an operation; see RULESETS in POD
#
# clarification: $_[0] in the following can be *either* a class or an
# object; $_[1] is the (optional) hashref passed as the only argument

sub pre_fetch_action    { return $_[0]->ruleset_process_action( 'pre_fetch_action',   $_[1] ) }
sub post_fetch_action   { return $_[0]->ruleset_process_action( 'post_fetch_action',  $_[1] ) }
sub pre_save_action     { return $_[0]->ruleset_process_action( 'pre_save_action',    $_[1] ) }
sub post_save_action    { return $_[0]->ruleset_process_action( 'post_save_action',   $_[1] ) }
sub pre_remove_action   { return $_[0]->ruleset_process_action( 'pre_remove_action',  $_[1] ) }
sub post_remove_action  { return $_[0]->ruleset_process_action( 'post_remove_action', $_[1] ) }


# Go through all of the subroutines found in a particular class
# relating to a particular action

sub ruleset_process_action {
    my ( $item, $action, $p ) = @_;
    $action = lc $action;
    DEBUG() && _w( 1, "Trying to process $action for a",
                      ( ref $item ) ? ref $item : $item, "type of object" );

    # Grab the ruleset table for this class and immediately
    # return if the list of rules to apply for this action is empty

    my $rs_table = $item->RULESET;
    return 1 unless ( ref $rs_table->{ $action } eq 'ARRAY' );
    return 1 unless ( scalar @{ $rs_table->{ $action } } );
    DEBUG() && _w( 1, "Ruleset exists in class." );

    # Cycle through the rules -- the only return value can be true or false,
    # and false short-circuits the entire operation

    my $count_rules = 0;
    foreach my $rule_sub ( @{ $rs_table->{ $action } } ) {
        return undef unless ( $rule_sub->( $item, $p ) );
        $count_rules++;
    }
    DEBUG() && _w( 1, "$action processed ($count_rules rules successful) without error" );
    return 1;
}


########################################
# SERIALIZATION
########################################

# Routines for subclases to override

sub save        {}
sub fetch       {}
sub remove      {}
sub log_action  { return 1 }

# Define methods for implementors to override to do something in case
# a fetch / save / remove fails

sub fail_fetch  {}
sub fail_save   {}
sub fail_remove {}


########################################
# SERIALIZATION SUPPORT
########################################

# initialize limit tracking vars -- the limit passed in can be:
# limit => 'x,y'  --> 'offset = x, max = y'
# limit => 'x'    --> 'max = x'

sub fetch_determine_limit {
    my ( $class, $limit ) = @_;
    return ( 0, 0 ) unless ( $limit );
    my ( $offset, $max );
    if ( $limit =~ /,/ ) {
        ( $offset, $max ) = split /\s*,\s*/, $limit;
        $max += $offset;
    }
    else {
        $max = $limit;
    }
    DEBUG() && _w( 1, "Limit set: Start $offset to $max" );
    return ( $offset, $max );
}


########################################
# LAZY LOADING
########################################

sub get_lazy_load_sub { return \&perform_lazy_load }
sub perform_lazy_load { return undef }

sub is_loaded         { return tied( %{ $_[0] } )->{ IDX_LAZY_LOADED() }{ $_[1] } }

sub set_loaded        { return tied( %{ $_[0] } )->{ IDX_LAZY_LOADED() }{ $_[1] }++ }

sub set_all_loaded {
    my ( $self ) = @_;
    DEBUG() && _w( 1, "Setting all fields to loaded for object class", ref $self );
    my %loaded = map { $_ => 1 } @{ $self->field_list };
    tied( %{ $self } )->{ IDX_LAZY_LOADED() } = \%loaded;
}

sub clear_loaded { tied( %{ $_[0] } )->{ IDX_LAZY_LOADED() }{ $_[1] } = undef }

sub clear_all_loaded {
    DEBUG() && _w( 1, "Clearing all fields to unloaded for object class", ref $_[0] );
    tied( %{ $_[0] } )->{ IDX_LAZY_LOADED() } = {};
}


########################################
# FIELD CHECKING
########################################

# Is this object doing field checking?

sub is_checking_fields { return tied( %{ $_[0] } )->{ IDX_CHECK_FIELDS() }; }


########################################
# MODIFICATION STATE
########################################

# Track whether this object has changed (keep 'changed()' for backward
# compatibility)

sub changed      { is_changed( @_ ) }
sub is_changed   { return $_[0]->{ IDX_CHANGE() } }
sub has_change   { $_[0]->{ IDX_CHANGE() } = 1 }
sub clear_change { $_[0]->{ IDX_CHANGE() } = 0 }


########################################
# SERIALIZATION STATE
########################################

# Track whether this object has been saved (keep 'saved()' for
# backward compatibility)

sub saved        { is_saved( @_ ) }
sub is_saved     { return $_[0]->{ IDX_SAVE() } }
sub has_save     { $_[0]->{ IDX_SAVE() } = 1 }
sub clear_save   { $_[0]->{ IDX_SAVE() } = 0 }


########################################
# TIMESTAMP
########################################

# WARNING: THESE MAY GO AWAY

# returns the timestamp value for this object, if
# one has been defined

sub timestamp {
    my ( $self ) = @_;
    return undef  if ( ! ( ref $self ) );
    if ( my $ts_field = $self->timestamp_field ) {
        return $self->{ $ts_field };
    }
    return undef;
}


# Pass in a value for a timestamp to check and compare it to what is
# currently in the object; if there is no timestamp field specified,
# just return true so everything will continue as normal

sub timestamp_compare {
    my ( $self, $check ) = @_;
    if ( my $ts_field = $self->timestamp_field ) {
        return ( $check eq $self->{ $ts_field } );
    }
    return 1;
}


########################################
# OBJECT INFORMATION
########################################

# Return the name of this object (what type it is), title of the
# object and url (in a hashref) to be used to make a link, or whatnot.

sub object_description {
    my ( $self ) = @_;
    my $title_info = $self->CONFIG->{name};
    my $title = '';
    if ( ref $title_info eq 'CODE' ) {
        $title = $title_info->( $self );
    }
    elsif ( ! ref $title_info ) {
        $title = $self->{ $title_info };
    }
    $title ||= 'Cannot find name';
    my $link_info = $self->CONFIG->{display};
    my $oid       = $self->id;
    my $id_field  = $self->id_field;
    my $url       = "$link_info->{url}?" . $id_field . '=' . $oid;
    my $url_edit  = "$link_info->{url}?edit=1;" . $id_field . '=' . $oid;
    return { class     => ref $self,
             object_id => $oid,
             oid       => $oid,
             id_field  => $id_field,
             name      => $self->CONFIG->{object_name},
             title     => $title,
             security  => $self->{tmp_security_level},
             url       => $url,
             url_edit  => $url_edit };
}


# This is very primitive, but objects that want something more
# fancy/complicated can implement it for themselves

sub as_string {
    my ( $self ) = @_;
    my $msg = '';
    my $fields = $self->CONFIG->{as_string_order} || $self->field_list;
    my $labels = $self->CONFIG->{as_string_label} || { map { $_ => $_ } @{ $fields } };
    foreach my $field ( @{ $fields } ) {
        $msg .= sprintf( "%-20s: %s\n", $labels->{ $field }, $self->{ $field } );
    }
    return $msg;
}


# This is even more primitive, but again, we're just providing the
# basics :-)

sub as_html {
    my ( $self ) = @_;
    return "<pre>" . $self->as_string . "\n</pre>\n";
}


########################################
# SECURITY
########################################

# These are the default methods that classes not using security
# inherit. Default action is WRITE, so everything is allowed

sub check_security          { return SEC_LEVEL_WRITE }
sub check_action_security   { return SEC_LEVEL_WRITE }
sub create_initial_security { return 1               }


########################################
# CACHING
########################################

# NOTE: CACHING IS NOT FUNCTIONAL AND THESE MAY RADICALLY CHANGE

# All objects are by default cached; set the key 'no_cache'
# to a true value to *not* cache this object

sub no_cache            { return $_[0]->CONFIG->{no_cache} || 0 }

# Your class should determine how to get to the cache -- the normal
# way is to have all your objects inherit from a common base class
# which deals with caching, datasource handling, etc.

sub global_cache        { return undef }

# Actions to do before/after retrieving/saving/removing
# an item from the cache

sub pre_cache_fetch     { return 1 }
sub post_cache_fetch    { return 1 }
sub pre_cache_save      { return 1 }
sub post_cache_save     { return 1 }
sub pre_cache_remove    { return 1 }
sub post_cache_remove   { return 1 }


sub get_cached_object {
    my ( $class, $p ) = @_;
    return undef unless ( $p->{id} );
    return undef unless ( $class->use_cache( $p ) );

    # If we can retrieve an item from the cache, then create a new object
    # and assign the values from the cache to it.

    if ( my $item_data = $class->global_cache->get({ class => $class, id => $p->{id} }) ) {
        DEBUG() && _w( 1, "Retrieving from cache..." );
        return $class->new( $item_data );
    }
    DEBUG() && _w( 1, "Cached data not found." );
    return undef;
}


sub set_cached_object {
    my ( $self, $p ) = @_;
    return undef unless ( ref $self );
    return undef unless ( $self->id );
    return undef unless ( $self->use_cache( $p ) );
    return $self->global_cache->set({ data => $self });
}


# Return 1 if we're using the cache; undef if not -- right now we
# always return undef since caching isn't enabled

sub use_cache {
    return undef;
    my ( $class, $p ) = @_;
    return undef if ( $p->{skip_cache} );
    return undef if ( $class->no_cache );
    return undef unless ( $class->global_cache );
    return 1;
}


########################################
# ACCESSORS/MUTATORS
########################################

# We should probably deprecate these...

sub get { return $_[0]->{ $_[1] } }
sub set { return $_[0]->{ $_[1] } = $_[2] }


# return a simple hashref of this object's data -- not tied, not as an
# object

sub as_data_only {
    my ( $self ) = @_;
    return { map { $_ => $self->{ $_ } } keys %{ $self } };
}

# Backward compatible...

sub data { return as_data_only( @_ ) }

sub AUTOLOAD {
    my ( $item ) = @_;
    my $request = $SPOPS::AUTOLOAD;
    $request =~ s/.*://;

  # First, give a nice warning and return undef if $item is just a
  # class rather than an object

    my $class = ref $item;
    unless ( $class ) {
        _w( 0, "Cannot fill request ($request) from class $item" );
        return undef;
    }

    no strict 'refs';
    DEBUG() && _w( 1, "Trying to fulfill $request from $class (ISA: ",
                      join( " // ", @{ $class . '::ISA' } ), ")" );
    if ( ref $item and $item->is_checking_fields ) {
        my $fields = $item->field || {};
        if ( exists $fields->{ $request } ) {
            DEBUG() && _w( 2, "$class to fill  param <<$request>>; returning data." );
            *{ $class . '::' . $request } = sub { return $_[0]->{ $request } };
            return $item->{ $request };
        }
        elsif ( my $value = $item->{ $request } ) {
            DEBUG() && _w( 2, " $request must be a temp or something, returning value." );
            return $value;
        }
        elsif ( $request =~ /^tmp_/ ) {
            DEBUG() && _w( 2, "$request is a temp var, but no value saved. Returning undef." );
            return undef;
        }
        elsif ( $request =~ /^_internal/ ) {
            DEBUG() && _w( 2, "$request is an internal request, but no value",
                              "saved. Returning undef." );
            return undef;
        }
        _w( 0, "AUTOLOAD Error: Cannot access the method $request via <<$class>>",
               "with the parameters ", join( ' ', @_ ) );
        return undef;
    }
    DEBUG() && _w( 2, "$class is not checking fields, so create sub and return",
                      "data for <<$request>>" );
    *{ $class . '::' . $request } = sub { return $_[0]->{ $request } };
    return $item->{ $request };
}


########################################
# DEBUGGING
########################################

sub _w {
    my $lev   = shift || 0;
    return unless ( DEBUG >= $lev );
    my ( $pkg, $file, $line ) = caller;
    my @ci = caller(1);
    warn "$ci[3] ($line) >> ", join( ' ', @_ ), "\n";
}


sub _wm {
    my $lev   = shift || 0;
    my $check = shift || 0;
    return unless ( $check >= $lev );
    my ( $pkg, $file, $line ) = caller;
    my @ci = caller(1);
    warn "$ci[3] ($line) >> ", join( ' ', @_ ), "\n";
}

1;

__END__

=pod

=head1 NAME

SPOPS -- Simple Perl Object Persistence with Security

=head1 SYNOPSIS

 # Define an object completely in a configuration file

 my $spops = {
   myobject => {
    class   => 'MySPOPS::Object',
    isa     => qw( SPOPS::DBI ),
    ...
   }
 };

 # Process the configuration and initialize the class

 SPOPS::Initialize->process({ config => $spops });

 # create the object

 my $object = MySPOPS::Object->new;

 # Set some parameters

 $object->{ $param1 } = $value1;
 $object->{ $param2 } = $value2;

 # Store the object in an inherited persistence mechanism

 eval { $object->save };
 if ( $@ ) {
   print "Error trying to save object: $@\n",
         "Stack trace: ", $@->trace->as_string, "\n";
 }

=head1 OVERVIEW

SPOPS -- or Simple Perl Object Persistence with Security -- allows you
to easily define how an object is composed and save, retrieve or
remove it any time thereafter. It is intended for SQL databases (using
the DBI), but you should be able to adapt it to use any storage
mechanism for accomplishing these tasks.  (An early version of this
used GDBM, although it was not pretty.)

The goals of this package are fairly simple:

=over 4

=item *

Make it easy to define the parameters of an object

=item *

Make it easy to do common operations (fetch, save, remove)

=item *

Get rid of as much SQL (or other domain-specific language) as
possible, but...

=item *

... do not impose a huge cumbersome framework on the developer

=item *

Make applications easily portable from one database to another

=item *

Allow people to model objects to existing data without modifying the
data

=item *

Include flexibility to allow extensions

=item *

Let people simply issue SQL statements and work with normal datasets
if they want

=back

So this is a class from which you can derive several useful
methods. You can also abstract yourself from a datasource and easily
create new objects.

The subclass is responsible for serializing the individual objects, or
making them persistent via on-disk storage, usually in some sort of
database. See "Object Oriented Perl" by Conway, Chapter 14 for much
more information.

The individual objects or the classes should not care how the objects
are being stored, they should just know that when they call C<fetch()>
with a unique ID that the object magically appears. Similarly, all the
object should know is that it calls C<save()> on itself and can
reappear at any later date with the proper invocation.

=head1 DESCRIPTION

This module is meant to be overridden by a class that will implement
persistence for the SPOPS objects. This persistence can come by way of
flat text files, LDAP directories, GDBM entries, DBI database tables
-- whatever. The API should remain the same.

Please see L<SPOPS::Manual::Intro|SPOPS::Manual::Intro> and
L<SPOPS::Manual::Object|SPOPS::Manual::Object> for more information
and examples about how the objects work.

=head1 API

The following includes methods within SPOPS and those that need to be
defined by subclasses.

In the discussion below, the following holds:

=over 4

=item *

When we say B<base class>, think B<SPOPS>

=item *

When we say B<subclass>, think of B<SPOPS::DBI> for example

=back

Also see the L<ERROR HANDLING> section below on how we use exceptions
to indicate an error and where to get more detailed infromation.

B<new( [ \%initialize_data ] )>

Implemented by base class.

This method creates a new SPOPS object. If you pass it key/value
pairs the object will initialize itself with the data (see
C<initialize()> for notes on this).

Note that you can use the key 'id' to substitute for the actual
parameter name specifying an object ID. For instance:

 my $uid = $user->id;
 if ( eval { $user->remove } ) {
   my $new_user = MyUser->new( { id => $uid, fname = 'BillyBob' ... } );
   ...
 }

In this case, we do not need to know the name of the ID field used by
the MyUser class.

You can also pass in default values to use for the object in the
'default_values' key.

We use a number of parameters from your object configuration. These
are:

=over 4

=item *

B<strict_field> (bool) (optional)

If set to true, you will use the L<SPOPS::Tie::StrictField|SPOPS::Tie::StrictField> tie
implementation, which ensures you only get/set properties that exist
in the field listing.

=item *

B<column_group> (\%) (optional)

Hashref of column aliases to arrayrefs of fieldnames. If defined
objects of this class will use L<LAZY LOADING>, and the different
aliases you define can typically be used in a C<fetch()>,
C<fetch_group()> or C<fetch_iterator()> statement. (Whether they can
be used depends on the SPOPS implementation.)

=item *

B<field_map> (\%) (optional)

Hashref of field alias to field name. This allows you to get/set
properties using a different name than how the properties are
stored. For instance, you might need to retrofit SPOPS to an existing
table that contains news stories. Retrofitting is not a problem, but
another wrinkle of your problem is that the news stories need to fit a
certain interface and the property names of the interface do not match
the fieldnames in the existing table.

All you need to do is create a field map, defining the interface
property names as the keys and the database field names as the values.

=item *

B<default_values> (\%) (optional)

Hashref of field names and default values for the fields when the
object is initialized with C<new()>.

Normally the values of the hashref are the defaults to which you want
to set the fields. However, there are two special cases of values:

B<'NOW'> This string will insert the current timestamp in the format
C<yyyy-mm-dd hh:mm:ss>.

B<\%> A hashref with the keys 'class' and 'method' will get executed
as a class method and be passed the name of the field for which we
want a default. The method should return the default value for this
field.

One problem with setting default values in your object configuration
B<and> in your database is that the two may become unsynchronized,
resulting in many pulled hairs in debugging.

To get around the synchronization issue, you can set this dynamically
using various methods with
L<SPOPS::ClassFactory|SPOPS::ClassFactory>. (A sample,
C<My::DBI::FindDefaults>, is shipped with SPOPS.)

=back

Returns on success: a tied hashref object with any passed data
already assigned.

Returns on failure: undef.

Examples:

 # Simplest form...
 my $data = MyClass->new();

 # ...with initialization
 my $data = MyClass->new({ balance => 10532,
                           account => '8917-918234' });

B<clone( \%params )>

Returns a new object from the data of the first. You can override the
original data with that in the \%params passed in. You can also clone
an object into a new class by passing the new class name as the
'_class' parameter -- of course, the interface must either be the same
or there must be a 'field_map' to account for the differences.

Examples:

 # Create a new user bozo

 my $bozo = $user_class->new;
 $bozo->{first_name} = 'Bozo';
 $bozo->{last_name}  = 'the Clown';
 $bozo->{login_name} = 'bozosenior';
 eval { $bozo->save };
 if ( $@ ) { ... report error .... }

 # Clone bozo; first_name is 'Bozo' and last_name is 'the Clown',
 # as in the $bozo object, but login_name is 'bozojunior'

 my $bozo_jr = $bozo->clone({ login_name => 'bozojunior' });
 eval { $bozo_jr->save };
 if ( $@ ) { ... report error ... }

 # Copy all users from a DBI datastore into an LDAP datastore by
 # cloning from one and saving the clone to the other

 my $dbi_users = DBIUser->fetch_group();
 foreach my $dbi_user ( @{ $dbi_users } ) {
     my $ldap_user = $dbi_user->clone({ _class => 'LDAPUser' });
     $ldap_user->save;
 }

B<initialize()>

Implemented by base class, although it is often overridden.

Cycle through the parameters and set any data necessary. This allows
you to construct the object with existing data. Note that the tied
hash implementation optionally ensures (with the 'strict_field'
configuration key set to true) that you cannot set infomration as a
parameter unless it is in the field list for your class. For instance,
passing the information:

 firt_name => 'Chris'

should likely not set the data, since 'firt_name' is the misspelled
version of the defined field 'first_name'.

Note that we also set the 'loaded' property of all fields to true, so
if you override this method you need to simply call:

 $self->set_all_loaded();

somewhere in the overridden method.

=head2 Accessors/Mutators

You should use the hash interface to get and set values in your object
-- it is easier. However, SPOPS will also create accessors for you on
demand -- just call a method with the same name as one of your
properties and it will be created. Generic accessors and mutators are
available.

B<get( $fieldname )>

Returns the currently stored information within the object for C<$fieldname>.

 my $value = $obj->get( 'username' );
 print "Username is $value";

It might be easier to use the hashref interface to the same data,
since you can inline it in a string:

 print "Username is $obj->{username}";

You may also use a shortcut of the parameter name as a method call for
the first instance:

 my $value = $obj->username();
 print "Username is $value";

B<set( $fieldname, $value )>

Sets the value of C<$fieldname> to C<$value>. If value is empty,
C<$fieldname> is set to undef.

 $obj->set( 'username', 'ding-dong' );

Again, you can also use the hashref interface to do the same thing:

 $obj->{username} = 'ding-dong';

Note that unlike C<get>, You B<cannot> use the shortcut of using the
parameter name as a method. So a call like:

 my $username = $obj->username( 'new_username' );

Will silently ignore any parameters that are passed and simply return
the information as C<get()> would.

B<id()>

Returns the ID for this object. Checks in its config variable for the
ID field and looks at the data there.  If nothing is currently stored,
you will get nothing back.

Note that we also create a subroutine in the namespace of the calling
class so that future calls take place more quickly.

=head2 Serialization

B<fetch( $object_id, [ \%params ] )>

Implemented by subclass.

This method should be called from either a class or another object
with a named parameter of 'id'.

Returns on success: an SPOPS object.

Returns on failure: undef; if the action failed (incorrect fieldname
in the object specification, database not online, database user cannot
select, etc.) a L<SPOPS::Exception|SPOPS::Exception> object (or one of
its subclasses) will be thrown to raise an error.

The \%params parameter can contain a number of items -- all are optional.

Parameters:

=over 4

=item *

B<(datasource)> (obj) (optional)

For most SPOPS implementations, you can pass the data source (a DBI
database handle, a GDBM tied hashref, etc.) into the routine. For DBI
this variable is C<db>, for LDAP it is C<ldap>, but for other
implementations it can be something else.

=item *

B<data> (\%) (optional)

You can use fetch() not just to retrieve data, but also to do the
other checks it normally performs (security, caching, rulesets,
etc.). If you already know the data to use, just pass it in using this
hashref. The other checks will be done but not the actual data
retrieval. (See the C<fetch_group> routine in L<SPOPS::DBI|SPOPS::DBI>
for an example.)

=item *

B<skip_security> (bool) (optional)

A true value skips security checks, false or default value keeps them.

=item *

B<skip_cache> (bool) (optional)

A true value skips any use of the cache, always hitting the data
source.

=back

In addition, specific implementations may allow you to pass in other
parameters. (For example, you can pass in 'field_alter' to the
L<SPOPS::DBI|SPOPS::DBI> implementation so you can format the returned data.)

Example:

 my $id = 90192;
 my $data = eval { MyClass->fetch( $id ) };

 # Read in a data file and retrieve all objects matching IDs

 my @object_list = ();
 while ( <DATA> ) {
   chomp;
   next if ( /\D/ );
   my $obj = eval { ObjectClass->fetch( $_ ) };
   if ( $@ ) { ... report error ... }
   else      { push @object_list, $obj  if ( $obj ) }
 }

B<fetch_determine_limit( $limit )>

This method of the SPOPS parent class supports the C<fetch()>
implementation of subclasses. It is used to help figure out what
records to fetch. Pass in a C<$limit> string and get back a two-item
list with the offset and max.

The C<$limit> string can be in one of two formats:

  'x,y'  --> offset = x, max = y
  'x'    --> offset = 0, max = x

Example:

 $p->{limit} = "20,30";
 my ( $offset, $max ) = $self->fetch_determine_limit( $p->{limit} );

 # Offset is 20, max is 30, so you should get back records 20 - 30.

If no C<$limit> is passed in, the values of both items in the
two-value list are 0.

B<save( [ \%params ] )>

Implemented by subclass.

This method should save the object state in whatever medium the module
works with. Note that the method may need to distinguish whether the
object has been previously saved or not -- whether to do an add versus
an update. See the section L<TRACKING CHANGES> for how to do this. The
application should not care whether the object is new or pre-owned.

Returns on success: the object itself.

Returns on failure: undef, and a L<SPOPS::Exception|SPOPS::Exception>
object (or one of its subclasses) will be thrown to raise an error.

Example:

 eval { $obj->save };
 if ( $@ ) {
   warn "Save of ", ref $obj, " did not work properly -- $@";
 }

Since the method returns the object, you can also do chained method
calls:

 eval { $obj->save()->separate_object_method() };

Parameters:

=over 4

=item *

B<(datasource)> (obj) (optional)

For most SPOPS implementations, you can pass the data source (a DBI
database handle, a GDBM tied hashref, etc.) into the routine.

=item *

B<is_add> (bool) (optional)

A true value forces this to be treated as a new record.

=item *

B<skip_security> (bool) (optional)

A true value skips the security check.

=item *

B<skip_cache> (bool) (optional)

A true value skips any caching.

=item *

B<skip_log> (bool) (optional)

A true value skips the call to 'log_action'

=back

B<remove()>

Implemented by subclass.

Permanently removes the object, or if called from a class removes the
object having an id matching the named parameter of 'id'.

Returns: status code based on success (undef == failure).

Parameters:

=over 4

=item *

B<(datasource)> (obj) (optional)

For most SPOPS implementations, you can pass the data source (a DBI
database handle, a GDBM tied hashref, etc.) into the routine.

=item *

B<skip_security> (bool) (optional)

A true value skips the security check.

=item *

B<skip_cache> (bool) (optional)

A true value skips any caching.

=item *

B<skip_log> (bool) (optional)

A true value skips the call to 'log_action'

=back

Examples:

 # First fetch then remove

 my $obj = MyClass->fetch( $id );
 my $rv = $obj->remove();

Note that once you successfully call C<remove()> on an object, the
object will still exist as if you had just called C<new()> and set the
properties of the object. For instance:

 my $obj = MyClass->new();
 $obj->{first_name} = 'Mario';
 $obj->{last_name}  = 'Lemieux';
 if ( $obj->save ) {
     my $saved_id = $obj->{player_id};
     $obj->remove;
     print "$obj->{first_name} $obj->{last_name}\n";
 }

Would print:

 Mario Lemieux

But trying to fetch an object with C<$saved_id> would result in an
undefined object, since it is no longer in the datastore.

=head2 Object Information

B<object_description()>

Returns a hashref with metadata about a particular object. The keys of
the hashref are:

=over 4

=item *

B<class> ($)

Class of this object

=item *

B<object_id> ($)

ID of this object. (Also under 'oid' for compatibility.)

=item *

B<id_field> ($)

Field used for the ID.

=item *

B<name> ($)

Name of this general class of object (e.g., 'News')

=item *

B<title> ($)

Title of this particular object (e.g., 'Man bites dog, film at 11')

=item *

B<url> ($)

URL that will display this object. Note that the URL might not
necessarily work due to security reasons.

B<url_edit> ($)

URL that will display this object in editable form. Note that the URL
might not necessarily work due to security reasons.

=back

The defaults put together by SPOPS by reading your configuration file
might not be sufficiently dynamic for your object. In that case, just
override the method and substitute your own. For instance, the
following adds some sort of sales adjective to the beginning of every
object title:

  package My::Object;

  sub object_description {
      my ( $self ) = @_;
      my $info = $self->SUPER::object_description();
      $info->{title} = join( ' ', sales_adjective_of_the_day(),
                                  $info->{title} );
      return $info;
  }

And be sure to include this class in your 'code_class' configuration
key. (See L<SPOPS::ClassFactory|SPOPS::ClassFactory> and
L<SPOPS::Manual::CodeGeneration|SPOPS::Manual::CodeGeneration> for
more info.)

B<as_string>

Represents the SPOPS object as a string fit for human consumption. The
SPOPS method is extremely crude -- if you want things to look nicer,
override it.

B<as_html>

Represents the SPOPS object as a string fit for HTML (browser)
consumption. The SPOPS method is double extremely crude, since it just
wraps the results of C<as_string()> (which itself is crude) in '<pre>'
tags.

=head2 Lazy Loading

B<is_loaded( $fieldname )>

Returns true if C<$fieldname> has been loaded from the datastore,
false if not.

B<set_loaded( $fieldname )>

Flags C<$fieldname> as being loaded.

B<set_all_loaded()>

Flags all fieldnames (as returned by C<field_list()>) as being loaded.

=head2 Field Checking

B<is_checking_fields()>

Returns true if this class is doing field checking (setting
'strict_field' equal to a true value in the configuration), false if
not.

=head2 Modification State

B<is_changed()>

Returns true if this object has been changed since being fetched or
created, false if not.

B<has_change()>

Set the flag telling this object it has been changed.

B<clear_change()>

Clear the change flag in an object, telling it that it is unmodified.

=head2 Serialization State

B<is_saved()>

Return true if this object has ever been saved, false if not.

B<has_save()>

Set the saved flag in the object to true.

B<clear_save()>

Clear out the saved flag in the object.

=head2 Configuration

Most of this information can be accessed through the C<CONFIG>
hashref, but we also need to create some hooks for subclasses to
override if they wish. For instance, language-specific objects may
need to be able to modify information based on the language
abbreviation.

We have simple methods here just returning the basic CONFIG
information.

B<no_cache()> (bool)

Returns a boolean based on whether this object can be cached or
not. This does not mean that it B<will> be cached, just whether the
class allows its objects to be cached.

B<field()> (\%)

Returns a hashref (which you can sort by the values if you wish) of
fieldnames used by this class.

B<field_list()> (\@)

Returns an arrayref of fieldnames used by this class.

Subclasses can define their own where appropriate.

=head2 "Global" Configuration

These objects are tied together by just a few things:

B<global_cache>

A caching object. If you have

 {cache}{SPOPS}{use}

in your configuration set to '0', then you do not need to worry about
this. Otherwise, the caching module should implement:

The method B<get()>, which returns the property values for a
particular object.

 $cache->get({ class => 'SPOPS-class', id => 'id' })

The method B<set()>, which saves the property values for an object
into the cache.

 $cache->set({ data => $spops_object });

This is a fairly simple interface which leaves implementation pretty
much wide open.

Note that subclasses may also have items that must be accessible to
all children -- see L<SPOPS::DBI|SPOPS::DBI> and the
C<global_datasource_handle> method.

=head2 Timestamp Methods

These might go away.

B<timestamp()>

Returns the value of the timestamp_field for this object, undef if the
timestamp_field is not defined.

B<timestamp_compare( $ts_check )>

Returns true if $ts_check matches what is in the object, false
otherwise.

B<timestamp_field()> ($)

Returns a fieldname used for the timestamp. Having a blank or
undefined value for this is ok. But if you do define it, your UPDATEs
will be checked to ensure that the timestamp values match up. If not,
the system will throw an error. (Note, this is not yet implemented.)

=head1 NOTES

There is an issue using these modules with
L<Apache::StatINC|Apache::StatINC> along with the startup methodology
that calls the C<class_initialize> method of each class when a httpd
child is first initialized. If you modify a module without stopping
the webserver, the configuration variable in the class will not be
initialized and you will inevitably get errors.

We might be able to get around this by having most of the
configuration information as static class lexicals. But anything that
depends on any information from the CONFIG variable in request (which
is generally passed into the C<class_initialize> call for each SPOPS
implementation) will get hosed.

=head1 TO DO

B<Method object_description() should be more robust>

In particular, the 'url' and 'url_edit' keys of object_description()
should be more robust.

B<Objects composed of many records>

An idea: Make this data item framework much like the one
Brian Jepson discusses in Web Techniques:

 http://www.webtechniques.com/archives/2000/03/jepson/

At least in terms of making each object unique (having an OID).
Each object could then be simply a collection of table name
plus ID name in the object table:

 CREATE TABLE objects (
   oid        int not null,
   table_name varchar(30) not null,
   id         int not null,
   primary key( oid, table_name, id )
 )

Then when you did:

 my $oid  = 56712;
 my $user = User->fetch( $oid );

It would first get the object composition information:

 oid    table        id
 ===    =====        ==
 56712  user         1625
 56712  user_prefs   8172
 56712  user_history 9102

And create the User object with information from all
three tables.

Something to think about, anyway.

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

Find out more about SPOPS -- current versions, updates, rants, ideas
-- at:

 http://www.openinteract.org/SPOPS/

CVS access and mailing lists (SPOPS is currently supported by the
openinteract-dev list) are at:

 http://sourceforge.net/projects/openinteract/

Also see the 'Changes' file in the source distribution for comments
about how the module has evolved.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

The following people have offered patches, advice, development funds,
etc. to SPOPS:

=over 4

=item *

Ray Zimmerman <rz10@cornell.edu> -- had offered tons of great design
ideas and general help, pushing SPOPS into new domains. Too much to
list here.

=item *

Christian Lemburg <lemburg@aixonix.de> -- contributed excellent
documentation, too many good ideas to implement as well as design help
with L<SPOPS::Secure::Hierarchy|SPOPS::Secure::Hierarchy>, the
rationale for moving methods from the main SPOPS subclass to
L<SPOPS::Utility|SPOPS::Utility>

=item *

Rusty Foster <rusty@kuro5hin.org> -- was influential in the early (!)
days of this library and offered up an implementation for 'limit'
functionality in L<SPOPS::DBI|SPOPS::DBI>

=item *

Rick Myers <rik@sumthin.nu> -- got rid of lots of warnings when
running under C<-w> and helped out with permission issues with
SPOPS::GDBM.

=item *

Harry Danilevsky <hdanilevsky@DeerfieldCapital.com> -- helped out with
Sybase-specific issues, including inspiring
L<SPOPS::Key::DBI::Identity|SPOPS::Key::DBI::Identity>.

=item *

Leon Brocard <acme@astray.com> -- prodded better docs of
L<SPOPS::Configure|SPOPS::Configure>, specifically the linking
semantics.

=item *

David Boone <dave@bis.bc.ca> -- prodded the creation of
L<SPOPS::Initialize|SPOPS::Initialize>.

=item *

MSN Marketing Service Nordwest, GmbH -- funded development of LDAP
functionality, including L<SPOPS::LDAP|SPOPS::LDAP>,
L<SPOPS::LDAP::MultiDatasource|SPOPS::LDAP::MultiDatasource>, and
L<SPOPS::Iterator::LDAP|SPOPS::Iterator::LDAP>.

=back

=cut
<
