package SPOPS::ClassFactory::DefaultBehavior;

# $Id: DefaultBehavior.pm,v 3.3 2003/01/02 06:00:24 lachoy Exp $

use strict;
use SPOPS               qw( _w DEBUG );
use SPOPS::ClassFactory qw( OK DONE ERROR RULESET_METHOD );

$SPOPS::ClassFactory::DefaultBehavior::VERSION   = sprintf("%d.%02d", q$Revision: 3.3 $ =~ /(\d+)\.(\d+)/);

my @PARSE_INTO_HASH = qw( field no_insert no_update skip_undef multivalue );

# NOTE: These behaviors are called from SPOPS.pm, although they can be
# theoretically called from anywhere.

########################################
# BEHAVIOR: manipulate_configuration
########################################

sub conf_modify_config {
    my ( $class ) = @_;

    DEBUG() && _w( 1, "Trying to modify configuration for class [$class]" );
    my $CONFIG = $class->CONFIG;

    if ( ref $CONFIG->{field} eq 'ARRAY' ) {
        $CONFIG->{field_list} = [ @{ $CONFIG->{field} } ];
    }

    # When we change a listref to a hashref, keep the order
    # by maintaining a count; that way they can be re-ordered
    # if desired.

    foreach my $item ( @PARSE_INTO_HASH ) {
        next unless ( ref $CONFIG->{ $item } eq 'ARRAY' );
        DEBUG() && _w( 1, "Parsing key ($item) into a hash" );
        my $count = 1;
        my %new = ();
        foreach my $subitem ( @{ $CONFIG->{ $item } } ) {
            $new{ $subitem } = $count;
            $count++;
        }
        $CONFIG->{ $item } = \%new;
    }
    return ( OK, undef );
}

########################################
# BEHAVIOR: id_method
########################################

my $ID_TEMPLATE = <<'IDTMPL';

       # Get the ID of this object, and optionally set it as well.

       sub %%CLASS%%::id {
          my ( $self, $new_id ) = @_;
          my $id_field = $self->id_field ||
                         SPOPS::Exception->throw(
                             "Cannot find ID for object since no ID ",
                             "field specified for class [",
                             "ref( $self ) . ']' " );
          return $self->{ $id_field } unless ( $new_id );
          return $self->{ $id_field } = $new_id;
       }

IDTMPL

# We return 'DONE' here because other behaviors shouldn't redefine

sub conf_id_method {
    my ( $class ) = @_;
    my $id_method = $ID_TEMPLATE;
    $id_method =~ s/%%CLASS%%/$class/g;
    DEBUG() && _w( 5, "ID method being created\n$id_method" );
    {
        local $SIG{__WARN__} = sub { return undef };
        eval $id_method;
        if ( $@ ) {
            return ( ERROR, "Cannot generate method 'id' in class " .
                            "[$class]. Error: $@" );
        }
    }
    return ( DONE, undef );
}


########################################
# BEHAVIOR: read_code
########################################

#
# Returns: arrayref of files used

