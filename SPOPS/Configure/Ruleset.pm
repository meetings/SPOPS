package SPOPS::Configure::Ruleset;

# $Id: Ruleset.pm,v 1.9 2001/07/08 21:12:02 lachoy Exp $

use strict;
use SPOPS qw( _w DEBUG );

@SPOPS::Configure::Ruleset::ISA      = ();
$SPOPS::Configure::Ruleset::VERSION  = '1.7';
$SPOPS::Configure::Ruleset::Revision = substr(q$Revision: 1.9 $, 10);

# EVAL'ABLE PACKAGE/SUBROUTINES

my $generic_ruleset_template = <<'RULESET';

       $%%CLASS%%::RULESET = {};
       sub %%CLASS%%::RULESET { return $%%CLASS%%::RULESET; }

RULESET

sub create_relationship {
    my ( $class, $info ) = @_;
    my $this_class = $info->{class};
    DEBUG() && _w( 1, "Parsing alias/class: $this_class" );

    # Install the variable/subroutine RULESET into the class

    my $ruleset_info = $generic_ruleset_template;
    $ruleset_info =~ s/%%CLASS%%/$this_class/g;
    eval $ruleset_info;
    die " Could not eval ruleset info into $this_class: $@"  if ( $@ );

    # Process the rulesets -- we pass around the hashref resulting from
    # the RULESET call so each subroutine can put its rules directly
    # into the variable

    my %classes_used = ();

    {
        no strict 'refs';

        # First see if we can add a ruleset implemented in the class
        # itself

        my $src = \%{ $this_class . '::' };
        my ( $base_sub );
        if ( defined( $src->{ruleset_add} ) and 
             defined( my $base_sub = *{ $src->{ruleset_add} }{CODE} ) ) {
            $base_sub->( $this_class, $this_class->RULESET );
            $classes_used{ $this_class }++;
        }

        # Now find all the rulesets in the classes for each
        # parent. Note that the 'ruleset_add' method should always
        # return the class that implemented it. This is so we ensure
        # that the same parent class doesn't get called more than
        # once.


PARENT:
        foreach my $parent_class ( @{ $this_class . '::ISA' } ) {
            if ( my $rs_sub = $parent_class->can( 'ruleset_add' ) ) {
                next PARENT if ( $classes_used{ $parent_class } );
                my $impl_class = $rs_sub->( $this_class, $this_class->RULESET );
                $classes_used{ $impl_class }++;
                DEBUG() && _w( 1, "Adding routine from ($impl_class) ",
                                   "using parent ($parent_class)" );
            }
        }
    }
    DEBUG() && _w( 1, "Finished adding rulesets" );
    return 1;
}

1;

__END__

=pod

=head1 NAME

SPOPS::Configure::Ruleset - Install variables, subroutines and process inherited rulesets per class

=head1 SYNOPSIS

 # Note that this is done from SPOPS::Configure and the
 # 'process_config()' method, or more easily from SPOPS::Initialize
 # and the 'process()' method

 SPOPS::Configure::Ruleset->create_relationship( $spops_config );

=head1 DESCRIPTION

This class only has one method: create_relationship. It is almost
always called from the L<SPOPS::Configure> class after doing intitial
processing of classes. The method takes configuration information for
a SPOPS class.

For this class, we install a package variable C<\%RULESET> and a
method C<RULESET()> which returns that hashref. The variable
C<\%RULESET> holds all of the applicable rules for that particular
class, and after creating the variable and subroutine we find all of
the rules inherited by the class and install them in the class. This
is a performance win, since we do not need to dynamically search them
out everytime the rules for a particular action need to be executed.

See L<SPOPS> for more information about what a ruleset is and how it
is executed.

=head1 METHODS

B<create_relationship( \%spops_config )>

Install the package variable C<\%RULESET> and the method C<RULESET()>
to access it. Also find all the rules that apply to a particular class
(inherited from parents) and install to the class.

=head1 TO DO

Nothing known.

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

See the L<SPOPS> module for the full author list.

=cut

