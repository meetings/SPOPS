package SPOPS::Configure;

# $Header: /usr/local/cvsdocs/SPOPS/SPOPS/Configure.pm,v 1.28 2000/10/16 16:33:06 cwinters Exp $

use strict;
use SPOPS::Error;
use SPOPS::Configure::Ruleset;
use Data::Dumper  qw( Dumper );

@SPOPS::Configure::ISA       = ();
$SPOPS::Configure::VERSION   = sprintf("%d.%02d", q$Revision: 1.28 $ =~ /(\d+)\.(\d+)/);

use constant DEBUG => 0;

my $DEFAULT_META = { parse_into_hash => [ qw/ field no_insert no_update skip_undef / ] };

sub process_config {
 my $class = shift;
 my $p     = shift;
 $p->{alias_list} ||= [ keys %{ $p->{config} } ];

 # So we can keep track of the classes we require/eval
 my @class_list = ();

 # First process all of the class-creation and config-creation
 # stuff...
 foreach my $alias ( @{ $p->{alias_list} } ) { 
   next if ( $alias =~ /^_/ ); # skip meta stuff
   $p->{config}->{ $alias }->{main_alias} = $alias;
   warn " (Configure/process_config): Setting $p->{config}->{ $alias }->{class} to $alias\n" if ( DEBUG );;
   my $create_class = $class->create_spops_class( $p, $p->{config}->{ $alias } );
   my $parse_class  = $class->parse_config( $p, $p->{config}->{ $alias } ); 
   push @class_list, $create_class  if ( $create_class eq $parse_class ); # just in case...
 }

 # Once everything is read in, then create the relationships among
 # the classes
 foreach my $alias ( @{ $p->{alias_list} } ) { 
   next if ( $alias =~ /^_/ ); # skip meta stuff
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
 my $class = shift;
 my $p     = shift;
 my $info  = shift;

 # Create the class on-the-fly (yee-haw!); just substitute our
 # keywords (currently only the class name) for the items in the
 # generic template above. Note that there really is not too much
 # stuff there
 warn " (Configure/create_spops_class): Creating $info->{class} on-the-fly.\n"  if ( DEBUG );
 my $module      = $GENERIC_TEMPLATE;
 $module        =~ s/%%CLASS%%/$info->{class}/g;
 my $isa_listing = join( ' ', @{ $info->{isa} } );
 $module        =~ s/%%ISA%%/$isa_listing/g;
 { 
   local $SIG{__WARN__} = sub { return undef };
   eval $module;
 }
 die " (Configure/create_spops_class): Could not create <<$info->{class}>> on the fly!\nError: $@"  if ( $@ );

 if ( $p->{require_isa} ) {
   foreach my $isa_class ( @{ $info->{isa} } ) {
     eval "require $isa_class";
     warn " (Configure/create_spops_class): Could not require the class ($isa_class). Error: $@\n"  if ( $@ );
   }
 }

 # Now that the class is created, see if we can leech some 
 # code from a concrete class specified in the config
 $class->_read_code_class( $info->{class}, $info->{code_class} ) if ( $info->{code_class} );
 return $info->{class};
}

sub parse_config {
 my $class = shift;
 my $p     = shift;
 my $info  = shift;
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
   }
   delete $info->{ $item };
   $count++;
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

 warn " (Configure/parse_config) Configuration information for ", 
      "$this_class is:\n", Dumper( $this_class->CONFIG )                   if ( DEBUG > 1 );
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
 my $class = shift;
 my $info  = shift;
 my $this_class = $info->{class};

 # First do the 'has_a' aliases; see POD documentation on this (below)
 $info->{has_a} ||= {};
 foreach my $hasa_class ( keys %{ $info->{has_a} } ) {
   warn " (Configure/create_relationship): Try to alias $this_class hasa $hasa_class\n" if ( DEBUG );
   my $hasa_config   = $hasa_class->CONFIG;
   my $hasa_id_field = $hasa_config->{id_field};
   my $id_fields = ( ref $info->{has_a}->{ $hasa_class } eq 'ARRAY' )
                      ? $info->{has_a}->{ $hasa_class } 
                      : [ $info->{has_a}->{ $hasa_class } ];
   my $num_id_fields = scalar @{ $id_fields };
   foreach my $usea_id_field ( @{ $id_fields } ) {
     warn " (Configure/create_relationship): Aliasing $hasa_class with field $usea_id_field within $this_class\n" if ( DEBUG );
     my $hasa_sub = $GENERIC_HASA;
     $hasa_sub =~ s/%%CLASS%%/$this_class/g;
     $hasa_sub =~ s/%%HASA_CLASS%%/$hasa_class/g;
     
     my $hasa_alias = undef;
     if ( $num_id_fields == 1 and $usea_id_field eq $hasa_id_field ) {
       $hasa_alias = $hasa_config->{main_alias}
     }
     else {
       $hasa_alias = join( '_', $usea_id_field, $hasa_config->{main_alias} );
     }
     $hasa_sub =~ s/%%HASA_ALIAS%%/$hasa_alias/g;
     $hasa_sub =~ s/%%HASA_ID_FIELD%%/$usea_id_field/g;
     warn " (Configure/create_relationship): Now going to eval the routine:\n$hasa_sub\n" if ( DEBUG > 1 );
     {
       local $SIG{__WARN__} = sub { return undef };
       eval $hasa_sub;
     }
     die " (Configure/create_relationship): Cannot eval has_a clause into $this_class. ",
         "Error: $@\nRoutine: $hasa_sub"                                if ( $@ );
   }
 }

 # Next, process the 'fetch_by' fields
 $info->{fetch_by} ||= [];
 foreach my $fetch_by_field ( @{ $info->{fetch_by} } ) {
   warn " (Configure/create_relationship): Creating routine for fetch_by_$fetch_by_field\n" if ( DEBUG );
   my $fetch_by_sub = $GENERIC_FETCH_BY;
   $fetch_by_sub    =~ s/%%CLASS%%/$this_class/g;
   $fetch_by_sub    =~ s/%%FETCH_BY_FIELD%%/$fetch_by_field/g;
   warn " (Configure/create_relationship): Now going to eval the routine:\n$fetch_by_sub\n" if ( DEBUG > 1 );
   {
     local $SIG{__WARN__} = sub { return undef };
     eval $fetch_by_sub;
   }
   die " (Configure/create_relationship): Cannot eval fetch_by routine into ",
       "$this_class using $fetch_by_field\nError: $@\nRoutine: $fetch_by_sub\n" if ( $@ );
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
sub _read_code_class {
 my $class      = shift;
 my $this_class = shift;
 my $code_class = shift;
 warn " (Configure/read_code_class): Trying to read code from $code_class to $this_class\n" if ( DEBUG );
 my $filename = $code_class;
 $filename =~ s|::|/|g;
 my $final_filename = undef;
 foreach my $prefix ( @INC ) {
   my $full_filename = "$prefix/$filename.pm";
   warn " (Configure/read_code_class): Try file: $full_filename\n"         if ( DEBUG > 1 );
   if (-f $full_filename ) {
     $final_filename = $full_filename;
     last;
   }
 }
 if ( $final_filename ) {
   open( PKG, $final_filename ) || die;
   my $code_pkg = undef;
   while ( <PKG> ) {
     if ( s/^\s*package $code_class\s*;\s*$/package $this_class;/ ) {
       $code_pkg .= $_;
       warn " (Configure/read_code_class): Package $code_class will be read in as $this_class\n" if ( DEBUG );
       last;
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
   warn " (Configure/read_code_class): Going to eval code:\n\n$code_pkg\n" if ( DEBUG > 1 );
   {
     local $SIG{__WARN__} = sub { return undef };
     eval $code_pkg;
   }
   die "(Configure/read_code_class): Could not read $code_class into $this_class\n",
       "Error: $@\n$code_pkg\n\n" if ( $@ );
 }
 else {  warn " **Filename not found for code in $code_class!\n" }
}

1;

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

B<code_class> ($)

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

B<name> (\&)

How can we find the name of an individual object? For instance, in a
contact database, the name of a person object is the full name of the
person.

Here we expect a code reference. It can do anything complicated you
like, but more often than not it is just:

 name => sub { return $_[0]->{my_name_field} }

Note: it is on the TO DO list for SPOPS to implement allowing a scalar
which names the property to use for assigning a name to an object.

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

Define a one-to-one relationship between objects. Currently, this
means that an object contains one or more fields that contain the ID
value of another object.

So the 'has_a' field of a configuration tells this class what these
relationships are, and this class automatically builds the subroutines
to make this happen.

Here is what you find in the 'has_a' field:

 { 
  SPOPS-tag => [ 'field_with_id_value', 'field_with_id_value' ],
 }

If you have the normal (simple) case, you will have something like:

  user => [ 'user_id' ]

Where the name of the 'field_with_id_value' matches up with the
'id_field' from the SPOPS class you are linking to. In this case, your
alias will simply be the SPOPS-tag:

  alias: 'user'

Which means you can call

 my $user = $obj->user;

And get back a SPOPS object.

However, if you have two or more items -- or one item that is not the
same name as the id_field -- identified by a single type but different
ID fields, e.g.

  user => [ 'created_by', 'fulfilled_by' ]

The alias created will be the id field followed by an underscore
followed by the type; in this case:

  alias: 'created_by_user'
  alias: 'fulfilled_by_user'

Or:

 my $create_user  = $obj->created_by_user;
 my $fulfill_user = $obj->fulfilled_by_user;

(Note: We are currently considering a proposal to change 'SPOPS-alias'
in the configuration field to 'SPOPS-class' so the configuration can
be more flexible.)

B<links_to> (\@)

(See L<SPOPS::Configure::DBI> for information.)

=head1 TO DO

=head1 BUGS

=head1 COPYRIGHT

Copyright (c) 2000 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

 Chris Winters (cwinters@intes.net)

=cut
