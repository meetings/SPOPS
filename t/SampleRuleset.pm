package SampleRuleset;

# $Id: SampleRuleset.pm,v 1.2 2002/04/23 01:04:30 lachoy Exp $

use strict;

sub ruleset_factory {
    my ( $class, $ruleset ) = @_;
    push @{ $ruleset->{post_save_action} }, \&reset_id;
    return __PACKAGE__;
}

# Always rewrite the ID to 'blimey!'

sub reset_id {
    my ( $self ) = @_;
    my $id_field = $self->id_field;
    $self->{ $id_field } = "blimey!";
    return 1;
}

1;
