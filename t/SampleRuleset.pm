package SampleRuleset;

# $Id: SampleRuleset.pm,v 1.3 2002/08/21 14:36:01 lachoy Exp $

use strict;

sub ruleset_factory {
    my ( $class, $ruleset ) = @_;
    push @{ $ruleset->{post_save_action} }, \&reset_id;
    return __PACKAGE__;
}

# Always rewrite the ID to 'blimey!'

sub reset_id {
    my ( $self ) = @_;
    return 1 if ( $self->is_saved );
    my $id_field = $self->id_field;
    $self->{ $id_field } = "blimey!";
    return 1;
}

1;