sub conf_read_code {
    my ( $class ) = @_;

    my $CONFIG = $class->CONFIG;
    my $code_class = $CONFIG->{code_class};
    return ( OK, undef )  unless ( $code_class );

    my @files_used = ();
    $code_class = [ $code_class ] unless ( ref $code_class eq 'ARRAY' );
    foreach my $read_code_class ( @{ $code_class } ) {
        DEBUG() && _w( 2, "Trying to read code from [$read_code_class]",
                          "into [$class]" );
        my $filename = $read_code_class;
        $filename =~ s|::|/|g;
        my $final_filename = undef;

PREFIX:
        foreach my $prefix ( @INC ) {
            my $full_filename = "$prefix/$filename.pm";
            DEBUG() && _w( 3, "Try file: [$full_filename]" );
            if ( -f $full_filename ) {
                $final_filename = $full_filename;
                last PREFIX;
            }
        }

        unless ( $final_filename and -f $final_filename ) {
            return ( ERROR, "Class [$read_code_class] specified in " .
                            "'code_class' configuration defintion " .
                            "for class [$class] was not found in \@INC" );
        }

        DEBUG() && _w( 2, "File [$final_filename] will be used for ",
                          "[$read_code_class]" );

        eval { open( PKG, $final_filename ) || die $! };
        if ( $@ ) {
            return ( ERROR, "Cannot read [$final_filename] specified in " .
                            "'code_class' configuration definition for " .
                            "class [$class]. Error: $@" );
        }
        my $code_pkg = undef;
        push @files_used, $final_filename;

CODEPKG:
        while ( <PKG> ) {
            if ( s/^\s*package $read_code_class\s*;\s*$/package $class;/ ) {
                $code_pkg .= $_;
                DEBUG() && _w( 1, "Package [$read_code_class] will be ",
                                  "read in as [$class]" );
                last CODEPKG;
            }
            $code_pkg .= $_;
        }

        # Use a block here because we want the $/ setting to NOT be
        # localized in the while loop -- that would be bad, since the
        # 'package' substitution would never work after the first
        # one...

        {
            local $/ = undef;
            $code_pkg .= <PKG>;
        }
        close( PKG );
        DEBUG() && _w( 5, "Going to eval code:\n\n$code_pkg" );
        {
            local $SIG{__WARN__} = sub { return undef };
            eval $code_pkg;
            if ( $@ ) {
                return ( ERROR, "Error running 'eval' on code read from " .
                                "[$final_filename] as specified in " .
                                "'code_class' configuration defintion for " .
                                "class [$class]. Error: $@" );
            }
        }
    }
    return ( OK, undef );
}


########################################
# BEHAVIOR: has_a
########################################

# EVAL'ABLE PACKAGE/SUBROUTINES

my $GENERIC_HASA = <<'HASA';

       sub %%CLASS%%::%%HASA_ALIAS%% {
           my ( $self, $p ) = @_;
           return undef  unless ( $self->{%%HASA_ID_FIELD%%} );
           return %%HASA_CLASS%%->fetch( $self->{%%HASA_ID_FIELD%%}, $p );
       }

HASA


# First do the 'has_a' aliases; see POD documentation on this (below)

sub conf_relate_hasa {
    my ( $class ) = @_;
    my $CONFIG = $class->CONFIG;
    $CONFIG->{has_a} ||= {};
    foreach my $hasa_class ( keys %{ $CONFIG->{has_a} } ) {
        DEBUG() && _w( 1, "Try to alias [$class] hasa [$hasa_class]" );
        my $hasa_config   = $hasa_class->CONFIG;
        my $hasa_id_field = $hasa_config->{id_field};
        my $hasa_sub = $GENERIC_HASA;
        $hasa_sub =~ s/%%CLASS%%/$class/g;
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

        my $id_fields = ( ref $CONFIG->{has_a}{ $hasa_class } eq 'ARRAY' )
                        ? $CONFIG->{has_a}{ $hasa_class }
                        : [ $CONFIG->{has_a}{ $hasa_class } ];
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
            DEBUG() && _w( 2, "Aliasing [$hasa_class] with field [$usea_id_field] ",
                              "using alias [$hasa_alias] within [$class]" );
            DEBUG() && _w( 5, "Now going to eval the routine:\n$this_hasa_sub" );
            {
                local $SIG{__WARN__} = sub { return undef };
                eval $this_hasa_sub;
                if ( $@ ) {
                    return ( ERROR, "Error reading 'has_a' code for alias " .
                                    "[$hasa_alias] mapped to class " .
                                    "[$hasa_class] into [$class]. Error: $@\n" );
                }
            }
        }
    }
    return ( OK, undef );
}


########################################
# BEHAVIOR: fetch_by
########################################

my $GENERIC_FETCH_BY = <<'FETCHBY';

       sub %%CLASS%%::fetch_by_%%FETCH_BY_FIELD%% {
           my ( $item, $fb_field_value, $p ) = @_;
           $p ||= {};
           my $obj_list = $item->fetch_group({ where => "%%FETCH_BY_FIELD%% = ?",
                                               value => [ $fb_field_value ],
                                               %{ $p } });
           if ( $p->{return_single} ) {
               return $obj_list->[0];
           }
           return $obj_list;
       }

FETCHBY

# Next, process the 'fetch_by' fields

