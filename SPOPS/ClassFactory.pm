package SPOPS::ClassFactory;

# $Id: ClassFactory.pm,v 1.8 2001/08/22 11:10:04 lachoy Exp $

use strict;
use Class::ISA;
use Data::Dumper  qw( Dumper );
use SPOPS         qw( _w DEBUG );
require Exporter;

@SPOPS::ClassFactory::ISA       = qw( Exporter );
$SPOPS::ClassFactory::VERSION   = '1.8';
$SPOPS::ClassFactory::Revision  = substr(q$Revision: 1.8 $, 10);
@SPOPS::ClassFactory::EXPORT_OK = qw( OK DONE ERROR RESTART FACTORY_METHOD RULESET_METHOD );

use constant OK             => 'OK';
use constant DONE           => 'DONE';
use constant ERROR          => 'ERROR';
use constant RESTART        => 'RESTART';
use constant FACTORY_METHOD => 'behavior_factory';
use constant RULESET_METHOD => 'ruleset_factory';

my $PK = '__private__'; # Save typing...

# TODO: Export constants with the names of these slots -- the order
# doesn't matter to anyone except us, so we shouldn't need to export
# order and be able to keep the variable a lexical

my @SLOTS = qw(
    manipulate_configuration
    id_method
    read_code
    fetch_by
    has_a
    links_to
    add_rule
);

my %SLOTS = map { $SLOTS[ $_ ] => $_ } ( 0 .. ( scalar @SLOTS - 1 ) );


########################################
# MAIN INTERFACE
########################################

# TODO: Will $config ever be an object? Also, is 'create' the best
# name?

sub create {
    my ( $class, $all_config, $p ) = @_;
    return [] unless ( ref $all_config eq 'HASH' );
    $p ||= {};

    $class->create_all_stubs( $all_config, $p );
    $class->find_all_behavior( $all_config, $p );
    $class->exec_all_behavior( $all_config, $p );
    $class->clean_all_behavior( $all_config, $p );

    my $alias_list = $class->get_alias_list( $all_config, $p );
    return [ map { $all_config->{ $_ }->{class} }
                 grep { defined $all_config->{ $_ }->{class} }
                      @{ $alias_list } ];
}


########################################
# MULTI-CONFIG METHODS
########################################

# These methods operate on $all_config, a hashref of SPOPS
# configuration hashrefs


# First, we need to create the class so we can have an inheritance
# tree to walk -- think of this as the ur-behavior, or the beginning
# of the chicken-and-egg, or...

sub create_all_stubs {
    my ( $class, $all_config, $p ) = @_;
    my $alias_list = $class->get_alias_list( $all_config, $p );
    foreach my $alias ( @{ $alias_list } ) {
        my $this_class = $all_config->{ $alias }{class};
        $all_config->{ $alias }->{main_alias} ||= $alias;
        my ( $status, $msg ) = $class->create_stub( $all_config->{ $alias } );
        die $msg     if ( $status eq ERROR );
        my ( $cfg_status, $cfg_msg ) = $class->install_configuration( $this_class, $all_config->{ $alias } );
        die $cfg_msg if ( $cfg_status eq ERROR );
    }
}


# Now that the class is created with at least @ISA defined, we can
# walk through @ISA for each class and install all the behaviors

sub find_all_behavior {
    my ( $class, $all_config, $p ) = @_;
    my $alias_list = $class->get_alias_list( $all_config, $p );
    foreach my $alias ( @{ $alias_list } ) {
        my $this_class = $all_config->{ $alias }{class};
        my $this_config = $this_class->CONFIG;
        $this_config->{ $PK }{behavior_table} = {};
        $this_config->{ $PK }{behavior_run}   = {};
        $this_config->{ $PK }{behavior_map}   = $class->find_behavior( $this_class );
    }
}


# Now execute the behavior for each slot-and-alias. Note that we
# cannot do this in reverse order (alias-and-slot) because some later
# slots (particularly the relationship ones) may depend on earlier
# slots being executed for other classes.

sub exec_all_behavior {
    my ( $class, $all_config, $p ) = @_;
    my $alias_list = $class->get_alias_list( $all_config, $p );
    foreach my $slot_name ( @SLOTS ) {
        foreach my $alias ( @{ $alias_list } ) {
            my $this_class = $all_config->{ $alias }{class};
            $class->exec_behavior( $slot_name, $this_class );
        }
    }
}


