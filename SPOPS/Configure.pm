package SPOPS::Configure;

# $Id: Configure.pm,v 1.2 2001/02/20 04:46:36 lachoy Exp $

use strict;
use SPOPS qw( _w );
use SPOPS::Error;
use SPOPS::Configure::Ruleset;
use Data::Dumper  qw( Dumper );

@SPOPS::Configure::ISA       = ();
$SPOPS::Configure::VERSION   = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use constant DEBUG => 0;

my $DEFAULT_META = { 
    parse_into_hash => [ qw/ field no_insert no_update skip_undef / ] 
};

sub process_config {
  my ( $class, $p ) = @_;
  $p->{alias_list} ||= [ keys %{ $p->{config} } ];

  # So we can keep track of the classes we require/eval

  my @class_list = ();

  # First process all of the class-creation and config-creation
  # stuff...

  foreach my $alias ( @{ $p->{alias_list} } ) { 

    # skip meta stuff, which always begins with '_'
    next if ( $alias =~ /^_/ );
    $p->{config}->{ $alias }->{main_alias} = $alias;
    _w( 1, "Setting $p->{config}->{ $alias }->{class} to $alias");
    my $create_class = $class->create_spops_class( 
                                   $p, $p->{config}->{ $alias } );
    my $parse_class  = $class->parse_config( $p, $p->{config}->{ $alias } );

   # just in case...
    push @class_list, $create_class  if ( $create_class eq $parse_class ); 
  }

  # Once everything is read in, then create the relationships among
  # the classes

  foreach my $alias ( @{ $p->{alias_list} } ) { 

   # skip meta stuff, which always begins with a '_'

    next if ( $alias =~ /^_/ );
    $class->create_relationship( $p->{config}->{ $alias } );
  }
  return \@class_list;
}

# EVAL'ABLE PACKAGE/SUBROUTINES

# Here's our template for a module on the fly.
# Modify as necessary.

my $GENERIC_TEMPLATE = <<'PACKAGE';

       package %%CLASS%%;
       
       use strict;

       @%%CLASS%%::ISA     = qw( %%ISA%% );
       $%%CLASS%%::C       = {};

       sub %%CLASS%%::CONFIG  { return $%%CLASS%%::C; }

PACKAGE

sub create_spops_class {
  my ( $class, $p, $info ) = @_;
  
  # Create the class on-the-fly (yee-haw!); just substitute our
  # keywords (currently only the class name) for the items in the
  # generic template above. Note that there really is not too much
  # stuff there
  
  _w( 1, "Creating $info->{class} on-the-fly." );
  my $module      = $GENERIC_TEMPLATE;
  $module        =~ s/%%CLASS%%/$info->{class}/g;
  my $isa_listing = join( ' ', @{ $info->{isa} } );
  $module        =~ s/%%ISA%%/$isa_listing/g;
  { 
    local $SIG{__WARN__} = sub { return undef };
    eval $module;
  }
  die "Could not create <<$info->{class}>> on the fly!\nError: $@"  if ( $@ );

  if ( $p->{require_isa} ) {
    foreach my $isa_class ( @{ $info->{isa} } ) {
      eval "require $isa_class";
      warn "--Could not require the class ($isa_class). Error: $@\n"  if ( $@ );
    }
  }

  # Now that the class is created, see if we can leech some 
  # code from a concrete class specified in the config

  if ( $info->{code_class} ) {
    $class->_read_code_class( $info->{class}, $info->{code_class} );
  }
  return $info->{class};
}

