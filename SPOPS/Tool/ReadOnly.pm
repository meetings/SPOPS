package SPOPS::Tool::ReadOnly;

# $Id: ReadOnly.pm,v 1.1 2002/04/26 15:37:15 lachoy Exp $

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

__END__

=pod

=head1 NAME

SPOPS::Tool::ReadOnly - Make a particular object read-only

=head1 SYNOPSIS

 # Load information with read-only rule

 my $spops = {
    class               => 'This::Class',
    isa                 => [ 'SPOPS::DBI' ],
    field               => [ 'email', 'language', 'country' ],
    id_field            => 'email',
    base_table          => 'test_table',
    rules_from          => [ 'SPOPS::Tool::ReadOnly' ],
 };
 SPOPS::Initialize->process({ config => { test => $spops } });

 # Fetch an object, modify it... 
 my $object = This::Class->fetch( 45 );
 $object->{foo} = "modification";

 # Trying to save the object gives a warning:
 # "This::Class is read-only; no changes allowed"
 eval { $object->save };

=head1 DESCRIPTION

This is a simple rule to ensure that C<save()> and C<remove()> calls
to a particular class do not actually do any work. Instead they just
result in a warning that the class is read-only.

=head1 METHODS

B<behavior_factory()>

Installs the behavior during the class generation process.

B<generate_persistence_methods()>

Generates C<save()> and C<remove()> methods that just issue warnings.

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

Chris Winters <chris@cwinters.com>

=cut