# Remove all evidence of behaviors, tracking, etc. -- nobody should
# need this information once the class has been created.

sub clean_all_behavior {
    my ( $class, $all_config, $p ) = @_;
    my $alias_list = $class->get_alias_list( $all_config, $p );
    foreach my $alias ( @{ $alias_list } ) {
        my $this_class = $all_config->{ $alias }{class};
        delete $this_class->CONFIG->{ $PK };
    }
}


########################################
# CREATE CLASS
########################################

# EVAL'ABLE PACKAGE/SUBROUTINES

# Here's our template for a module on the fly. Super easy.

my $GENERIC_TEMPLATE = <<'PACKAGE';
       @%%CLASS%%::ISA     = qw( %%ISA%% );
       $%%CLASS%%::C       = {};
       sub %%CLASS%%::CONFIG  { return $%%CLASS%%::C; }
PACKAGE

sub create_stub {
    my ( $class, $config ) = @_;

    my $this_class = $config->{class};
    DEBUG() && _w( 1, "Creating stub ($this_class) with main alias ($config->{main_alias})");

    # Create the barest information forming the class; just substitute our
    # keywords (currently only the class name) for the items in the
    # generic template above.

    DEBUG() && _w( 1, "Creating $this_class on-the-fly." );
    my $module      = $GENERIC_TEMPLATE;
    $module        =~ s/%%CLASS%%/$this_class/g;
    my $isa_listing = join( ' ', @{ $config->{isa} } );
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
            return ( ERROR, "Error creating stub class: $@ with code\n" . $module );
        }
    }
    return $class->require_isa( $config );
}


# Just step through @{ $config->{isa} } and 'require' each entry

sub require_isa {
    my ( $class, $config ) = @_;
    my $this_class = $config->{class};
    foreach my $isa_class ( @{ $config->{isa} } ) {
        eval "require $isa_class";
        if ( $@ ) {
            return ( ERROR, "Error requiring class ($isa_class) from ISA in ($this_class): $@" );
        }
        DEBUG() && _w( 1, "Class ($isa_class) require'd ok." );
    }
    return ( OK, undef );
}


########################################
# INSTALL CONFIGURATION
########################################

# Just take the config from the $all_config (or wherever) and install
# it to the class -- we aren't doing any manipulation or anything,
# just copying over the original config key by key. Manipulation comes later.

sub install_configuration {
    my ( $class, $this_class, $config ) = @_;
    DEBUG() && _w( 3, "Installing configuration to class ($this_class)\n",
                      Dumper( $config ) );
    my $class_config = $this_class->CONFIG;
    while ( my ( $k, $v ) = each %{ $config } ) {
        $class_config->{ $k } = $v;
    }
    return ( OK, undef );
}


########################################
# FIND BEHAVIOR
########################################

# Find all the factory method-generators in all members of a class's
# ISA, then run each of the generators and keep track of the slots
# each generator uses (behavior map)

sub find_behavior {
    my ( $class, $this_class ) = @_;
    my $subs = $class->find_parent_methods( $this_class, FACTORY_METHOD );
    my $this_config = $this_class->CONFIG;
    my %behavior_map = ();
    foreach my $sub_info ( @{ $subs } ) {
        my $behavior_gen_class = $sub_info->[0];
        my $behavior_gen_sub   = $sub_info->[1];
        next if ( defined $behavior_map{ $behavior_gen_class } );

        # Execute the behavior factory and map the returned
        # information (slot => coderef or slot => \@( coderef )) into
        # the class config.

        my $behaviors = $behavior_gen_sub->( $this_class ) || {};
        DEBUG() && _w( 1, "Behaviors returned: ", join( ', ', keys %{ $behaviors } ) );
        foreach my $slot_name ( keys %{ $behaviors } ) {
            my $typeof = ref $behaviors->{ $slot_name };
            next unless ( $typeof eq 'CODE' or $typeof eq' ARRAY' );
            DEBUG() && _w( 1, "Adding slot behaviors for ($slot_name)" );
            if ( $typeof eq 'CODE' ) {
                push @{ $this_config->{ $PK }{behavior_table}{ $slot_name } }, $behaviors->{ $slot_name };
            }
            elsif ( $typeof eq 'ARRAY' ) {
                next unless ( scalar @{ $behaviors->{ $slot_name } } );
                push @{ $this_config->{ $PK }{behavior_table}{ $slot_name } }, @{ $behaviors->{ $slot_name } };
            }
            $behavior_map{ $behavior_gen_class }->{ $slot_name }++;
        }
    }
    return \%behavior_map;
}


