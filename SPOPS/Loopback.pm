package SPOPS::Loopback;

# $Id: Loopback.pm,v 3.5 2002/09/16 20:35:42 lachoy Exp $

use strict;
use base qw( SPOPS );
use Data::Dumper qw( Dumper );
use SPOPS::Secure qw( :level );

$SPOPS::Loopback::VERSION  = sprintf("%d.%02d", q$Revision: 3.5 $ =~ /(\d+)\.(\d+)/);

# Save objects here, indexed by ID.

my %BY_ID = ();

sub fetch {
    my ( $class, $id, $p ) = @_;
    return undef unless ( $class->pre_fetch_action( $id ) );
    my $level = SEC_LEVEL_WRITE;
    if ( ! $p->{skip_security} and $class->isa( 'SPOPS::Secure' ) ) {
        $level = $class->check_action_security({ id       => $id,
                                                 DEBUG    => $p->{DEBUG},
                                                 required => SEC_LEVEL_READ });
    }
    my $object = ( exists $BY_ID{ $class }->{ $id } )
                 ? $class->new( $BY_ID{ $class }->{ $id } )
                 : $_[0]->new({ id => $id });
    $object->{tmp_security_level} = $level;
    return undef unless ( $object->post_fetch_action );
    $object->has_save;
    $object->clear_change;
    return $object;
}


sub fetch_group {
    my ( $class, $params ) = @_;
    $params ||= {};
    my @id_list = ();
    if ( scalar keys %{ $BY_ID{ $class } } == 0 ) {
        @id_list = ( 1 .. 15 );
    }
    elsif ( $params->{where} ) {
        my ( $field, $value ) = split /\s*=\s*/, $params->{where};
        $value =~ s/[\'\"]//g;
        my $id_field = $class->id_field;
        foreach my $id ( sort keys %{ $BY_ID{ $class } } ) {
            my $data = $BY_ID{ $class }->{ $id };
            if ( exists $data->{ $field } and $data->{ $field } eq $value ) {
                push @id_list, $id;
            }
        }
    }
    else {
        @id_list = sort keys %{ $BY_ID{ $class } }
    }
    return [ map { $class->fetch( $_ ) } @id_list ];
}


sub fetch_iterator {
    my ( $class, $params ) = @_;
    my $items = $class->fetch_group( $params );
    require SPOPS::Iterator::WrapList;
    return SPOPS::Iterator::WrapList->new({ object_list => $items });
}


sub save {
    my ( $self, $p ) = @_;
    $p ||= {};
    unless ( $self->pre_save_action({ is_add => $self->is_saved }) ) {
        return undef;
    }
    if ( $self->is_saved ) {
        if ( ! $p->{skip_security} and $self->isa( 'SPOPS::Secure' ) ) {
            $self->check_action_security({ DEBUG    => $p->{DEBUG},
                                           required => SEC_LEVEL_WRITE });
        }
    }
    else {
        $self->id( $self->pre_fetch_id );
        $self->id( $self->post_fetch_id ) unless ( $self->id );
    }
    $BY_ID{ ref( $self ) }->{ $self->id } = $self->as_data_only;
    #warn "Saved new object: ", Dumper( $self ), "\n";
    unless ( $self->is_saved or $p->{skip_security} ) {
        #warn "Calling create_initial_security()\n";
        $self->create_initial_security;
    }
    return undef unless ( $self->post_save_action );
    $self->has_save;
    $self->clear_change;
    return $self;
}


sub remove {
    my ( $self ) = @_;
    return undef unless ( $self->pre_remove_action );
    delete $BY_ID{ ref( $self ) }->{ $self->id };
    return undef unless ( $self->post_remove_action );
    return 1
}


sub peek {
    my ( $class, $id, $field ) = @_;
    return undef unless ( exists $BY_ID{ $class }->{ $id } );
    return $BY_ID{ $class }->{ $id }{ $field }
}

1;

__END__

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
C<pre/post_fetch_action()> methods first. If the object has been
previously saved we pull it from the in-memory storage, otherwise we
return a new object initialized with C<$ID>.

B<fetch_group()>

Returns an arrayref of previously saved objects. If no objects have
been saved, it returns an arrayref of new objects initialized with
numeric IDs.

B<save()>

Returns the object you called the method on. If this is an unsaved
object (if it has not been fetched or saved previously), we call
C<pre_fetch_id()> and C<post_fetch_id()> to trigger any key-generation
actions.

Saved and unsaved objects both have C<pre/post_save_action()> methods
called.

This also stores the object in-memory so you can call C<fetch()> on it
later.

B<remove()>

Calls the C<pre/post_remove_action()> and removes the object from the
in-memory storage.

B<peek( $id, $field )>

Peeks into the in-memory store for the value of C<$field> for object
C<$id>. Must be called as class method.

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
