package SPOPS;

# $Header: /usr/local/cvsdocs/SPOPS/SPOPS.pm,v 1.40 2000/10/15 18:47:43 cwinters Exp $

use strict;
use vars qw( $IDX_CHANGE );

require Exporter;

use Carp          qw( carp );
use SPOPS::Tie    qw( IDX_DATA  IDX_CHANGE  IDX_CHECK_FIELDS );
use SPOPS::Secure qw( SEC_LEVEL_WRITE );
use Date::Format  qw( time2str );

$SPOPS::AUTOLOAD = '';
@SPOPS::ISA      = qw( Exporter );
$SPOPS::VERSION  = sprintf("%d.%02d", q$Revision: 1.40 $ =~ /(\d+)\.(\d+)/);

@SPOPS::EXPORT_OK   = qw( now today generate_random_code crypt_it );
%SPOPS::EXPORT_TAGS = (
 utils    => [ qw/ now today generate_random_code crypt_it / ], 
);

use constant DEBUG => 0;

# Allow subclasses read-only access to the 
# index where the data are stored within an object.
sub _idx_data { return IDX_DATA; }

sub CONFIG              { return {} }

# Language of the object (not used now)
sub lang                { return $_[0]->CONFIG->{lang}               }

# Field hash and list (not just for databases...); plus the# name of the ID field and the timestamp field
sub field               { return $_[0]->CONFIG->{field} || {}        }
sub field_list          { return $_[0]->CONFIG->{field_list} || []   }
sub id_field            { return $_[0]->CONFIG->{id_field}           }
sub timestamp_field     { return $_[0]->CONFIG->{timestamp_field}    } 
sub creation_security   { return $_[0]->CONFIG->{creation_security} || {}  } 
sub no_security         { return $_[0]->CONFIG->{no_security}        }

# All objects are by default cached; set the key 'no_cache'
# to a true value to *not* cache this object
sub no_cache            { return $_[0]->CONFIG->{no_cache} || 0; }

# Your class should determine how to get to these very important
# items. This is typically done through the use of a 'stash class',
# where important per-application information is kept.
sub global_cache        { return undef; }
sub global_config       { return undef; }

# Actions to do before/after a fetch, save and remove; note
# that overridden methods must return a 1 on success or the
# fetch/save/remove will fail; this allows any of a number of rules
# to short-circuit an operation; see RULESETS below
#
# clarification: $_[0] in the following can be *either* a class
# or an object; $_[1] is the (optional) hashref passed as the only argument
sub pre_fetch_action    { return $_[0]->ruleset_process_action( 'pre_fetch_action',   $_[1] ) }
sub post_fetch_action   { return $_[0]->ruleset_process_action( 'post_fetch_action',  $_[1] ) }
sub pre_save_action     { return $_[0]->ruleset_process_action( 'pre_save_action',    $_[1] ) }
sub post_save_action    { return $_[0]->ruleset_process_action( 'post_save_action',   $_[1] ) }
sub pre_remove_action   { return $_[0]->ruleset_process_action( 'pre_remove_action',  $_[1] ) }
sub post_remove_action  { return $_[0]->ruleset_process_action( 'post_remove_action', $_[1] ) }

# Go through all of the subroutines found in a particular
# class relating to a particular action; 
sub ruleset_process_action {
 my $item   = shift;
 my $action = lc shift;
 my $p      = shift;

 my $DBG = DEBUG || $p->{DEBUG};
 warn "(SPOPS/ruleset_process_action): Trying to process $action for ",
      ( ref $item ) ? ref $item : $item, " type of object\n"               if ( $DBG );
 # Grab the ruleset table for this class and immediately
 # return if the list of rules to apply for this action is empty
 my $rs_table = $item->RULESET;
 return 1 unless ( ref $rs_table->{ $action } eq 'ARRAY' );
 return 1 unless ( scalar @{ $rs_table->{ $action } } );
 warn " (SPOPS/ruleset_process_action): Ruleset exists in class.\n"        if ( $DBG );

 # Cycle through the rules -- the only return value can be true or false,
 # and false short-circuits the entire operation
 foreach my $rule_sub ( @{ $rs_table->{ $action } } ) {
   return undef unless ( $rule_sub->( $item, $p ) );
 }
 warn " (SPOPS/ruleset_process_action): $action processed without error\n" if ( $DBG );
 return 1;
}

sub ruleset_add { return 1; }

# Actions to do before/after retrieving/saving/removing
# an item from the cache
sub pre_cache_fetch     { return 1; }
sub post_cache_fetch    { return 1; }
sub pre_cache_save      { return 1; }
sub post_cache_save     { return 1; }
sub pre_cache_remove    { return 1; }
sub post_cache_remove   { return 1; }