# Find all instances of method $method supported by classes in the ISA
# of $class. Hooray for Class::ISA!

sub find_parent_methods {
    my ( $class, $this_class, @method_list ) = @_;
    my @isa_classes = Class::ISA::self_and_super_path( $this_class );
    my @subs = ();
    foreach my $isa_class ( @isa_classes ) {
        no strict 'refs';
        my $src = \%{ $isa_class . '::' };
METHOD:
        foreach my $method ( @method_list ) {
            if ( defined( $src->{ $method } ) and
                 defined( my $sub = *{ $src->{ $method } }{CODE} ) ) {
                push @subs, [ $isa_class, $sub ];
                DEBUG() && _w( 1, "($this_class): Found ($method) in class ($isa_class)\n" );
                last METHOD;
            }
        }
    }
    return \@subs;
}


########################################
# EXECUTE BEHAVIOR
########################################


# Execute behavior rules for a particular SPOPS class and slot configuration

sub exec_behavior {
    my ( $class, $slot_name, $this_class ) = @_;
    my $this_config = $this_class->CONFIG;
    my $behavior_list = $this_config->{ $PK }{behavior_table}{ $slot_name };

    # No behaviors to execute, all done with this slot

    return 1 unless ( ref $behavior_list eq 'ARRAY' and scalar @{ $behavior_list } );
    DEBUG() && _w( 1, "Behaviors in ($this_class)($slot_name): ", scalar @{ $behavior_list } );

    # Cycle through the behaviors for this slot. Note that they are
    # currently unordered -- that is, the order shouldn't
    # matter. (Whether this is true remains to be seen...)

BEHAVIOR:
    foreach my $behavior ( @{ $behavior_list } ) {

        DEBUG() && _w( 1, "Running behavior for slot ($slot_name) and class ($this_class)" );

        # If this behavior has already been run, then skip it. This
        # becomes relevant when we get a RESTART status from one of
        # the behaviors (below)

        if ( $this_config->{ $PK }{behavior_run}{ $behavior } ) {
            DEBUG() && _w( 1, "Skipping behavior, already run." );
            next BEHAVIOR;
        }
        # Every behavior should return a two-element list with the
        # status and (potentially empty) message

        my ( $status, $msg ) = $behavior->( $this_class );
        DEBUG() && _w( 1, "Status returned from behavior: ($status)" );

        if ( $status eq ERROR ) {
            die "Error running behavior for $slot_name in $this_class: $msg\n";
        }

        # If anything but an error, go ahead and mark this behavior as
        # run. Note that we rely on coderefs always stringifying to
        # the same memory location.

        $this_config->{ $PK }{behavior_run}{ $behavior }++;

        # A 'DONE' means the behavior has decreed that no more
        # processing should be done in this slot

        return 1       if ( $status eq DONE );

        # An 'OK' is normal -- either the behavior declined to do
        # anything or did what it was supposed to do without issue

        next BEHAVIOR  if ( $status eq OK );

        # RESTART is a little tricky. A 'RESTART' means that we need
        # to re-check this class for new behaviors. If we don't find
        # any new ones, no problem. If we do find new ones, then we
        # need to then re-run all behavior slots before this one. Note
        # that we will *NOT* re-run behaviors that have already been
        # run -- we're tracking them.

        if ( $status eq RESTART ) {
            my $new_behavior_map = $class->find_behavior( $this_class );
            my $behaviors_same   = $class->compare_behavior_map( $new_behavior_map,
                                                                 $this_config->{ $PK }{behavior_map} );
            next BEHAVIOR if ( $behaviors_same );
            $this_config->{ $PK }{behavior_map} = $new_behavior_map;
            for ( my $i = 0; $i <= $SLOTS{ $slot_name }; $i++ ) {
                $class->exec_behavior( $SLOTS[ $i ], $this_class );
            }
        }
    }
    return 1;
}


# Return false if the two behavior maps don't compare (in both
# directions), true if they do

sub compare_behavior_map {
    my ( $class, $b1, $b2 ) = @_;
    return undef unless ( $class->_compare_behaviors( $b1, $b2 ) );
    return undef unless ( $class->_compare_behaviors( $b2, $b1 ) );
    return 1;
}

