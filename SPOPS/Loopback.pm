package SPOPS::Loopback;

# $Id: Loopback.pm,v 2.0 2002/03/19 04:00:00 lachoy Exp $

use strict;
use base qw( SPOPS );

$SPOPS::Loopback::VERSION  = substr(q$Revision: 2.0 $, 10);


sub fetch {
    my ( $class, $id ) = @_;
    return undef unless ( $class->pre_fetch_action( $id ) );
    my $object = $_[0]->new({ id => $id });
    return undef unless ( $object->post_fetch_action );
    $object->has_save;
    $object->clear_change;
    return $object;
}


sub fetch_group {
    my ( $class ) = @_;
    return [ map { $class->fetch( $_ ) } ( 1 .. 15 ) ];
}


sub save {
    my ( $self ) = @_;
    unless ( $self->pre_save_action({ is_add => $self->is_saved }) ) {
        return undef;
    }
    unless ( $self->is_saved ) {
        $self->id( $self->pre_fetch_id );
        $self->id( $self->post_fetch_id ) unless ( $self->id );
    }
    return undef unless ( $self->post_save_action );
    $self->has_save;
    $self->clear_change;
    return $self;
}


sub remove {
    my ( $self ) = @_;
    return undef unless ( $self->pre_remove_action );
    return undef unless ( $self->post_remove_action );
    return 1
}

1;

__END__

=pod

=head1 NAME

SPOPS::Loopback - Simple SPOPS class used for testing rules and other goodies

=head1 SYNOPSIS

    use SPOPS::Initialize;

    my %config = (
      test => {
         class    => 'LoopbackTest',
         isa      => [ qw( SPOPS::Loopback ) ],
         field    => [ qw( id_field field_name ) ],
         id_field => 'id_field',
      },
    );
    SPOPS::Initialize->process({ config => $config });
    my $object = LoopbackTest->new;
    $object->save;
    $object->remove;

=head1 DESCRIPTION

This is a simple SPOPS class that returns success for all
operations. The serialization methods (C<save()>, C<fetch()>,
C<fetch_group()> and C<remove()>) all call the pre/post action methods
just like any other objects, so it is useful for testing out rules.

=head1 METHODS

B<fetch( $id )>

Returns a new object initialized with the ID C<$id>, calling the
C<pre/post_fetch_action()> methods first.

B<fetch_group()>

Returns a list of new objects, initialized with IDs.

B<save()>

Returns the object you called the method on. If this is an unsaved
object (if it has not been fetched or saved previously), we call
C<pre_fetch_id()> and C<post_fetch_id()> to trigger any key-generation
actions.

Saved and unsaved objects both have C<pre/post_save_action()> methods
called.

B<remove()>

Calls the C<pre/post_remove_action()>

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS|SPOPS>

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
