package SPOPS::Iterator::DBI;

# $Id: DBI.pm,v 1.3 2001/07/10 13:47:00 lachoy Exp $

use strict;
use SPOPS           qw( _w DEBUG );
use SPOPS::Iterator qw( ITER_IS_DONE ITER_FINISHED );
use SPOPS::Secure   qw( :level );

@SPOPS::Iterator::DBI::ISA = qw( SPOPS::Iterator );

# Keys with _DBI at the beginning are specific to this implementation;
# keys without _DBI at the begining are used in all iterators.

sub initialize {
    my ( $self, $p ) = @_;
    $self->{_DBI_STH}       = $p->{sth};
    $self->{_DBI_OFFSET}    = $p->{offset};
    $self->{_DBI_MAX}       = $p->{max};
    $self->{_DBI_ID_LIST}   = $p->{id_list};
    $self->{_DBI_COUNT}     = 0;
    $self->{_DBI_RAW_COUNT} = 0;
}


# TODO [fetch_object]: Put the pre_fetch_action in here for when we
# don't have _DBI_ID_LIST

sub fetch_object {
    my ( $self ) = @_;

    # First either grab the row with the ID if we've already got it or
    # kick the DBI statement handle for the next row

    my ( $obj );
    my $object_class = $self->{_CLASS};
    if ( $self->{_DBI_ID_LIST} ) {
        my $id = $self->{_DBI_ID_LIST}->[ $self->{_DBI_RAW_COUNT} ];
        DEBUG() && _w( 1, "Trying to retrieve idx ($self->{_DBI_RAW_COUNT}) with ",
                          "ID ($id) from class ($self->{_CLASS}" );
        $obj = eval { $object_class->fetch( $id, 
                                            { skip_security => $self->{_SKIP_SECURITY} } ) };

        # If the object doesn't exist then it's likely a security issue,
        # in which case we bump up our internal count (but not the
        # position!) and try again.

        if ( $@ ) {
            $self->{_DBI_RAW_COUNT}++;
            return $self->fetch_object;
        }

        unless( $obj ) {
            return ITER_IS_DONE;
        }

        if ( $self->{_DBI_OFFSET} and 
             ( $self->{_DBI_COUNT} < $self->{_DBI_OFFSET} ) ) {
            $self->{_DBI_COUNT}++;
            $self->{_DBI_RAW_COUNT}++;
            return $self->fetch_object;
        }

    }
    else {
        my $row = $self->{_DBI_STH}->fetchrow_arrayref;
        unless ( $row ) {
            return ITER_IS_DONE;
        }

        # It's ok to create the object now

        $obj = $object_class->new;
        $obj->_fetch_assign_row( $self->{_FIELDS}, $row );

        # Check security on the row unless overridden. If the security
        # check fails that's ok, just skip the row and move on -- DO
        # increase our internal index but DON'T increase the position.

        $obj->{tmp_security_level} = SEC_LEVEL_WRITE;
        unless ( $self->{_SKIP_SECURITY} ) {
            $obj->{tmp_security_level} = eval { $obj->check_action_security({
                                                   required => SEC_LEVEL_READ }) };
            if ( $@ ) {
                DEBUG() && _w( 1, "Security check for ($self->{_CLASS}) failed." );
                $self->{_DBI_RAW_COUNT}++;
                return $self->fetch_object;
            }
        }

        # Now call the post_fetch callback; if it fails, fetch another row

        unless ( $obj->_fetch_post_process( {}, $obj->{tmp_security_level} ) ) {
            $self->{_DBI_RAW_COUNT}++;
            return $self->fetch_object;
        }
    }

    # Not to the offset yet, so call ourselves again to go to the next
    # row but first bump up the count.

    # Note: this *does* need to be beneath the fetch and security stuff
    # above b/c the count refers to the records this user *could*
    # see. So if 25 records matched the criteria but the user couldn't
    # see 5 of them, we only want to the user to know and iterate
    # through 1-20, not know that we actually picked the records
    # 1-10,12,14,16-22,24-25 and discarded the others due to security.

    if ( $self->{_DBI_OFFSET} and 
         ( $self->{_DBI_COUNT} < $self->{_DBI_OFFSET} ) ) {
        $self->{_DBI_COUNT}++;
        $self->{_DBI_RAW_COUNT}++;
        return $self->fetch_object;
    }

    # Oops, we've gone past the max. Finish up.

    if ( $self->{_DBI_MAX} and
         ( $self->{_DBI_COUNT} > $self->{_DBI_MAX} ) ) {
        return ITER_IS_DONE;
    }

    # Ok, we've navigated everything we need to, which means we can
    # actually return this record. So bump up both counts. Note that
    # we also use this count for the ID list.

    $self->{_DBI_COUNT}++;
    $self->{_DBI_RAW_COUNT}++;

    return ( $obj, $self->{_DBI_COUNT} );
}


# Might need to wrap this in an eval

sub finish {
    my ( $self ) = @_;
    $self->{_DBI_STH}->finish()  if ( $self->{_DBI_STH} );
    return $self->{ ITER_FINISHED() } = 1;
}

1;

__END__

=pod

=head1 NAME

SPOPS::Iterator::DBI - Implementation of SPOPS::Iterator for SPOPS::DBI

=head1 SYNOPSIS

  my $iter = My::SPOPS->fetch_iterator({ 
                             skip_security => 1,
                             where => 'package = ?',
                             value => [ 'base_theme' ],
                             order => 'name' });
  while ( $iter->has_next ) {
      my $template = $iter->get_next;
      print "Item ", $iter->position, ": $template->{package} / $template->{name}";
      print " (", $iter->is_first, ") (", $iter->is_last, ")\n";
  }

=head1 DESCRIPTION

This is an implementation of the C<SPOPS::Iterator> interface -- for
usage guidelines please see the documentation for that module. The
methods documented here are for SPOPS developers (versus SPOPS users).

=head1 METHODS

B<initialize()>

B<fetch_object()>

B<finish()>

=head1 SEE ALSO

L<SPOPS::Iterator>, L<SPOPS::DBI>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