# Return false if all classes and slot names of behavior-1 are not in
# behavior-2

sub _compare_behaviors {
    my ( $class, $b1, $b2 ) = @_;
    return undef unless ( ref $b1 eq 'HASH' and ref $b2 eq 'HASH' );
    foreach my $b1_class ( keys %{ $b1 } ) {
        return undef unless ( $b2->{ $b1_class } );
        next if ( ! $b1->{ $b1_class } and ! $b2->{ $b1_class } );
        return undef if ( ref $b1->{ $b1_class } ne 'HASH' or ref $b2->{ $b1_class } ne 'HASH' );
        foreach my $b1_slot_name ( keys %{ $b1->{ $b1_class } } ) {
            return undef unless ( $b2->{ $b1_class }{ $b1_slot_name } );
        }
    }
    return 1;
}


########################################
# UTILITY METHODS
########################################

sub get_alias_list {
    my ( $class, $all_config, $p ) = @_;
    return [ grep ! /^_/,
                  ( ref $p->{alias_list} eq 'ARRAY' and scalar @{ $p->{alias_list} } )
                    ? @{ $p->{alias_list} }
                    : keys %{ $all_config } ];
}

1;

__END__

=pod

=head1 NAME

SPOPS::ClassFactory - Create SPOPS classes from configuration and code

=head1 SYNOPSIS

 # Using SPOPS::Initialize (recommended)

 my $config = { ... };
 SPOPS::Initialize->process({ config => $config });

 # Using SPOPS::ClassFactory

 my $config = {};
 my $classes_created = SPOPS::ClassFactory->create( $config );
 foreach my $class ( @{ $classes_created } ) {
     $class->class_initialize();
 }

=head1 DESCRIPTION

This class creates SPOPS classes. It replaces C<SPOPS::Configure> --
if you try to use C<SPOPS::Configure> you will (for the moment) get a
warning about using a deprecated interface and call this module, but
that will not last forever.

=head1 DISCUSSION

(This section will probably be removed or merged into others as the
behavior firms up.)

So with configuration, we would create a number of slots into which
classes could install behaviors. The slots might look something like:

 - manipulate_installed_configuration
 - id_method
 - read_code
 - fetch_by
 - has_a (relationship)
 - links_to (relationship)
 - add_rule

(These are not definite yet and will probably change with actual
usage.)

A class in the hierarchy for an object could install a behavior in
none or all of the slots. So for instance, C<SPOPS::Configure::DBI>
would go away and be replaced by a 'links_to' behavior being installed
by SPOPS::DBI.

Multiple behaviors can be installed in each slot. I am still a little
unclear about how things will be ordered -- I suspect that by doing a
depth-first inheritance walk we will be ok. The processing of each
slot can use a (slightly modified) 'Chain of Responsibility' pattern
-- a behavior can decide to perform or not perform any action and
continue (OK), to perform an action, to declare the slot finished
(DONE), to stop the process entirely (ERROR) or that the behavior has
made changes which necessitates refreshing the behavior listing
(RESTART)..

As a completely untested example of a behavior, say we wanted to
ensure that all of our objects are using a particular SPOPS::DBI
subclass:

   my $USE_CLASS = 'SPOPS::DBI::Pg';

   sub check_spops_subclass {
       my ( $config ) = @_;
       foreach ( @{ $config->{isa} } ) {
           s/^SPOPS::DBI::.*$/$USE_CLASS/;
       }
       return SPOPS::ClassFactory::OK;
   }

We would just put this method in a common parent to all our objects
and install the behavior in the 'manipulate_configuration' slot. When
the class is configured the rule would be executed and we would never
have to worry about our objects using the wrong DBI class again. (This
is common in OpenInteract when you install new packages and forget to
run 'oi_manage change_spops_driver'.)

I believe this would enable more focused and flexible behaviors. For
instance, we could create one 'links_to' behavior for DBI to handle
the current configuration style and another to handle the proposed
(and more robust) ESPOPS configuration style. The first could step
through the 'links_to' configuration items and process only those it
can, while the second could do the same.

We could also do wacky stuff, like install a 'read_code'
behavior to use LWP to grab a module and checksums off a code
repository somewhere. If the checksum and code match up, we can bring
the code into the SPOPS class.

This new scheme might sound more complicated, but I believe most of
the complicated stuff will be done behind the scenes. These behaviors
can be extremely simple and therefore easy to code and understand.

=head1 SLOTS