sub parse_config {
  my ( $class, $p, $info ) = @_;
  my $meta = $p->{meta} || $p->{config}->{_meta} || $DEFAULT_META;
  my $this_class = $info->{class};

 # $MC should now be the (empty) configuration hashref for 
 # the class $this_class
  
  my $MC = $this_class->CONFIG;
  
  # We need to track the alias this initially used (particularly for
  # establishing relationships, see 'create_relationship' below)
  
  $MC->{main_alias} = $info->{alias};
  
  # When we change a listref to a hashref, keep the order
  # by maintaining a count; that way they can be re-ordered
  # if desired.
  
  foreach my $item ( @{ $meta->{parse_into_hash} } ) {
    next unless ( ref $info->{ $item } eq 'ARRAY' );
    my $count = 1;
    foreach my $subitem ( @{ $info->{ $item } } ) {
      $MC->{ $item }->{ $subitem } = $count;
      $count++;
    }
    delete $info->{ $item };
  }
   
 # Dereference all arrayrefs and hashrefs! Otherwise we might get
 # some deeply weird stuff going on because the classes'
 # configuration information would point to the original config 
 # object created here ($conf)
  
  foreach my $item ( keys %{ $info } ) {
    next unless ( $info->{ $item } );
    my $type = ref $info->{ $item };
    if ( $type eq 'ARRAY' ) { $MC->{ $item } = \@{ $info->{ $item } }; next }
    if ( $type eq 'HASH' )  { $MC->{ $item } = \%{ $info->{ $item } }; next }
    $MC->{ $item } = $info->{ $item }; # does CODE, scalar, object
  }
  
  _w( 2, "Configuration information for $this_class is:\n", 
      Dumper( $this_class->CONFIG ) );
  return $this_class;
}


# EVAL'ABLE PACKAGE/SUBROUTINES

my $GENERIC_HASA = <<'HASA';

       sub %%CLASS%%::%%HASA_ALIAS%% {
        my ( $self, $p ) = @_;
        return undef  unless ( $self->{%%HASA_ID_FIELD%%} );
        return %%HASA_CLASS%%->fetch( $self->{%%HASA_ID_FIELD%%}, $p );
       }
       
HASA

my $GENERIC_FETCH_BY = <<'FETCHBY';

       sub %%CLASS%%::fetch_by_%%FETCH_BY_FIELD%% {
        my ( $item, $fb_field_value, $p ) = @_;
        my $obj_list = $item->fetch_group( { where => "%%FETCH_BY_FIELD%% = ?",
                                             value => [ $fb_field_value ],
                                             %{ $p } } );
        if ( $p->{return_single} ) {
          return $obj_list->[0];
        }
        return $obj_list;
       }
       
FETCHBY


sub create_relationship {
  my ( $class, $info ) = @_;
  my $this_class = $info->{class};
  
  # First do the 'has_a' aliases; see POD documentation on this (below)
  
  $info->{has_a} ||= {};
  foreach my $hasa_class ( keys %{ $info->{has_a} } ) {
    _w( 1, "Try to alias $this_class hasa $hasa_class" );
    my $hasa_config   = $hasa_class->CONFIG;
    my $hasa_id_field = $hasa_config->{id_field};
    my $hasa_sub = $GENERIC_HASA;
    $hasa_sub =~ s/%%CLASS%%/$this_class/g;
    $hasa_sub =~ s/%%HASA_CLASS%%/$hasa_class/g;

    my $id_fields = ( ref $info->{has_a}->{ $hasa_class } eq 'ARRAY' )
                       ? $info->{has_a}->{ $hasa_class } 
                       : [ $info->{has_a}->{ $hasa_class } ];
    my $num_id_fields = scalar @{ $id_fields };
    foreach my $usea_id_info ( @{ $id_fields } ) {
      my ( $hasa_alias, $usea_id_field ) = '';
      if ( ref $usea_id_info eq 'HASH' ) {
        $usea_id_field = (keys %{ $usea_id_field })[0];
        $hasa_alias    = $usea_id_info->{ $usea_id_field };
      }
      else {
        $usea_id_field = $usea_id_info;
        if ( $usea_id_field eq $hasa_id_field ) {
          $hasa_alias = $hasa_config->{main_alias}
        }
        else {
          $hasa_alias = join( '_', $usea_id_field, $hasa_config->{main_alias} );
        }
      }
    
      my $this_hasa_sub = $hasa_sub;
      $this_hasa_sub =~ s/%%HASA_ALIAS%%/$hasa_alias/g;
      $this_hasa_sub =~ s/%%HASA_ID_FIELD%%/$usea_id_field/g;
      _w( 1, "Aliasing ($hasa_class) with field ($usea_id_field) ",
             "using alias ($hasa_alias) within ($this_class)" );
      _w( 2, "Now going to eval the routine:\n$this_hasa_sub" );
      {
        local $SIG{__WARN__} = sub { return undef };
        eval $this_hasa_sub;
      }
      if ( $@ ) {
        die " (Configure/create_relationship): Cannot eval has_a clause into $this_class. ",
            "Error: $@\nRoutine: $this_hasa_sub";
      }
    }
  }
  
  # Next, process the 'fetch_by' fields
  
  $info->{fetch_by} ||= [];
  foreach my $fetch_by_field ( @{ $info->{fetch_by} } ) {
    _w( 1, "Creating routine for fetch_by_$fetch_by_field" );
    my $fetch_by_sub = $GENERIC_FETCH_BY;
    $fetch_by_sub    =~ s/%%CLASS%%/$this_class/g;
    $fetch_by_sub    =~ s/%%FETCH_BY_FIELD%%/$fetch_by_field/g;
    _w( 2, "Now going to eval the routine:\n$fetch_by_sub" );
    {
      local $SIG{__WARN__} = sub { return undef };
      eval $fetch_by_sub;
    }
    if ( $@ ) {
      die " (Configure/create_relationship): Cannot eval fetch_by routine into ",
          "$this_class using $fetch_by_field\nError: $@\nRoutine: $fetch_by_sub\n";
    }
  }

  # Next, process the ruleset information, which is in a separate
  # module (maybe we should bring them back here...)
  
  SPOPS::Configure::Ruleset->create_relationship( $info );
  return $this_class;
}