# Define methods for implementors to override to do
# something in case a fetch / save / remove fails
sub fail_fetch          { return undef; }
sub fail_save           { return undef; }
sub fail_remove         { return undef; }

# Actions to check security on an object -- the default access is
# read/write (which also includes delete)
sub check_security          { return SEC_LEVEL_WRITE; }
sub check_action_security   { return SEC_LEVEL_WRITE; } 
sub create_initial_security { return 1;}

# Return either a data hashref or a list with the
# data hashref and object, depending on context
sub new {
 my $pkg   = shift;
 my $class = ref $pkg || $pkg;
 my $p     = shift;
 my ( %data );
 my $params = {};
 my $fields = $class->field;
 if ( keys %{ $fields } ) {
   $params->{field} = [ keys %{ $fields } ];
 }
 my $int = tie %data, 'SPOPS::Tie', $class, $params;
 my $self = bless( \%data, $class );
 $self->initialize( $p );
 return $self;
}

# Create a new object from an old one, allowing any passed-in
# values to override the ones from the old object
sub clone {
 my $self = shift;
 my $p    = shift;
 my $new = $self->new; 
 my $id_field = $self->id_field();
 if ( $id_field ) {
   my $new_id = $p->{ $id_field } || $p->{id};
   $new->{ $id_field } = $new_id   if ( $new_id );
 }
 while ( my ( $k, $v ) = each %{ $self } ) {
   next if ( $id_field and $k eq $id_field );
   $new->{ $k } = $p->{ $k } || $v;
 }
 return $new;
}

# Simple initialization: subclasses can override for
# field validation or whatever.
sub initialize {
 my $self = shift;
 my $p    = shift;
 foreach my $field ( keys %{ $p } ) {
   $self->{ $field } = $p->{ $field };
 }
}

# Create routines for subclases to override
sub save   { return undef; }
sub fetch  { return undef; }
sub remove { return undef; }

# We should probably deprecate these...
sub get { return $_[0]->{ $_[1] }; }
sub set { return $_[0]->{ $_[1] } = $_[2]; }

# return a simple hashref of this object's
# data -- not tied, not as an object
sub data {
 my $self = shift;
 my $data = {};
 while ( my ( $k, $v ) = each %{ $self } ) {
   $data->{ $k } = $v;
 }
 return $data;
}

sub is_checking_fields { return tied( %{ $_[0] } )->{ IDX_CHECK_FIELDS() }; }

sub id {
 my $self   = shift;
 my $new_id = shift;
 return undef if ( ! ref $self );
 my $id_field = $self->id_field;
 warn " (SPOPS/id): ID field is ($id_field) ID is ($new_id)\n"             if ( DEBUG );

{
  # Setup a new subroutine to take care of this 
  # in the future (BLOCK is just so we only
  # set no strict for a limited area)
  no strict 'refs';
  my $class = ref( $self );
  warn " (SPOPS/id): Setting up subroutine in: $class for ->id() call.\n"  if ( DEBUG );
  *{ $class. '::id' } = sub { return $_[0]->{ $id_field } if ( ! $_[1] ); return $_[0]->{ $id_field } = $_[1]; };
}
 
 # Take care of the most common case first, then set the new ID
 return $self->{ $id_field }      if ( ! $new_id );
 return $self->{ $id_field } = $new_id;
}

# This is very primitive, but objects that want
# something more fancy/complicated can implement
# it for themselves
sub as_string {
 my $self = shift;
 my $msg = '';
 my $fields = $self->CONFIG->{as_string_order} || $self->field_list;
 my $labels = $self->CONFIG->{as_string_label} || { map { $_ => $_ } @{ $fields } };
 foreach my $field ( @{ $fields } ) {
   $msg .= sprintf( "%-20s: %s\n", $labels->{ $field }, $self->{ $field } );
 }
 return $msg;
}

# Track whether this object has changed
sub changed      { return $_[0]->{ IDX_CHANGE() }; }
sub has_change   { $_[0]->{ IDX_CHANGE() } = 1;    }
sub clear_change { $_[0]->{ IDX_CHANGE() } = 0;    }

# returns the timestamp value for this object, if
# one has been defined
sub timestamp {
 my $self = shift;
 return undef  if ( ! ( ref $self ) );
 if ( my $ts_field = $self->timestamp_field ) {
   return $self->{ $ts_field };
 }
 return undef; 
}

# pass in a value for a timestamp to check and 
# compare it to what is currently in the object
sub timestamp_compare {
 my $self  = shift;
 my $check = shift;
 if ( my $ts_field = $self->timestamp_field ) {
   return ( $check eq $self->{ $ts_field } );
 }

 # if there is no timestamp field specified, return true so
 # everything will continue as normal
 return 1;
}

