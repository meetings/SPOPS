package My::ReadOnly;

# $Id: ReadOnly.pm,v 2.0 2002/03/19 04:00:06 lachoy Exp $

use strict;
use SPOPS               qw( _w DEBUG );
use SPOPS::ClassFactory qw( OK );

sub behavior_factory {
    my ( $class ) = @_;
    DEBUG && _w( 1, "Installing read-only persistence methods for ($class)" );
    return { read_code => \&generate_persistence_methods };
}

sub generate_persistence_methods {
    my ( $class ) = @_;
    DEBUG && _w( 1, "Generating read-only save() and remove() for ($class)" );
    no strict 'refs';
    *{ "${class}::save" }   = sub { warn ref $_[0], " is read-only; no changes allowed\n" };
    *{ "${class}::remove" } = sub { warn ref $_[0], " is read-only; no changes allowed\n" };
    return OK;
}

1;