sub conf_relate_fetchby {
    my ( $class ) = @_;
    my $CONFIG = $class->CONFIG;
    $CONFIG->{fetch_by} ||= [];
    foreach my $fetch_by_field ( @{ $CONFIG->{fetch_by} } ) {
        my $fetch_by_sub = $GENERIC_FETCH_BY;
        $fetch_by_sub    =~ s/%%CLASS%%/$class/g;
        $fetch_by_sub    =~ s/%%FETCH_BY_FIELD%%/$fetch_by_field/g;
        DEBUG() && _w( 2, "Creating fetch_by for field ($fetch_by_field)" );
        DEBUG() && _w( 5, "Now going to eval the routine:\n$fetch_by_sub" );
        {
            local $SIG{__WARN__} = sub { return undef };
            eval $fetch_by_sub;
            if ( $@ ) {
                return ( ERROR, "Cannot eval 'fetch_by' code for field " .
                                "[$fetch_by_field] into [$class]. Error: $@" );
            }
        }
    }
    return ( OK, undef );
}


########################################
# BEHAVIOR: add_rule
########################################

my $GENERIC_RULESET_REFER = <<'RULESET';

       $%%CLASS%%::RULESET = {};
       sub %%CLASS%%::RULESET { return $%%CLASS%%::RULESET }

RULESET

sub conf_add_rules {
    my ( $class ) = @_;
    my $CONFIG = $class->CONFIG;
    DEBUG() && _w( 1, "Adding rules to ($class)" );

    # Install the variable/subroutine RULESET into the class

    my $ruleset_info = $GENERIC_RULESET_REFER;
    $ruleset_info   =~ s/%%CLASS%%/$class/g;

    {
        no warnings 'redefine';
        eval $ruleset_info;
        if ( $@ ) {
            return ( ERROR, "Could not eval ruleset info into [$class]. Error: $@" );
        }
    }

    # Now find all the classes that have the method RULESET_METHOD
    # (and 'ruleset_add' for backwards compatibility)

    my $rule_classes = $CONFIG->{rules_from} || [];
    my $subs = SPOPS::ClassFactory->find_parent_methods( $class, $rule_classes, RULESET_METHOD, 'ruleset_add' );
    foreach my $sub_info ( @{ $subs } ) {
        DEBUG() && _w( 2, "Calling ruleset generation for [$class] ",
                          "from [$sub_info->[0]]" );
        $sub_info->[1]->( $class, $class->RULESET );
    }
    return ( OK, undef );
}


1;

__END__

=head1 NAME

SPOPS::ClassFactory::DefaultBehavior - Default configuration methods called from SPOPS.pm

=head1 SYNOPSIS

No synopsis.

=head1 DESCRIPTION

This class has default behaviors for all SPOPS classes. They may or
may not be used, depending on what subclasses do.

=head1 METHODS

Note: Even though the first parameter for all behaviors is C<$class>,
they are not class methods. The parameter refers to the class into
which the behaviors will be installed.

B<conf_modify_config( \%config )>

Set the values from 'field' into 'field_list', and parse the following
entries from arrayrefs into hashrefs:

 field, no_insert, no_update, skip_undef, multivalue

B<conf_id_method( \%config )>

Generate the C<id()> method.

B<conf_read_code( \%config )>

Reads the entries from C<code_class>, finds them from C<@INC> and
includes the libraries into the generated package. The value for
C<code_class> can be a scalar or arrayref.

Example:

 code_class => [ 'My::OtherBehavior', 'My::Neato' ],

B<conf_relate_hasa( \%config )>

Generate any methods used for relating an object to an object it
contains. (See
L<SPOPS::Manual::Relationships|SPOPS::Manual::Relationships> for more
information.)

B<conf_relate_fetchby( \%config )>

Generate a method C<fetch_by_$fieldname> for each entry listed in the
configuration key 'fetch_by'. The generated method takes a value to
search in C<$fieldname>.

Example:

 fetch_by => [ 'last_name' ],

would generate a method with the signature:

 sub fetch_by_last_name( $class, $last_name, \%params );

B<conf_add_rules( \%config )>

Adds the rules listed in 'rules_from' and from all entries in the
C<@ISA> of the class.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::ClassFactory|SPOPS::ClassFactory>

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