# Return a title and url (in a hashref) to be used to 
# make a link, or whatnot.
sub object_description {
 my $self = shift;
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
 my $url = "$link_info->{url}?" . $self->id_field . '=' . $self->id;
 return { name => $self->CONFIG->{object_name},
          title => $title, url  => $url };
}

sub generate_random_code {
 my $self   = shift;
 my $length = shift;
 my $opt    = shift;
 return undef if ( ! $length );
 return join '', map { chr( int( rand(26) ) + 65 ) } ( 1 .. $length )  if ( $opt ne 'mixed' );
 return join '', map { ( $_ % 2 == 0 )
                         ? chr( int( rand(26) ) + 65 )
                         : chr( int( rand(26) ) + 97 ) } ( 1 .. $length );
}

sub crypt_it {
 my $class = shift;
 my $text  = shift;
 return undef if ( ! $text );
 my $salt = $class->generate_random_code( 2 );
 return crypt( $text, $salt );
}

sub now {
 my $class = shift;
 my $p     = shift;
 $p->{format} ||= '%Y-%m-%d %T';
 $p->{time}   ||= time;
 return time2str( $p->{format}, $p->{time} );
}

sub today { return $_[0]->now( { format => '%Y-%m-%e' } ); }

# Pass in \@existing and \@new and get back a hashref:
#   add    => \@: items in \@new but not in \@existing,
#   keep   => \@: items in \@new and in \@existing,
#   remove => \@: items not in \@new but in \@existing  
sub list_process {
 my $class = shift;
 my $exist = shift;
 my $new   = shift;

 # Create a hash of the existing items
 my %existing = map { $_ => 1 } @{ $exist };
 my ( @k, @a );

 # Go through the new items...
 foreach my $new_id ( @{ $new } ) {

   #... if it's existing, track it as a keeper
   # and remove it from the existing pile
   if ( $existing{ $new_id } ) {
	 delete $existing{ $new_id };
	 push @k, $new_id;
   }

   # otherwise, track it as an add
   else {
	 push @a, $new_id;
   }
 }

 # now, the only items left in %existing are the ones
 # that were not specified in the new list; therefore,
 # these should be removed
 return { add => \@a, keep => \@k, remove => [ keys %existing ] };
}

sub AUTOLOAD {
 my $self = shift;
 my $request = $SPOPS::AUTOLOAD;
 $request =~ s/.*://;
 my $class = ref( $self ) || $self;
 no strict 'refs';
 carp "  (SPOPS): Trying to fulfill $request from $class (ISA: ",
      join( " // ", @{ $class . '::ISA' } ), ")"                           if ( DEBUG );
 if ( $self->is_checking_fields ) {
   my $fields = $self->field || {};
   if ( exists $fields->{ $request } ) {
     carp " (SPOPS): $class to fill  param <<$request>>; returning data."    if ( DEBUG );
     *{ $class . '::' . $request } = sub { return $_[0]->{ $request } };
     return $self->{ $request };
   }
   elsif ( my $value = $self->{ $request } ) {
     warn " $request must be a temp or something, returning value.\n"        if ( DEBUG );
     return $value;
   }
   elsif ( $request =~ /^tmp_/ ) {
     warn " $request is a temp var, but no value saved. Returning undef.\n"  if ( DEBUG );
     return undef;
   }
   elsif ( $request =~ /^_internal/ ) {
     warn " $request is an internal request, but no value saved. Returning undef.\n"  if ( DEBUG );
     return undef;
   }
   my $error_msg = "Cannot access the method $request via <<$class>>" .
                   "with the parameters " . join ' ', @_;
   carp " AUTOLOAD Error: $error_msg\n";
   return undef;
 }
 carp " (SPOPS): $class is not checking fields, so create sub and return data for <<$request>>"  if ( DEBUG );
 *{ $class . '::' . $request } = sub { return $_[0]->{ $request } };
 return $self->{ $request }; 
}

sub DESTROY {
 my ( $self ) = @_;
 if ( DEBUG ) {
   carp "Destroying SPOPS object <", ref( $self ), ">\n",
         "ID: <", $self->id, ">\n",
         "Time: ", scalar( localtime );
   warn "\n";
 }
}

1;

=pod

=head1 NAME

SPOPS -- Simple Perl Object Persistence with Security