#
# Usage $class->_read_code_class( 'MyApp::Object', 'OriginalClass::Object') 
# 

# Locates and reads in the file specified by the code class, changes
# the class's package then eval's the text so that the subroutines are
# all installed to the package we've just created on the fly rather
# than the package we originally used for the code. For instance, if
# you want to use the 'Interact::User' class, you need in your
# 'spops.perl' file something like:
# 
# 'class'      => 'MyApp::User',
# 'code_class' => 'Interact::User', 
#
# So we find the 'Interact::User' file (somewhere in @ISA), open it up
# and as we read it in replace the old package name ('Interact::User')
# with the new one ('MyApp::User'). We don't change the file, just the
# text that's read into memory. Once that's done, we eval it and it
# becomes part of the library!
#
#
# Note that 'code_class' can also be an arrayref of classes, each of
# which has its subroutines read into the main class
#
# Returns: arrayref of files used

sub _read_code_class {
  my ( $class, $this_class, $code_class ) = @_;
  my @files_used = ();
  unless ( ref $code_class eq 'ARRAY' ) {
    $code_class = [ $code_class ];
  }
  foreach my $read_code_class ( @{ $code_class } ) {
    _w( 1, "Trying to read code from $read_code_class to $this_class" );
    my $filename = $read_code_class;
    $filename =~ s|::|/|g;
    my $final_filename = undef;

PREFIX:
    foreach my $prefix ( @INC ) {
      my $full_filename = "$prefix/$filename.pm";
      _w( 2, "Try file: $full_filename" );
      if (-f $full_filename ) {
        $final_filename = $full_filename;
        last PREFIX;
      }
    }
    
    _w( 1, "File ($final_filename) will be used for $read_code_class" );
    if ( $final_filename ) {
      open( PKG, $final_filename ) || die $!;
      my $code_pkg = undef;
      push @files_used, $final_filename;

CODEPKG:
      while ( <PKG> ) {
        if ( s/^\s*package $read_code_class\s*;\s*$/package $this_class;/ ) {
          $code_pkg .= $_;
          _w( 1, " Package $read_code_class will be read in as $this_class" );
          last CODEPKG;
        }
        $code_pkg .= $_;
      }
   
      # Use a block here because we want the $/ setting to
      # NOT be localized in the while loop -- that would be bad, since
      # the 'package' substitution would never work after the first one...
      
      {
        local $/ = undef;
        $code_pkg .= <PKG>;
      }
      close( PKG );
      _w( 2, "Going to eval code:\n\n$code_pkg" );
      {
        local $SIG{__WARN__} = sub { return undef };
        eval $code_pkg;
        if ( $@ ) {
          die "(Configure/read_code_class): Could not read $code_class into $this_class\n",
              "Error: $@\n$code_pkg\n\n"; 
        }
      }
    }
    else {  
      warn " **Filename not found for code to be read in from $code_class\n";
    }
  }
  return \@files_used;
}

1;

__END__

=pod

=head1 NAME

SPOPS::Configure - read in configuration information for collections and create/configure