We use the term 'slots' to refer to the different steps we walk
through to create, configure and auto-generate methods for an SPOPS
class. Each 'slot' can have multiple behaviors attached to it, and the
behaviors can come from any of the classes in the @ISA for the
generated class.

Here are the current slots and a description of each. Note that they
might change -- in particular, the 'links_to' and 'has_a' slots might
be merged into a single 'relationship' slot.

=over 4

=item *

B<manipulate_configuration>: Modify the configuration as
necessary. SPOPS comes with one method to transform arrayrefs (for
easy typing) into hashref (for easy lookup). Other options might be to
set application-specific information accessible from all your objects,
futz around with the @ISA, etc.

=item *

B<id_method>: Very focused: generate an C<id( [ $new_id ] )>
method. SPOPS uses these to ensure it can get the crucial information
from every object -- class and ID -- without having to know what the
ID field is.

SPOPS comes with a default method for this that will probably work
fine for you -- see L<SPOPS::ClassFactory::DefaultBehavior>.

=item *

B<read_code>: Reads in code from another class to the class
being created/configured. SPOPS comes with a method to read the
value(s) from the configuration key 'code_class', find them along @INC
and read them in.

But you can perform any action you need here -- you could even issue a
SOAP request to read Perl code (along with checksums) off the net,
check the code then read it in.

=item *

B<fetch_by>: Process the 'fetch_by' configuration key. SPOPS comes
with autogenerated methods to do this, but you can modify it and
implement your own.

=item *

B<has_a>: Process the 'has_a' configuration key. Usually this is
implementation-specific and involves auto-generating methods. SPOPS
comes with a default for this, but an implementation class can elect
to not use it by returning the 'DONE' constant.

=item *

B<links_to>: Process the 'links_to' configuration key. Usually this is
implementation-specific and involves auto-generating methods.

=item *

B<add_rule>: You will probably never need to create a behavior here:
SPOPS has one that performs the same duties as
C<SPOPS::Configure::Ruleset> used to -- it scans the @ISA of a class,
finds the ruleset generation methods from all the parents and installs
these coderefs to the class.

=back

=head1 BEHAVIOR GENERATOR

The behavior generator is called 'behavior_factory' (the name can be
imported in the constant 'FACTORY_METHOD') and it takes a single
argument, the name of the class being generated. It should return a
hashref with the slot names as keys. A value should either be a
coderef (for a single behavior) or an arrayref of coderefs (for
multiple behaviors).

Here is an example, directly from from C<SPOPS>:

  sub behavior_factory {
      my ( $class ) = @_;
      require SPOPS::ClassFactory::DefaultBehavior;
      DEBUG() && _w( 1, "Installing SPOPS default behaviors for ($class)" );
      return { manipulate_configuration => \&SPOPS::ClassFactory::DefaultBehavior::conf_modify_config,
               read_code                => \&SPOPS::ClassFactory::DefaultBehavior::conf_read_code,
               id_method                => \&SPOPS::ClassFactory::DefaultBehavior::conf_id_method,
               has_a                    => \&SPOPS::ClassFactory::DefaultBehavior::conf_relate_hasa,
               fetch_by                 => \&SPOPS::ClassFactory::DefaultBehavior::conf_relate_fetchby,
               add_rule                 => \&SPOPS::ClassFactory::DefaultBehavior::conf_add_rules, };
  }

=head1 BEHAVIOR DESCRIPTION

Behaviors can be simple or complicated, depending on what you need
them to do. Here is an example of a behavior installed to the
'manipulate_configuration' slot:

   my $USE_CLASS = 'SPOPS::DBI::Pg';

   sub check_spops_subclass {
       my ( $class ) = @_;
       foreach ( @{ $class->CONFIG->{isa} } ) {
           s/^SPOPS::DBI::.*$/$USE_CLASS/;
       }
       return SPOPS::ClassFactory::OK;
   }

# NOTE: WE NEED TO DEAL WITH THIS ISA ISSUE SPECIFICALLY, SINCE YOU
# HAVE @ISA AND \@$class->CONFIG->{isa}. Do they get synchronized?

...

There can be a few wrinkles, although you will probably never
encounter any of them. One of the main ones is: what if a behavior
modifies the 'ISA' of a class?

=head1 METHODS

B<create( \%multiple_config, \%params )>

This is the main interface into the class factory, and generally the
only one you need. That said, most users will only ever require the
C<SPOPS::Initialize> window into this functionality.

