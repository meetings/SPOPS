package SPOPS::Configure::Ruleset;

# $Header: /usr/local/cvsdocs/SPOPS/SPOPS/Configure/Ruleset.pm,v 1.7 2000/10/27 04:05:45 cwinters Exp $

use strict;

@SPOPS::Configure::Ruleset::ISA     = ();
$SPOPS::Configure::Ruleset::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use constant DEBUG => 0;

# EVAL'ABLE PACKAGE/SUBROUTINES
my $generic_ruleset_template = <<'RULESET';

       $%%CLASS%%::RULESET = {};
       sub %%CLASS%%::RULESET { return $%%CLASS%%::RULESET; }

RULESET

sub create_relationship {
 my $class = shift;
 my $info     = shift;
 my $this_class = $info->{class};
 warn " (Ruleset/create_relationship): Parsing alias/class: $this_class\n" if ( DEBUG );

 # Install the variable/subroutine RULESET into the class
 my $ruleset_info = $generic_ruleset_template;
 $ruleset_info =~ s/%%CLASS%%/$this_class/g;
 eval $ruleset_info;
 die " Could not eval ruleset info into $this_class: $@"  if ( $@ );

 # Process the rulesets -- note that each ruleset should also 
 # call SUPER::... so all of the sets can be set; we also
 # pass around the hashref resulting from the RULESET call
 # so each subroutine can put its rules directly into the 
 # variable
 
 # Something to add -- we really must allow a SPOPS class to
 # define its own behaviors; however, if we simply call 'can',
 # we may wind up with the information from a parent.
   
 # Another idea how to handle this is to simply establish a 
 # policy whereby a class must fill its own ruleset using
 # its _class_initialize procedure. There's an inheritance issue
 # there (what if the _class_initialize is inherited as well?),
 # but we can cross that bridge when we come to it.     
 {
   no strict 'refs';
   foreach my $parent_class ( @{ $this_class . '::ISA' } ) {
     if ( my $rs_sub = $parent_class->can( 'ruleset_add' ) ) {
       $rs_sub->( $this_class, $this_class->RULESET );
       warn " (Ruleset/create_relationship): Adding routine from ($parent_class)\n" if ( DEBUG );
     }
   }
 }
return 1;
}

1;

__END__

=pod

=head1 NAME

SPOPS::Configure::Ruleset - Install variables, subroutines and process
inherited rulesets per class

=head1 SYNOPSIS

 # Note that this is almost (entirely?) exclusively done
 # from SPOPS::Configure
 SPOPS::Configure::Ruleset->create_relationship( $spops_config );

=head1 DESCRIPTION

This class only has one method: create_relationship. It is almost
always called from the L<SPOPS::Configure> class after doing intitial
processing of classes. The method takes configuration information for
a SPOPS class.

For this class, we install a package variable \%RULESET and a method
RULESET which returns that hashref. The variable \%RULESET holds all
of the applicable rules for that particular class, and after creating
the variable and subroutine we find all of the rules inherited by the
class and install them in the class. This is a performance win, since
we do not need to dynamically search them out everytime the rules for
a particular action need to be executed.

See L<SPOPS> for more information about what a ruleset is and how it
is executed.

=head1 METHODS

B<create_relationship( \%spops_config )>

Install the package variable \%RULESET and the method RULESET to
access it. Also find all the rules that apply to a particular class
(inherited from parents) and install to the class.

=head1 TO DO

=head1 BUGS

=head1 COPYRIGHT

Copyright (c) 2000 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <cwinters@intes.net>


=cut

