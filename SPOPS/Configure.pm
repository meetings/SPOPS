package SPOPS::Configure;

# $Id: Configure.pm,v 1.13 2001/07/20 02:25:20 lachoy Exp $

use strict;
use Data::Dumper  qw( Dumper );
use SPOPS         qw( _w DEBUG );
use SPOPS::Error;
use SPOPS::Configure::Ruleset;

@SPOPS::Configure::ISA       = ();
$SPOPS::Configure::VERSION   = '1.7';
$SPOPS::Configure::Revision  = substr(q$Revision: 1.13 $, 10);

my $DEFAULT_META = {
    parse_into_hash => [ qw/ field no_insert no_update skip_undef / ] 
};


sub process_config {
    my ( $class, $p ) = @_;
    return unless ( ref $p->{config} eq 'HASH' );

    $p->{alias_list} ||= [ keys %{ $p->{config} } ];

    # So we can keep track of the classes we require/eval

    my @class_list = ();

    # First process all of the class-creation and config-creation
    # stuff...

    # It would be nice to have an iterator here which automatically
    # skips entries beginning with '_'...

    foreach my $alias ( @{ $p->{alias_list} } ) {
        next if ( $alias =~ /^_/ );
        my $class_info = $p->{config}->{ $alias };
        $class_info->{main_alias} = $alias;
        DEBUG() && _w( 1, "Setting $class_info->{class} to $alias");

        # Put the _meta settings into this class (determines how certain
        # configuration items get parsed)

        $class_info->{_meta} = $p->{meta} || $p->{config}->{_meta} || $DEFAULT_META;

        # Bring in all the classes in ISA if requested. We should do this
        # before creating the class :-)

        if ( $p->{require_isa} ) {
            $class->require_isa( $class_info );
        }

        my $config_class  = $class->find_config_class( $class_info, $p->{default_config_class} );
        my $create_class  = $config_class->create_spops_class( $class_info );
        my $install_class = $config_class->install_class_config( $class_info );

        # Ensure that the class was actually created and that the
        # create/install classes are the same before we push them into the
        # return value

        if ( $create_class and $create_class eq $install_class ) {
            push @class_list, $create_class; 
        }
    }

    # Once everything is read in, then create the relationships among
    # the classes

    # It would be nice to have an iterator here which automatically
    # skips entries beginning with '_'...

    foreach my $alias ( @{ $p->{alias_list} } ) { 
        next if ( $alias =~ /^_/ );
        my $class_info = $p->{config}->{ $alias };
        my $config_class = $class->find_config_class( $class_info );
        $config_class->create_relationship( $class_info );
    }

    # Return the list of classes created properly

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

       # Get the ID of this object, and optionally set it as well.

       sub %%CLASS%%::id {
          my ( $self, $new_id ) = @_;
          my $id_field = $self->id_field 
                           || die "Cannot find ID for object since ",
                                  "no ID field specified for class ", ref $self, "\n";
          return $self->{ $id_field } unless ( $new_id );
          return $self->{ $id_field } = $new_id; 
       }

PACKAGE



sub create_spops_class {
    my ( $class, $class_info ) = @_;
  
    # Create the class on-the-fly (yee-haw!); just substitute our
    # keywords (currently only the class name) for the items in the
    # generic template above. Note that there really is not too much
    # stuff there
  
    DEBUG() && _w( 1, "Creating $class_info->{class} on-the-fly." );
    my $module      = $GENERIC_TEMPLATE;
    $module        =~ s/%%CLASS%%/$class_info->{class}/g;
    my $isa_listing = join( ' ', @{ $class_info->{isa} } );
    $module        =~ s/%%ISA%%/$isa_listing/g;

    DEBUG() && _w( 3, "Trying to create class with the code:\n$module\n" );

    # Capture 'warn' calls that get triggered as a result of warnings,
    # redefined subroutines or whatnot; these get dumped to STDERR and
    # we want to be as quiet as possible -- or at least control our
    # noise!

    { 
        local $SIG{__WARN__} = sub { return undef };
        eval $module;
        if ( $@ ) {
            die "Could not create <<$class_info->{class}>> on the fly!\nError: $@";
        }
    }

    # Now that the class is created, see if we can leech some code from
    # one or more concrete classes specified in the config

    if ( $class_info->{code_class} ) {
        $class->read_code_class( $class_info->{class}, $class_info->{code_class} );
    }
    return $class_info->{class};
}


# Ensure our new class has access to its configuration information

sub install_class_config {
    my ( $class, $class_info ) = @_;
    my $this_class = $class_info->{class};

    # $CLASS_CONFIG should now be the (empty) configuration hashref for 
    # the class $this_class and retrievable by ->CONFIG
  
    my $CLASS_CONFIG = $this_class->CONFIG;
  
    # We need to track the alias this initially used (particularly for
    # establishing relationships, see 'create_relationship' below)

    $CLASS_CONFIG->{main_alias} = $class_info->{alias};

    # When we change a listref to a hashref, keep the order
    # by maintaining a count; that way they can be re-ordered
    # if desired.
  
    $class_info->{_meta} ||= {};
    if ( ref $class_info->{_meta}->{parse_into_hash} eq 'ARRAY' ) {
        foreach my $item ( @{ $class_info->{_meta}->{parse_into_hash} } ) {
            next unless ( ref $class_info->{ $item } eq 'ARRAY' );
            my $count = 1;
            foreach my $subitem ( @{ $class_info->{ $item } } ) {
                $CLASS_CONFIG->{ $item }->{ $subitem } = $count;
                $count++;
            }
            delete $class_info->{ $item };
        }
    }
   
    # Dereference all arrayrefs and hashrefs! Otherwise we might get
    # some deeply weird stuff going on because the class's
    # configuration information would point to the original config 
    # object created here ($conf).
  
    foreach my $item ( keys %{ $class_info } ) {
        next unless ( $class_info->{ $item } );
        my $type = ref $class_info->{ $item };
        if ( $type eq 'ARRAY' ) { 
            $CLASS_CONFIG->{ $item } = \@{ $class_info->{ $item } };
            next;
        }
        if ( $type eq 'HASH' )  {
            $CLASS_CONFIG->{ $item } = \%{ $class_info->{ $item } };
            next;
        }

        # does CODE, scalar, object
        $CLASS_CONFIG->{ $item } = $class_info->{ $item };
    }
  
    DEBUG() && _w( 2, "Configuration information for $this_class after running ",
                      "install_class_config() is:\n", Dumper( $this_class->CONFIG ) );
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


# Create a 'has_a' relationship between two SPOPS objects

sub create_relationship {
    my ( $class, $class_info ) = @_;
    my $this_class = $class_info->{class};
  
    # First do the 'has_a' aliases; see POD documentation on this (below)

    $class_info->{has_a} ||= {};
    foreach my $hasa_class ( keys %{ $class_info->{has_a} } ) {
        DEBUG() && _w( 1, "Try to alias $this_class hasa $hasa_class" );
        my $hasa_config   = $hasa_class->CONFIG;
        my $hasa_id_field = $hasa_config->{id_field};
        my $hasa_sub = $GENERIC_HASA;
        $hasa_sub =~ s/%%CLASS%%/$this_class/g;
        $hasa_sub =~ s/%%HASA_CLASS%%/$hasa_class/g;

        # Each defined relationship can be between more than one instance
        # of another class, each of which is linked to a separate ID
        # field.. For instance, if my SPOPS objects had two user_id fields
        # in it (say, 'created_by' and 'last_updated_by'), then I need to
        # create *two* links from this class to the user class.

        # Example:
    
        # This specification has two links to one class:

        #   has_a => { 'MySPOPS::User' => [ 'created_by', 'updated_by' ], ... }

        # This specification has one link to one class:

        #   has_a => { 'MySPOPS::User' => 'created_by', ... }

        my $id_fields = ( ref $class_info->{has_a}->{ $hasa_class } eq 'ARRAY' )
                        ? $class_info->{has_a}->{ $hasa_class } 
                        : [ $class_info->{has_a}->{ $hasa_class } ];
        my $num_id_fields = scalar @{ $id_fields };
        foreach my $usea_id_info ( @{ $id_fields } ) {
            my ( $hasa_alias, $usea_id_field ) = '';

            # This can be a hash when we want to specify the alias name in
            # the configuration rather than let SPOPS create it for
            # us. Something like the following where we want use the alias
            # 'creator' rather than the alias SPOPS will create,
            # 'created_by_user':

            # has_a => { 'MySPOPS::User' => [ { 'created_by' => 'creator' }, ... ], ... }

            if ( ref $usea_id_info eq 'HASH' ) {
                $usea_id_field = ( keys %{ $usea_id_info } )[0];
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
            DEBUG() && _w( 1, "Aliasing ($hasa_class) with field ($usea_id_field) ",
                              "using alias ($hasa_alias) within ($this_class)" );
            DEBUG() && _w( 3, "Now going to eval the routine:\n$this_hasa_sub" );
            {
                local $SIG{__WARN__} = sub { return undef };
                eval $this_hasa_sub;
            }
            if ( $@ ) {
                die "Cannot eval has_a clause into $this_class.\n",
                    "Error: $@\nRoutine: $this_hasa_sub";
            }
        }
    }
  
    # Next, process the 'fetch_by' fields
  
    $class_info->{fetch_by} ||= [];
    foreach my $fetch_by_field ( @{ $class_info->{fetch_by} } ) {
        DEBUG() && _w( 1, "Creating routine for fetch_by_$fetch_by_field" );
        my $fetch_by_sub = $GENERIC_FETCH_BY;
        $fetch_by_sub    =~ s/%%CLASS%%/$this_class/g;
        $fetch_by_sub    =~ s/%%FETCH_BY_FIELD%%/$fetch_by_field/g;
        DEBUG() && _w( 3, "Now going to eval the routine:\n$fetch_by_sub" );
        {
            local $SIG{__WARN__} = sub { return undef };
            eval $fetch_by_sub;
        }
        if ( $@ ) {
            die "Cannot eval fetch_by routine into $this_class using $fetch_by_field\n",
                "Error: $@\n",
                "Routine: $fetch_by_sub";
        }
    }

    # Next, process the ruleset information, which is in a separate
    # module (maybe we should bring them back here...)
  
    SPOPS::Configure::Ruleset->create_relationship( $class_info );
    return $this_class;
}


#
# Usage $class->read_code_class( 'MyApp::Object', 'OriginalClass::Object');
#   or
# Usage $class->read_code_class( 'MyApp::Object', 
#                                [ 'OriginalClass::Object', 'AnotherClass::Object ] );
# Returns: arrayref of files used

sub read_code_class {
    my ( $class, $this_class, $code_class ) = @_;
    my @files_used = ();
    unless ( ref $code_class eq 'ARRAY' ) {
        $code_class = [ $code_class ];
    }
    foreach my $read_code_class ( @{ $code_class } ) {
        DEBUG() && _w( 1, "Trying to read code from $read_code_class to $this_class" );
        my $filename = $read_code_class;
        $filename =~ s|::|/|g;
        my $final_filename = undef;

PREFIX:
        foreach my $prefix ( @INC ) {
            my $full_filename = "$prefix/$filename.pm";
            DEBUG() && _w( 2, "Try file: $full_filename" );
            if (-f $full_filename ) {
                $final_filename = $full_filename;
                last PREFIX;
            }
        }
    
        DEBUG() && _w( 1, "File ($final_filename) will be used for $read_code_class" );
        if ( $final_filename ) {
            open( PKG, $final_filename ) || die $!;
            my $code_pkg = undef;
            push @files_used, $final_filename;

CODEPKG:
            while ( <PKG> ) {
                if ( s/^\s*package $read_code_class\s*;\s*$/package $this_class;/ ) {
                    $code_pkg .= $_;
                    DEBUG() && _w( 1, " Package $read_code_class will be ",
                                      "read in as $this_class" );
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
            DEBUG() && _w( 3, "Going to eval code:\n\n$code_pkg" );
            {
                local $SIG{__WARN__} = sub { return undef };
                eval $code_pkg;
                if ( $@ ) {
                    die "Could not read $code_class into $this_class\n",
                        "Error: $@\n",
                        "$code_pkg";
                }
            }
        }
        else {  
            warn " **Filename not found for code to be read in from $code_class\n";
        }
    }
    return \@files_used;
}


# Note: you should have called 'require_isa()' before calling this. If
# you haven't, I'm not responsible for the consequences!

sub find_config_class {
    my ( $class, $class_info ) = @_;
    my $config_class = __PACKAGE__;

    # Test for SPOPS::DBI-ness -- since 'SPOPS::DBI' is normally at the
    # bottom of the stack, we flip it (sneaky)

    foreach my $parent_class ( reverse @{ $class_info->{isa} } ) {
        next unless ( $parent_class );
        DEBUG() && _w( 1, "Try to see if parent ($parent_class) isa SPOPS::DBI" );
        my $isa_dbi = eval { $parent_class->isa( 'SPOPS::DBI' ) };
        if ( $@ ) { 
            _w( 0, "Looks like you didn't run 'require_isa()' before 'find_config_class()'",
                   "since I got the following error when running '->isa()' on",
                   "($parent_class): $@" );
            next;
        }
        if ( $isa_dbi ) {
            DEBUG() && _w( 1, "Yes, ($parent_class) isa SPOPS::DBI. Use ",
                              "SPOPS::Configure::DBI to configure." );
            $config_class = 'SPOPS::Configure::DBI';
            last;
        }
    }
    DEBUG() && _w( 2, "Resulting configuration class for ",
                      "($class_info->{class}): $config_class" );

    # So we don't have to 'use SPOPS::Configure::Blah' anywhere else...

    eval "require $config_class" if ( $config_class ne __PACKAGE__ );
    return $config_class;
}


# 'require' all the classes listed in the 'isa' key of \%class_info

sub require_isa {
    my ( $class, $class_info ) = @_;
    foreach my $isa_class ( @{ $class_info->{isa} } ) {
        eval "require $isa_class";
        die "Could not require the class ($isa_class). Error: $@"  if ( $@ );
    }
    return 1;
}


1;

__END__

=pod

=head1 NAME

SPOPS::Configure - read in configuration information for collections and create/configure

=head1 SYNOPSIS

 use SPOPS::Configure;
 
 my $conf = {
     fatbomb => {
       class        => 'My::ObjectClass',
       isa          => [ qw/ SPOPS::DBI::MySQL SPOPS::DBI / ],
       increment_field => 1,
       field        => [ qw/ fatbomb_id calories cost name servings / ],
       no_insert    => [ qw/ fatbomb_id / ],
       base_table   => 'fatbomb',
       id_field     => 'fatbomb_id',
       skip_undef   => [ qw/ servings / ],
       sql_defaults => [ qw/ servings / ],
     },
 };

 my $classes = SPOPS::Configure->process_config( $conf );
 My::ObjectClass->class_initialize();

 # You can also use the SPOPS::Initialize to process a configuration
 # from a file and do multiple objects for you -- it's a piece of
 # cake!

 use SPOPS::Initialize;
 SPOPS::Initialize->process({ filename => 'my_spops.perl' });

=head IMPORTANT NOTE

SPOPS::Configure and SPOPS::Configure::DBI may be changing radically
in the near future (July/August 2001). We will try to maintain
backward compatibility with all changes, but just be aware they are
coming.

=head1 DESCRIPTION

This class only has one public method: C<process_config>. It takes a
hashref of collection information and configures existing classes with
any information necessary (including the @ISA for each) and also whips
up SPOPS classes on the fly based on the data found in the hashref
passed in.

The classes created will each have the following methods:

=over 4

=item *

B<CONFIG>: Returns a reference to the configuration information in the
class.

=item *

B<RULESET>: Returns a reference to the table of rules installed to the
class.

=item *

B<id>: Returns the ID for an instance of this class. (See L<NOTES>
below for SPOPS subclass authors.)

=back

=head1 METHODS

B<process_config( \%params )>

Parameters:

=over 4

=item *

B<config> (\%)

A hashref of configuration information for one or more SPOPS
objects. The key is the SPOPS object alias, the value is a hashref of
configuration information corresponding to that alias.

In the absence of an 'alias_list', each of the SPOPS objects specified
in the configuration will be processed.

=item *

B<alias_list> (\@) (optional)

List of aliases to process from the 'config'. Use this if for some
reason you do not want to process all the aliases.

=item *

B<meta> (\%) (optional)

Can also be in the 'config' hashref -- see information under
'install_class_config()' below.

=item *

B<require_isa> (bool) (optional)

Pass a true value to 'require' every class in the 'isa' field of each
SPOPS class configuration. (This is actually done by the
<require_isa()> method, below.)

=back

Returns: An arrayref of the SPOPS classes successfully created.

B<create_spops_class( \%spops_config )>

Takes configuration information for a single SPOPS class, creates it
on-the-fly and reads in any external code when specified.

Returns: the class name if successful.

B<install_class_config( \%spops_config )>

Takes a hashref of configuration information and installs it to the
SPOPS class presumably just created.

One of the keys ('_meta') in the configuration is special because it
has directives for the config installer to perform. If do not pass it
in with the C<\%spops_config> info, we use a default (the class
variable $DEFAULT_META).

This 'meta' information allows you to manipulate the information in
the configuration. Generally this is only for easier input: who wants
to type out an entire hashref when all you want is to list some fields
that get used later as lookups?

The 'meta' information is a hashref. Currently the only supported key
is 'parse_into_hash', which takes a listref of fields which it will
change from a listref to a hashref when installing the class to
facilitate individual lookups. (No 'grep in a void context' for us!)

Contrived example where 'field1' is transformed from a listref in the
original configuration information to a hashref:

 $spops_config->{_meta}->{parse_into_hash} = [ qw/ field1 field2 / ];
 $spops_config->{field1} = [ qw/ first second third fourth fifth / ];
 my $spops_class = $class->install_class_config( $spops_config );

 print Data::Dumper::Dumper( $spops_class->CONFIG->{field1} );

 >>  $VAR1 = {
      'fifth' => 5,
      'first' => 1,
      'fourth' => 4,
      'second' => 2,
      'third' => 3,
    };

So we read in the \%spops_config information, massage it as necessary
and assign the information to the SPOPS class configuration. After
this class is run you should be able to call:

 my \%class_config = $object_class->CONFIG;

And get back a hashref of configuration information for the
class. This configuration information is also used by the reflection
methods of SPOPS, like C<id_field()>, C<field_list()> and so on.

Returns: the class name if successful.

B<create_relationship( \%spops_config )>

Currently this creates the 'has_a' relationship and installs the
ruleset information in each class that asks for it.

See the writeup below under L<Relationship Fields>.

Returns: the class name if successful.

B<read_code_class( $new_package_class, [ \@code_class | $code_class ] )>

Used internally to emulate some of what 'require' does to find a Perl
class (.pm) then reads the subroutines into another package.

Locates and reads in the file specified by the code class (first arg),
changes the package of the Perl module then runs c<eval ""> on the
text of the module so that the subroutines are all installed to the
package we have just created on the fly rather than the package we
originally used for the code. For instance, if you want to use the
'OpenInteract::User' class, you need in your 'spops.perl' file something
like:

  'class'      => 'MyApp::User',
  'code_class' => 'OpenInteract::User', 

So we find the 'OpenInteract::User' file (somewhere in @ISA), open it
up and as we read it in replace the old package name
('OpenInteract::User') with the new one ('MyApp::User'). We do not
change the file, just the text that is read into memory. Once that is
done, we eval it and it becomes part of the library!

If the file is not found in @ISA we issue a C<warn> but that is
all. In the future we might C<die>.

Note that 'code_class' can also be an arrayref of classes, each of
which has its subroutines read into the main class. This way you can
create a generic routine for many objects and implement the behavior
in all of them. (Of course, you could also simply put the generic
routine package into the ISA hierarchy for each object. TMTOWTDI.)

Returns: arrayref of filenames whose subroutines were read into the
SPOPS object class.

B<find_config_class( \%spops_config )>

Returns the class that should process the configuration for this
class. Currently this simply goes through the 'isa' elements of the
class and returns the appropriate C<SPOPS::Configure> subclass (e.g.,
if we find C<SPOPS::DBI> as a parent of the class we return
C<SPOPS::Configure::DBI> as the class to process it.)

Note that only one C<SPOPS::Configure> child can be used as the main
config class. If you have a need for more, let us know on the
openinteract-dev@lists.sourceforce.net mailing list.

B<require_isa( \%spops_config )>

Run a 'require' on all the 'isa' classes in a SPOPS configuration
entry.

=head1 CONFIGURATION FIELDS EXPLAINED

The configuration for a SPOPS class can be elaborate or minimal,
depending on your needs. 

=head2 Required Fields

B<class> ($)

Name the class you want to create. 

B<field> (\@) (parsed into \%)

List the properties of the object. If you use the 'strict_field' key
(below) and try to assign to a property that is not in the list,
L<SPOPS::Tie> will warn you and the assignment will be discarded. For
instance:

 # configuration

 class => 'My::HipHop',
 field => [ qw/ hip hop hooray / ],
 strict_field => 1,
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
'fetch_by_blah' that takes two fields instead of one.

=head2 Optional Fields

B<strict_field> (bool) (optional)

As mentioned above, if you specify this SPOPS will issue a warning any
time you try to get/set a property that does not exist in the object.

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

The query string it appends is very simple, persforming something
like:

 my $id_query = join( '=', $object->CONFIG->{id_field}, $object->id() );
 my $URL = '/Object/show/?' $id_query;

So the resulting URL for a class with 'id_field' as 'news_id' and an
ID of 5 would look like:

 /Object/show/?news_id=5

The URL you define is entirely separate from SPOPS and is not
determined by it, or auto-generated by it, at all.

B<name> ($ | \&)

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

In this case, $id_field is 'subgroup_id' and $alias is 'group', which
makes 'subgroup_id_group'.

You can sometimes use this to your advantage but it often makes for
some awkward naming schemes. Fortunately, you can use another means of
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
get overwritten. (In this case, you need to ensure that 'subgroup()'
is not a subroutine name in an external code class you are using.)

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

=head1 NOTES

B<Subroutine 'id' may need to be overridden>

Some SPOPS subclasses may need to calculate the ID for a given object
differently than others. In this case you will need to override the ID
method, and the best place to do this is usually the implementation
subclass.

For instance, L<SPOPS::GDBM> overrides the C<id()> method since there
is no concept of an 'id_field' in the implementation. In its
C<class_initialize()> method, it installs its own C<id()> method to
each class that uses it:

    # Turn off warnings in this block so we don't get the 'subroutine
    # id redefined' message (yes, we know what we're doing)
    {
        no strict 'refs';
        local $^W = 0;
        *{ $class . '::id' } = \&id;
    }

Easy! You could also more elegantly just remove the subroutine from
the symbol table and rely on inheritance. But I could not find a way
to do that and none of the (to me) intuitive ways to do it
worked. Hints welcome.

=head1 BUGS

None known (beyond being a little confusing in places).

=head1 SEE ALSO

L<SPOPS::Configure::Ruleset>

See also the appropriate child class for information specific to that
implementation. For instance, if you are using L<SPOPS::DBI>, see the
L<SPOPS::Configure::DBI> for additional configuration information.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

See the L<SPOPS> module for the full author list.

=cut