=head1 SYNOPSIS

 # Define an object completely in a configuration file
 my $spops = { 
   myobject => {
    class => 'MySPOPS::Object',
    isa => qw( SPOPS::DBI ),
    ...
   }, ...
 };

 # Process the configuration:
 SPOPS::Configure->process_config( { config => $spops } );
 
 # Initialize the class
 MySPOPS::Object->class_initialize;

 # create the object
 my $object = MySPOPS::Object->new;

 # Set some parameters
 $object->{ $param1 } = $value1;
 $object->{ $param2 } = $value2;

 # Store the object in an inherited persistence mechanism
 eval { $object->save };
 if ( $@ ) {
   my $err_info = SPOPS::Error->get;
   die "Error trying to save object:\n",
       "$err_info->{user_msg}\n",
       "$err_info->{system_msg}\n";
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

Get rid of as much SQL as possible, but...

=item * 

... do not impose a huge cumbersome framework on the developer

=item * 

Make applications easily portable from one database to another

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
are being stored, they should just know that when they call I<fetch()>
with a unique ID that the object magically appears. Similarly, all the
object should know is that it calls I<save()> on itself and can
reappear at any later date with the proper invocation.

B<Tie Interface>

This version of SPOPS supports using a L<tie> interface to get and set
the individual data values. You can also use the more traditional OO
I<get> and I<set> operators, but most people will likely find the
hashref interface easier to deal with. (It also means you can
interpolate data into strings: bonus!) Examples are given below.

The tie interface allows the most common operations -- fetch data and
put it into a data structure for later use -- to be done very
easily. It also hides much of the complexity behind the object for you
so that most of the time you are dealing with a simple hashref.

=head2 What do the objects look like?

Here is an example getting values from CGI.pm and saving an object:

 my $q = new CGI;
 my $obj = MyUserClass->new();
 foreach my $field ( qw( f_name l_name birthdate ) ) {
   $obj->{ $field } = $q->param( $field );
 }
 my $object_id = eval { $obj->save };
 if ( $@ ) {
  ... report error information ...
 }
 else {
   warn " Object saved with ID: $obj->{object_id}\n";
 }

You can now retrieve it later using the object_id:

 my $obj = MyUserClass->fetch( $object_id );
 print "First Name: $obj->{f_name}\n",
       "Last Name:  $obj->{l_name}\n",
       "Birthday:   $obj->{birthdate}\n";


You can also associate objects to other objects:

 my $primary_group = $user->group;
 print "Group Name: $primary_group->{name}\n";

And you can fetch batches of objects at once:

 my $user_list = MyUserClass->fetch_group( { where => 'l_name LIKE ?',
                                             value => [ 'w%' ],
                                             order => 'birthdate' } );
 foreach my $user ( @{ $user_list } ) {
   print " $user->{f_name} $user->{l_name} -- $user->{birthdate}\n";
 }

=head1 EXAMPLES

 # Retrieve all themes and print a description
 my $themes = eval { $theme_class->fetch_group( { order => 'title' } ) };
 if ( $@ ) { ... report error ... }
 else {
   foreach my $thm ( @{ $themes } ) {
     print "Theme: $thm->{title}\n",
           "Description: $thm->{description}\n";
   }
 }

 # Create a new user, set some values and save
 my $user = $user_class->new;
 $user->{email} = 'mymail@user.com';
 $user->{first_name} = 'My';
 $user->{last_name}  = 'User';
 my $user_id = eval { $user->save };
 if ( $@ ) {
   print "There was an error: ", $R->error->report(), "\n";
 }

 # Retrieve that same user from the database
 my $user_id = $cgi->param( 'user_id' );
 my $user = eval { $user_class->fetch( $user_id ) };
 if ( $@ ) { ... report error ... }
 else {
   print "The user's first name is: $user->{first_name}\n";
 }

 my $data = MyClass->new( { field1 => 'value1', field2 => 'value2' } );

 # Retrieve values using the hashref
 print "The value for field2 is: $data->{field2}\n";

 # Set values using the hashref
 $data->{field3} = 'value3';

 # Save the current data state
 eval { $data->save };
 if ( $@ ) { ... report error ... }

 # Remove the object permanently
 eval { $data->remove };
 if ( $@ ) { ... report error ... }

 # Call arbitrary object methods to get other objects
 my $other_obj = eval { $data->call_to_get_other_object() };
 if ( $@ ) { ... report error ... }

 # Clone the object with an overridden value and save
 my $new_data = $data->clone( { field1 => 'new value' } );
 eval { $new_data->save };
 if ( $@ ) { ... report error ... }

 # $new_data is now its own hashref of data --
 # explore the fields/values in it
 while ( my ( $k, $v ) = each %{ $new_data } ) {
   print "$k == $v\n";
 }

 # Retrieve saved data
 my $saved_data = eval { MyClass->fetch( $id ) };
 if ( $@ ) { ... report error ... }
 else {
   while ( my ( $k, $v ) = each %{ $saved_data } ) {
     print "Value for $k with ID $id is $v\n";
   }
 }

 # Retrieve lots of objects, display a value and call a 
 # method on each
 my $data_list = eval { MyClass->fetch_group( where => "last_name like 'winter%'" ) };
 if ( $@ ) { ... report error ... }
 else {
   foreach my $obj ( @{ $data_list } ) {
     print "Username: $obj->{username}\n";
     $obj->increment_login();
   }
 }

=head1 DESCRIPTION

This module is meant to be overridden by a class that will implement
persistence for the SPOPS objects. This persistence can come by way of
flat text files, LDAP directories, GDBM entries, DBI database tables
-- whatever. The API should remain the same.

=head2 Class Hierarchy

SPOPS (Simple Perl Object Persistence with Security) provides a
framework to make your application objects persistent (meaning, you
can store them somewhere, e.g., in a relational database), and to
control access to them (the usual user/group access rights stuff). You
will usually just configure SPOPS by means of configuration files, and
SPOPS will create the necessary classes and objects for your
application on the fly. You can of course have your own code implement
your objects - extending the default SPOPS object behavior with your
methods. However, if SPOPS shall know about your classes and objects,
you will have to tell it -- by configuring it.

The typical class hierarchy for an SPOPS object looks like this:

     --------------------------
    |SPOPS                     |
     --------------------------
                ^
                |
     --------------------------
    |SPOPS::MyStorageTechnology|
     --------------------------
                ^
                |
     --------------------------
    |SPOPS::MyApplicationClass |
     --------------------------

=over 4

=item SPOPS

Abstract base class, provides persistency and security framework
(fetch, save, remove)

Example: You are reading it now!

=item SPOPS::MyStorageTechnology

Concrete base class, provides technical implementation of framework
for a particular storage technology (e.g., Filesystem, RDBMS, LDAP,
... )

Example: SPOPS::DBI, SPOPS::GDBM, ...

=item SPOPS::MyApplicationClass

User class, provides semantic implementation of framework
(configuration of parent class, e.g., database connection strings,
field mappings, ... )

Example: MyApplication::User, MyApplication::Document, ...

=back

=head2 SPOPS Object States

Basically, each SPOPS object is always in one of two states: 

=over 4

=item *

Runtime State

=item *

Persistency State

=back

In Runtime State, the object representation is based on a hash of
attributes. The object gets notified about any changes to it through
the tie(3) mechanism.

In Persistency State, the object exists in some persistent form, that
is, it is stored in a database, or written out to a file.

You can control what happens to the object when it gets written to its
persistent form, or when it is deleted, or fetched from its storage
form, by implementing a simple API: fetch(), save(), remove().



     -------------         save, remove         -----------------
    |Runtime State|     ------------------->   |Persistency State|
     -------------      <------------------     -----------------
                              fetch


Around the fetch(), save(), and remove() calls, you can execute helper
functions (pre_fetch(), post_fetch(), pre_save(), post_save(),
pre_remove(), post_remove()), in case you need to prepare anything or
clean up something, according to needs of your storage technology.
These are pushed on a queue based on a search of @ISA, and executed
front to end of the queue. If any of the calls in a given queue
returns a false value, the whole action (save, remove, fetch) is
short-circuited (that is, a failing method bombs out of the
action). More information on this is in L<Data Manipulation Callbacks:
Rulesets> below.

=cut

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

Onward!

Also see the L<ERROR HANDLING> section below on how we use die() to
indicate an error and where to get more detailed infromation.

B<new( [ \%initialize_data ] )>

Implemented by base class.

This method creates a new SPOPS object. If you pass it key/value
pairs the object will initialize itself with the data (see
I<initialize()> for notes on this).

Note that you can use the key 'id' to substitute for the actual
parameter name specifying an object ID. For instance:

 my $uid = $user->id;
 if ( eval { $user->remove } ) {
   my $new_user = MyUser->new( { id => $uid, fname = 'BillyBob' ... } );
   ...
 }

In this case, we do not need to know the name of the ID field used by
the MyUser class.

Returns on success: a tied hashref object with any passed data
already assigned. 

Returns on failure: undef.

Examples:

 # Simplest form...
 my $data = MyClass->new();

 # ...with initialization
 my $data = MyClass->new( { balance => 10532, 
                            account => '8917-918234' } );

B<clone( \%params )>

Returns a new object from the data of the first. You can override the
original data with that in the \%params passed in.

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
 my $bozo_jr = $bozo->clone( { login_name => 'bozojunior' } );
 eval { $bozo_jr->save };
 if ( $@ ) { ... report error ... }

B<initialize()>

Implemented by base class, although it is often overridden.

Cycle through the parameters and set any data necessary. This allows
you to construct the object with existing data. Note that the tied
hash implementation ensures that you cannot set infomration as a
parameter unless it is in the field list for your class. For instance,
passing the information:

 firt_name => 'Chris'

should likely not set the data, since 'firt_name' is the misspelled
version of the defined field 'first_name'.

B<fetch( $oid, [ \%params ] )>

Implemented by subclass.

This method should be called from either a class or another object
with a named parameter of 'id'.

Returns on success: a SPOPS object.

Returns on failure: undef; if the action failed (incorrect fieldname
in the object specification, database not online, database user cannot
select, etc.) a die() will be used to raise an error.

The \%params parameter can contain a number of items -- all are optional.

Parameters:

 <datasource>
   For most SPOPS implementations, you can pass the data source (a DBI
   database handle, a GDBM tied hashref, etc.) into the routine.

 data
   You can use fetch() not just to retrieve data, but also to do the
   other checks it normally performs (security, caching, rulesets,
   etc.). If you already know the data to use, just pass it in using
   this hashref. The other checks will be done but not the actual data
   retrieval. (See the C<fetch_group> routine in L<SPOPS::DBI> for an
   example.)

 skip_security
   A true value skips security checks.

 skip_cache
   A true value skips any use of the cache.

In addition, specific implementations may allow you to pass in other
parameters. (For example, you can pass in 'field_alter' to the
L<SPOPS::DBI> implementation so you can format the returned data.)

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

B<save( [ \%params ] )>

Implemented by subclass.

This method should save the object state in whatever medium the module
works with. Note that the method may need to distinguish whether the
object has been previously saved or not -- whether to do an add versus
an update. See the section L<TRACKING CHANGES> for how to do this. The
application should not care whether the object is new or pre-owned.

Returns on success: the ID of the object if applicable, otherwise a
true value;

Returns on failure: undef, and a die() to indicate that the action failed.

Example:

 my $rv = eval { $obj->save };
 if ( $@ ) {
   warn "Save of ", ref $obj, " did not work properly!";
 }

Parameters:

 <datasource>
   For most SPOPS implementations, you can pass the data source (a DBI
   database handle, a GDBM tied hashref, etc.) into the routine.

 is_add
   A true value forces this to be treated as a new record.

 skip_security
   A true value skips the security check.

 skip_cache
   A true value skips any caching.

 skip_log
   A true value skips the call to 'log_action'

B<remove()>

Implemented by subclass.

Permanently removes the object, or if called from a class removes the
object having an id matching the named parameter of 'id'.

Returns: status code based on success (undef == failure).

Parameters:

 <datasource>
   For most SPOPS implementations, you can pass the data source (a DBI
   database handle, a GDBM tied hashref, etc.) into the routine.

Examples:

 # First fetch then remove
 my $obj = MyClass->fetch( $id );
 my $rv = $obj->remove();

=head1 TRACKING CHANGES

The object tracks whether any changes have been made since it was
instantiated and keeps an internal toggle switch. You can query the
toggle or set it manually.

 $obj->changed();

Returns 1 if there has been change, undef if not.

 $obj->has_change();

Sets the toggle to true.

 $obj->clear_change();

Sets the toggle to false.

Example:

 if ( $obj->changed() ) {
   my $rv = $obj->save();
 }

Note that this can (and should) be implemented within the subclass, so
you as a user can simply call:

 $obj->save();

And not worry about whether it has been changed or not. If there has
been any modification, the system will save it, otherwise it will not.

B<Automatically Created Accessors>

In addition to getting the data for an object through the hashref
method, you can also get to the data with accessors named after the
fields.

For example, given the fields:

 $user->{f_name}
 $user->{l_name}
 $user->{birthday}

You can call to retrieve the data:

 $user->f_name();
 $user->l_name();
 $user->birthday();

Note that this is only to read the data, not to change it. The system
does this using AUTOLOAD, and after the first call it automatically
creates a subroutine in the namespace of your class which handles
future calls so there is no need for AUTOLOAD on the second or future
calls.

=head1 DATA ACCESS METHODS

Most of this information can be accessed through the I<CONFIG>
hashref, but we also need to create some hooks for subclasses to
override if they wish. For instance, language-specific objects may
need to be able to modify information based on the language
abbreviation.

We have simple methods here just returning the basic CONFIG
information. The following are defined:

=over 4

=item * 

lang ( $ )

Returns a language code (e.g., 'de' for German; 'en' for
English). This only works if defined by your class.

=item * 

no_cache ( bool )

Returns a boolean based on whether this object can be cached or
not. This does not mean that it B<will> be cached, just whether the
class allows its objects to be cached.

=item * 

field( \% )

Returns a hashref (which you can sort by the values if you wish) of
fieldnames used by this class.

=item * 

field_list( \@ )

Returns an arrayref of fieldnames used by this class.

=item * 

timestamp_field ( $ )

Returns a fieldname used for the timestamp. Having a blank or
undefined value for this is ok. But if you do define it, your UPDATEs
will be checked to ensure that the timestamp values match up. If not,
the system will throw an error. (Note, this is not yet implemented.)

=back

Subclasses can define their own where appropriate.

=head1 "GLOBALS"

These objects are tied together by just a few things:

=over 4

=item 1

global_config

A few items sprinkled throughout the SPOPS hierarchy need information
provided in a configuration file. See L<SPOPS::Configure> for more
information about what should be in it, what form it should take and
some of the nifty tricks you can do with it.

Returns: a hashref of configuration information.

=item 2

global_cache

A caching object. If you have 

 {cache}->{SPOPS}->{use}

in your configuration set to '0', then you do not need to worry about
this. Otherwise, the caching module should implement:

The method B<get()>, which returns the property values for a
particular object.

 $cache->get( { class => 'SPOPS-class', id => 'id' } )

The method B<set()>, which saves the property values for an object
into the cache.

 $cache->set( { data => $spops_object } );

This is a fairly simple interface which leaves implementation pretty
much wide open.

=back

Note that subclasses (such as L<SPOPS::DBI>) may also have items that
must be accessible to all children.

=head1 DATA MANIPULATION CALLBACKS: RULESETS

When a SPOPS object calls fetch/save/remove, the base class takes care
of most of the details for retrieving and constructing the
object. However, sometimes you want to do something more complex or
different. Each data manipulation method allows you to define two
methods to accomplish these things. One is called before the action is
taken (usually at the very beginning of the action) and the other
after the action has been successfully completed.

What kind of actions might you want to accomplish? Cascading deletes
(when you delete one object, delete a number of other dependent
objects as well); dependent fetches (when you fetch one object, fetch
all its component objects as well); implement a consistent data layer
(such as full-text searching) by sending all inserts and updates to a
separate module or daemon. Whatever.

Each of these actions is a rule, and together they are rulesets. There
are some fairly simple guidelines to rules:

=over 4

=item 1

Each rule is independent of every other rule. Why? Rules for a
particular action may be executed in an arbitrary order. You cannot
guarantee that the rule from one class will execute before the rule
from a separate class.

=item 2

A rule should not change the data of the object on which it
operates. Each rule should be operating on the same data. And since
guideline 1 states the rules can be executed in any order, changing
data for use in a separate rule would create a dependency between
them.

=item 3

If a rule fails, then the action is aborted. This is central to how
the ruleset operates, since it allows inherited behaviors to have a
say on whether a particular object is fetched, saved or removed.

=back

For example, you may want to implement a 'layer' over certain classes
of data. Perhaps you want to collect how many times users from various
groups visit a set of objects on your website. You can create a fairly
simple class that puts a rule into the ruleset of its children that
creates a log entry every time a particular object is
I<fetch()>ed. The class could also contain methods for dealing with
this information.

This rule is entirely separate and independent from other rules, and
does not interfere with the normal operation except to add information
to a separate area of the database as the actions are happening. In
this manner, you can think of them as a trigger as implemented in a
relational database. However, triggers can (and often do) modify the
data of the row that is being manipulated, whereas a rule should not.

B<pre_fetch_action( { id =E<gt> $ } )>

Called before a fetch is done, although if an object is retrieved from
the cache this action is skipped. The only argument is the ID of the
object you are trying to fetch.

B<post_fetch_action( \% )>

Called after a fetch has been successfully completed, including after
a positive cache hit.

B<pre_save_action( { is_add =E<gt>; bool } )>

Called before a save has been attempted. If this is an add operation
(versus an update), we pass in a true value for the 'is_add' parameter.

B<post_save_action( { is_add =E<gt> bool } )>

Called after a save has been successfully completed. If this object
was just added to the data store, we pass in a true value for the
'is_add' parameter.

B<pre_remove_action( \% )>

Called before a remove has been attempted.

B<post_remove_action( \% )>

Called after a remove has been successfully completed.

=head1 FAILED ACTIONS

If an action fails, the 'fail' method associated with that action is
triggered. This can be a notification to an administrator, or saving
the data in the filesystem after a failed save.

B<fail_fetch()>

Called after a fetch has been unsuccessful.

B<fail_save()>

Called after a save has been unsuccessful.

B<fail_remove()>

Called after a remove has been unsuccessful.

=head1 CACHING

SPOPS has object caching built-in. As mentioned above, you will need
to define a B<global_cache> either in your SPOPS object class one of
its parents. Typically, you will put the I<stash class> in the @ISA of
your SPOPS object.

B<pre_cache_fetch()>

Called before an item is fetched from the cache; if this is called, we
know that the object is in the cache, we just have not retrieved it
yet.

B<post_cache_fetch()>

Called after an item is successfully retrieved from the cache.

B<pre_cache_save()>

Called before an object has been cached.

B<post_cache_save()>

Called after an object has been cached.

B<pre_cache_remove()>

Called before an object is removed from the cache.

B<post_cache_remove()>

Called after an object is successfully removed from the cache.

=head1 OTHER INDIVIDUAL OBJECT METHODS

B<get( $param_name )>

Returns the currently stored information within 
the object for $param.

 my $value = $obj->get( 'username' );
 print "Username is $value";

It might be easier to use the hashref interface to the same data,
since you can inline it in a string:

 print "Username is $obj->{username}";

You may also use a shortcut of the parameter name as a method call for
the first instance:

 my $value = $obj->username();
 print "Username is $value";

B<set( $param_name, $value )>

Sets the value of $param to $value. If value is empty, $param is set
to undef.

 $obj->set( 'username', 'ding-dong' );

Again, you can also use the hashref interface to do the same thing:

 $obj->{username} = 'ding-dong';

Note that unlike I<get>, You B<cannot> use the shortcut of using the
parameter name as a method. So a call like:

 my $username = $obj->username( 'new_username' );

Will silently ignore any parameters that are passed and simply return
the information as I<get()> would.

B<id()>

Returns the ID for this object. Checks in its config variable for the
ID field and looks at the data there.  If nothing is currently stored,
you will get nothing back.

Note that we also create a subroutine in the namespace of the calling
class so that future calls take place more quickly.

B<changed()>

Retuns the current status of the data in this object, whether it has
been changed or not.

B<has_change()>

Sets the I<changed> flag of this object to true.

B<clear_change()>

Sets the I<changed> flag of this object to false.

B<is_checking_fields()>

Returns 1 if this object (and class) check to ensure that you use only
the right fieldnames for an object, 0 if not.

B<timestamp()>

Returns the value of the timestamp_field for this object, undef if the
timestamp_field is not defined.

B<timestamp_compare( $ts_check )>

Returns true if $ts_check matches what is in the object, false
otherwise.

B<object_description()>

Returns a hashref with three keys of information about a particular
object:

 url
   URL that will display this object

 name
   Name of this general class of object (e.g., 'News')

 title
   Title of this particular object (e.g., 'Man bites dog, film at 11')

B<generate_random_code( $length )>

Generates a random code of $length length consisting of upper-case
characters in the english alphabet.

B<crypt_it( $text )>

Returns a crypt()ed version of $text. If $text not passed
in, returns undef.

B<now( \% )>

Return the current time, formatted: yyyy-mm-dd hh:mm:ss. Since we use
the L<Date::Format> module (which in turn uses standard strftime
formatting strings), you can pass in a format for the date/time to fit
your needs.

Parameters:

 format
   strftime format

 time
   return of time command (or manipulation thereof)

B<today()>

Return a date (yyyy-mm-dd) for today.

B<list_process( \@existing, \@new )>

Returns: hashref with three keys, each with an arrayref as the value:

 keep:   items found in both \@existing and \@new
 add:    items found in \@new but not \@existing
 remove: items found in \@existing but not \@new

Mainly used for determining one-to-many relationship changes, but you
can probably think of other applications.

=head1 ERROR HANDLING

(See L<SPOPS::Error> for now -- more later!)

=head1 NOTES

There is an issue using these modules with I<Apache::StatINC> along
with the startup methodology that calls the I<class_initialize> method
of each class when a httpd child is first initialized. If you modify a
module without stopping the webserver, the configuration variable in
the class will not be initialized and you will inevitably get errors.

We might be able to get around this by having most of the
configuration information as static class lexicals. But anything that
depends on any information from the CONFIG variable in request (which
is generally passed into the I<class_initialize> call for each SPOPS
implementation) will get hosed.

=head1 TO DO

B<Allow call to pass information to rulesets>

Modify all calls to C<pre_fetch_action> (etc.) to take a hashref of
information that can be used by the ruleset. For instance, if I do not
want an object indexed by the full-text ruleset (even though the class
uses it), I could do:

 eval { $obj->save( { full_text_skip => 1 } ) };

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

=head1 COPYRIGHT

Copyright (c) 2000 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

 Chris Winters (cwinters@intes.net)

=cut