=head1 SYNOPSIS

 use Ad::This;
 use Ad::That;

 use SPOPS::Configure;
 
 my $classes = []; 
 $classes = SPOPS::Configure->parse_config( $conf );

=head1 DESCRIPTION

This class only has one method: parse_config. It takes a hashref 
of collection information and configures existing classes with 
any information necessary (including the @ISA for each) and also
whips up collection classes on the fly based on the data
found in the hashref passed in.

Note that this class is B<not required> to use SPOPS. You can happily
just define the configuration information right in your class and
never have a need to 

=head1 METHODS

B<process_config( \%params )>

Parameters:

 config (\%)
   A hashref of configuration information for one or more SPOPS
   objects. The key is the SPOPS object alias, the value is a hashref
   of configuration information corresponding to that alias.

   In the absence of an 'alias_list', each of the SPOPS objects
   specified in the configuration will be processed.

 alias_list (\@) (optional)
   List of aliases to process from the 'config'. Use this if for some
   reason you do not want to process all the aliases.

 meta (\%) (optional)
   Can also be in the 'config' hashref -- see information under
   'parse_config()' below.

B<create_spops_class( \%config, \%spops_config )>

Takes configuration information for a single SPOPS class, creates it
on-the-fly and reads in any external code when specified.

Note that you can pass a true value for the key 'require_isa' in the
\%config parameter. The routine will then try to 'require' every class
in the 'isa' field of your SPOPS class configuration.

Returns: the class name if successful.

B<parse_config( \%config, \%spops_config )>

Takes a hashref of configuration information and returns the classes
created/configured properly. 

One of the keys in the configuration is special. You can pass it in
directly as a parameter (using the 'meta' key) or put it in the
configuration (using the '_meta' key). If you do neither, the system
will use a default (currently consisting of parsing the fields
'field', 'no_insert', 'no_update' and 'skip_undef' from an arrayref
into a hashref.)

This 'meta' information allows you to manipulate the information in
the configuration. Generally this is only for easier input: who wants
to type out an entire hashref when all you want is to list some fields
that get used later as lookups?

The 'meta' information is a hashref. Currently the only supported key
is 'parse_into_hash', which takes a listref and makes it into a
hashref to facilitate individual lookups. (No 'grep in a void context'
for us!)

So we read in the \%spops_config information, massage it if necessary
and assign the information to the SPOPS class configuration. After
this class is run you should be able to call:

 my \%class_config = $object_class->CONFIG;

And get back a hashref of configuration information for the class.

Returns: the class name if successful.

B<create_relationship>

Currently this creates the 'has_a' relationship and installs the
ruleset information in each class that asks for it.

See the writeup below under L<Relationship Fields>.

Returns: the class name if successful.

B<_read_code_class>

Used internally to emulate some of what 'require' does to find a file
with code and then reads the subroutines into another package.

Returns: arrayref of filenames that whose subroutines were read into
the SPOPS object class.

=head1 CONFIGURATION FIELDS EXPLAINED

The configuration for a SPOPS class can be elaborate or minimal,
depending on your needs. 

=head2 Required Fields

B<class> ($)

Name the class you want to create. 

B<field> (\@) (parsed into \%)

List the properties of the object. If you try to assign to a property
that is not in the list, L<SPOPS::Tie> will warn you and the
assignment will be discarded. For instance:

 # configuration
 class => 'My::HipHop',
 field => [ qw/ hip hop hooray / ],
 ...

 # code
 my $obj = My::HipHop->new;
 $obj->{'boo-yah'} = "and he said";

will result in a warning.

B<isa> (\@)

List the classes that your class inherits from. This can be a
combination of SPOPS and other classes -- for instance, you might use
L<SPOPS::DBI> for serialization functinality but another class
(C<My::FullTextIndex>) to implement a ruleset for full-text
indexing. (See L<SPOPS> for more information on rulesets.)

B<id_field> ($)

Name the field that will be used to uniquely identify an object. The
type of field does not matter, but the fact that each value is unique
does. You also cannot use an empty string (or undef, or 'NULL') as an
identifier.