Return value is an arrayref of classes created;

The first parameter is a series of SPOPS configurations, in the
format:

 { alias => { ... },
   alias => { ... },
   alias => { ... } }

The second parameter is a hashref of options. Currently there is only
one parameter supported, but the future could bring more options.

=over 4

=item *

B<alias_list> (\@) (optional)

List of aliases to process from C<\%multiple_config>. If not given we
simply read the keys of C<\%multiple_config> (screening out those that
begin with '_').

Use this if you only want to process a limited number of the SPOPS
class definitions available in C<\%multiple_config>.

=back

=head2 Multiple Configuration Methods

These methods are basically wrappers around the L<Individual
Configuration Methods> below, calling them once for each class to be
configured.

B<create_all_stubs( \%multiple_config, \%params )>

Creates all the necessary classes and installs the available
configuration to each class.

Calls C<create_stub()> and C<install_configuration()>.

B<find_all_behavior( \%multiple_config, \%params )>

Retrieves behavior routines from all necessary classes.

Calls C<find_behavior()>.

B<exec_all_behavior( \%multiple_config, \%params )>

Executes behavior routines in all necessary classes.

Calls C<exec_behavior()>

B<clean_all_behavior( \%multiple_config, \%params )>

Removes behavior routines and tracking information from the
configuration of all necessary classes.

Calls: nothing.

=head2 Individual Configuration Methods

B<find_behavior( $class )>

Find all the factory method-generators in all members of the
inheritance tree for an SPOPS class, then run each of the generators
and keep track of the slots each generator uses (behavior map).

Return value is the behavior map, a hashref with keys as class names
and values as arrayrefs of slot names. For instance:

 my $b_map = SPOPS::ClassFactory->find_behavior( 'My::SPOPS' );
 print "Behaviors retrieved for My::SPOPS\n";
 foreach my $class_name ( keys %{ $b_map } ) {
     print "  -- Retrieved from ($class_name): ", 
           join( ', ' @{ $b_map->{ $class_name } } ), "\n";
 }

B<exec_behavior( $slot_name, $class )>

Execute behavior rules in slot C<$slot_name> collected by
C<find_behavior()> for C<$class>.

Executing the behaviors in a slot succeeds if there are no behaviors
to execute or if all the behaviors execute without returning an
C<ERROR>.

If a behavior returns an C<ERROR>, the entire process is stopped and a
C<die> is thrown with the message returned from the behavior.

Return value: true if success, C<die>s on failure.

B<create_stub( \%config )>

Creates the class specified by C<\%config>, sets its C<@ISA> to what
is set in C<\%config> and ensures that all members of the C<@ISA> are
C<require>d.

Return value: same as any behavior (OK or ERROR plus message).

B<require_isa( \%config )>

Runs a 'require' on all members of the 'isa' key in C<\%config>.

Return value: same as a behavior (OK or ERROR plus message).

B<install_configuration( $class, \%config )>

Installs the configuration C<\%config> to the class C<$class>. This is
a simple copy and we do not do any transformation of the data.

Return value: same as a behavior (OK or ERROR plus message).

=head2 Utility Methods

B<get_alias_list( \%multiple_config, \%params )>

Looks at the 'alias_list' key in C<\%params> for an arrayref of
aliases; if it does not exist, pulls out the keys in
C<\%multiple_config> that do not begin with '_'.

Returns: arrayref of alias names.

B<find_parent_methods( $class, @method_list )>

Walks through the inheritance tree for C<$class> and finds all
instances of any member of C<@method_list>. The first match wins, and
only one match will be returned per class.

Returns: arrayref of two-element arrayrefs describing all the places
that $method_name can be executed in the inheritance tree; the first
item is the class name, the second a code reference.

Example:

 my $parent_info = SPOPS::ClassFactory->find_parent_methods(
                                'My::Class', 'method_factory', 'method_generate' );
 foreach my $method_info ( @{ $parent_info } ) {
     print "Class $method_info->[0] found sub which has the result: ",
           $method_info->[1]->(), "\n";
 }

B<compare_behavior_map( \%behavior_map, \%behavior_map )>

Returns 1 if the two are equivalent, 0 if not.

=head1 BUGS

B<New>

This is a very new process, so if you have problems (functionality or
backward compatibility) please contact the author or (preferably) the
mailing list 'openinteract-help@lists.sourceforge.net'.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
