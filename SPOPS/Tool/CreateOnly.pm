package SPOPS::Tool::CreateOnly;

# $Id: CreateOnly.pm,v 1.1 2002/05/08 03:42:01 lachoy Exp $

use strict;
use SPOPS               qw( _w DEBUG );
use SPOPS::ClassFactory qw( OK );

sub behavior_factory {
    my ( $class ) = @_;
    DEBUG && _w( 1, "Installing create-only persistence methods for [$class]" );
    return { read_code => \&generate_persistence_methods };
}

sub generate_persistence_methods {
    my ( $class ) = @_;
    DEBUG && _w( 1, "Generating create-only save() [$class]" );
    no strict 'refs';
    *{ "${class}::save" }   =
          sub {
              my ( $self, $params ) = @_;
              if ( $self->is_saved() ) {
                  warn "Objects in [", ref $self, "] can only be created, ",
                       "not updated. No changes made.\n";
                  return $self;
              }
              return $self->SUPER::save( $params );
          };
    return OK;
}

1;

__END__

=pod

=head1 NAME

SPOPS::Tool::CreateOnly - Make a particular object create-only -- it cannot be updated

=head1 SYNOPSIS

 # Load information with create-only rule

 my $spops = {
    class               => 'This::Class',
    isa                 => [ 'SPOPS::DBI' ],
    field               => [ 'email', 'language', 'country' ],
    id_field            => 'email',
    base_table          => 'test_table',
    rules_from          => [ 'SPOPS::Tool::CreateOnly' ],
 };
 SPOPS::Initialize->process({ config => { test => $spops } });

 # Fetch an object and try to modify it...
 my $object = This::Class->fetch( 'prez@whitehouse.gov' );
 $object->{country} = "Time/Warnerland";

 # Trying to save the object gives a warning:
 # "Objects in [This::Class] can only be inserted, not updated. No changes made"
 eval { $object->save };

 # Instantiate a new object and try to save it...
 my $new_object = This::Class->new({ email    => 'foo@bar.com',
                                     language => 'lv',
                                     country  => 'Freedonia' });
 eval { $new_object->save() }; # ...works as normal, object is saved. Hooray!

=head1 DESCRIPTION

This is a simple rule to ensure that calls to C<save()> on an
already-saved object do nothing. Calling C<save()> on a new (unsaved)
object works as normal. Thus, you have create-only objects.

=head1 METHODS

B<behavior_factory()>

Installs the behavior during the class generation process.

B<generate_persistence_methods()>

Generates a C<save()> method that issues a warning and a no-op when
called on a saved object.

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