SPOPS does not currently deal with objects that use multiple fields to
identify a record. (In database parlance, this is a "multiple field
primary key".) To get around the restriction, you can simply add
another field to the record and use it as a primary key. Instead of
using the 'fetch' method to retrieve records, you can create a simple
'fetch_by_blah' that takes two fields instead of one. (Note: on the TO
DO list for SPOPS is the ability to create a 'fetch_by_blah' method
on-the-fly from configuration information.

=head2 Optional Fields

B<code_class> ($ or \@)

Note: This is B<not> optional if you wish to draw code from a class
separate from the one you are creating.

When this class finds a 'code_class' value, it tries to find the class
somewhere in @ISA. If it can find the class, it reads the file in and
puts the subroutines into the class you are creating. For instance:

 ...
 class      => 'My::Tofu',
 code_class => 'Food::Tofu',
 ...

Will read the routines from 'Food::Tofu' and put them into the
'My::Tofu' namespace. (It will also currently put any lexical
variables from the code class into your class, so be careful.)

You can also bring in routines from multiple files:

 ...
 class      => 'My::Tofu',
 code_class => [ 'Food::Tofu', 'Food::Soybean', 'Food::Vegan' ],
 ...

However, you should be careful with this. Possibilities abound for
different classes defining the same subroutine and similar actions
which are quite difficult to debug.

B<no_security> ($)

Set this to a true value if you do not want this class to use
security. This overrides all other values -- even if you have
L<SPOPS::Secure> in the 'isa' of your class, security will not be
checked if this value is true. Be careful!

B<no_insert> (\@) (parsed into (\%)

Specify fields that should not be included when we first create a
record.

B<no_update> (\@) (parsed into (\%)

Specify fields whose values should never be changed when we update a
record.

B<skip_undef> (\@) (parsed into (\%)

Specify fields that are not included on either a create or update if
they are not defined. (Note that 'undef' is a bit of a misnomer -- we
do a simple perl 'truth' test to see if the field exists or not.)

B<alias> (\@)

What other aliases do you want this class to be known under? SPOPS
does not currently do anything with this, but implementations can.

B<display> (\%)

How should this object be displayed? Currently, the hashref it points
to must have at least one key 'url', to which SPOPS appends a query
string to identify this object.

The query string it appends is very simple, something like:

 url . ? . $class->CONFIG->{id_field} . = . $object->id()

B<name> (\&)

How can we find the name of an individual object? For instance, in a
contact database, the name of a person object is the full name of the
person.

Here we expect either a code reference or a scalar. Most often you
will use a scalar, which just names the field within an object to use,
such as:

 name => 'title'

The code reference can do anything complicated you like, but more
often than not it is just something like:

 name => sub { return join( ', ', $_[0]->{field1}, $_[0]->{field2} ) }

B<object_name> ($)

What is the generic name for an object? For instance, 'Document',
'Link', 'Page', 'Food'.

B<as_string_order> (\@)
B<as_string_label> (\%)

Every SPOPS object has a method 'as_string' as defined in
L<SPOPS>. However, this is a very blunt instrument as it basically
just dumps out the properties of the object into a string without any
nice labelling or control over order. The 'as_string_order' field
allows you to list the fields you want included in the 'as_string'
output along with their order, and 'as_string_label' allows you to
assign a label to these fields.

B<creation_security> (\%) (used by SPOPS::Secure)

See L<SPOPS::Secure> for more information how this is used.

B<base_table> ($) (used by SPOPS::DBI)

Table name for data to be stored.

B<sql_defaults> (\@) (used by SPOPS::DBI)

List of fields that have defaults defined in the SQL table. For
instance:

   active   CHAR(3) NOT NULL DEFAULT 'yes',

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

B<has_a> (\%)

Define a one-to-one relationship from one object to
another. Currently, this means that an object has one or more fields
that contain the ID value of another object. The 'has_a' field of a
configuration tells this class what these relationships are, and this
class automatically builds the subroutines to make this happen.

Here is a simple example that many people are familiar with in which a
user can belong to a single group.

 my $spops = {
   user => {
     field    => [ 'user_id', 'group_id', 'email' ],
     id_field => 'user_id',
     class    => 'My::User',
     has_a    => { 'My::Group' => [ 'group_id' ] },
     ...
   },
   group => {
     field    => [ 'group_id', 'name' ],
     id_field => 'group_id',
     class    => 'My::Group',
     ...
   },

 };

Here are the steps this class goes through to create a subroutine you
can call from one object to retrieve its associated object. (Using the
above example, to retrieve a C<My::Group> object given a C<My::User>
object.)

=over 4

=item 1.

Find the SPOPS configuration information matching the SPOPS class
given as the key. ('My::Group' under {user}-E<gt>{has_a} in the example
above.) We will call this the SPOPS-Has below.

=item 2.

Compare the 'id_field' in the SPOPS-Has information ('group_id' under
{group}-E<gt>{id_field} in the example) to the field given as the key
in the original link ('group_id' under
{user}-E<gt>{has_a}-E<gt>{'My::Group'} in the example).

=item 3.

If the 'id_field' and the linking field are the same, create a
subroutine of the same name as the SPOPS-Has tag. This is true in the
above example, so we can do:

 # Retrieve a My::User object
 my $user = My::User->fetch( 13 );

 # Retrieve the My::Group object related to this My::User object
 my $group = $user->group();

since the field specified in the user 'has_a' clause matches the
id_field specified in the class it is linking to.

=item 4.

If the 'id_field' and the linking field are B<not> the same we either
create a subroutine automatically or allow the configuration to
specify one for us. We will deal with both possibilities below.

First, the automatic creation. For this example, replace the above
definition for 'user' with:

   user => {
     field    => [ 'user_id', 'group_id', 'subgroup_id', 'email' ],
     id_field => 'user_id',
     class    => 'My::User',
     has_a    => { 'My::Group' => [ 'group_id', 'subgroup_id' ] },
     ...
   },

Now we have two relationships: the user belongs to both a group and a
subgroup. Both the group and subgroup are instances of the same class,
so we cannot refer to both of them using the 'group' alias as we did
in the previous example.

Once the above configuration is processed, we can do:

 # Retrieve a My::User object
 my $user = My::User->fetch( 13 );

 # Retrieve the My::Group object related to this My::User object by
 # the 'group_id' field
 my $group = $user->group();

 # Retrieve the My::Group object related to this My::User object by
 # the 'subgroup_id' field
 my $subgroup = $user->subgroup_id_group();

So we create a subroutine with the name:

 my $subroutine_name = join( '_', $id_field, $link_alias );

In this case, $id_field is 'subgroup_id' and $alias is 'group'.

You can sometimes use this to your advantage but it makes for some
awkward naming schemes. However, you can use another means of
naming. The custom means allows you to do something like this:


   user => {
     field    => [ 'user_id', 'group_id', 'subgroup_id', 'email' ],
     id_field => 'user_id',
     class    => 'My::User',
     has_a    => { 'My::Group' => [ 'group_id', 
                                    { subgroup_id => 'subgroup' } ] },
     ...
   },

Now you can do the following:

 # Retrieve a My::User object
 my $user = My::User->fetch( 13 );

 # Retrieve the My::Group object related to this My::User object by
 # the 'group_id' field
 my $group = $user->group();

 # Retrieve the My::Group object related to this My::User object by
 # the 'subgroup_id' field
 my $subgroup = $user->subgroup();

Here, instead of relying on SPOPS to name the subroutine for us that
maps to the $id_field 'subgroup_id', we named it ouselves. The only
warning here is to ensure that you do not create a subroutine of the
same name in a 'code_class', otherwise the 'code_class' routine will
get overwritten.

B<fetch_by> (\@)

Create a 'fetch_by_{fieldname}' routine that simply returns an
arrayref of objects that match the value of a particular field.

Example:

 my $spops = {
   user => {
     field    => [ 'user_id', 'group_id', 'subgroup_id', 'email' ],
     id_field => 'user_id',
     class    => 'My::User',
     fetch_by => [ 'email' ],
     ...
   },
 };

Allows us to do:

 my $user_list = My::User->fetch_by_email( 'allyour@base.ours.com' );
 foreach my $user ( @{ $user_list } ) {
   send_email( $user->{email}, "This is an invalid address" );
 }

B<links_to> (\@)

(See L<SPOPS::Configure::DBI> for information.)

=head1 TO DO

B<Creating a file of code>

Instead of always reading the code into memory we might want to create
a file with the new package if it is not found the first time or if it
is modified in the process here. This would allow offline tools to
modify a SPOPS configuration and generate a class with subroutines
from more than one class...

B<Make 'code_class' more flexible>

Instead of making 'code_class' read in just packages, maybe we want to
have a file of just subroutines that gets included to the class.

=head1 BUGS

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
