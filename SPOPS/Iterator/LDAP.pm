package SPOPS::Iterator::LDAP;

# $Id: LDAP.pm,v 1.7 2001/10/12 21:00:26 lachoy Exp $

use strict;
use SPOPS           qw( _w DEBUG );
use SPOPS::Iterator qw( ITER_IS_DONE ITER_FINISHED );
use SPOPS::Secure   qw( :level );

@SPOPS::Iterator::LDAP::ISA = qw( SPOPS::Iterator );
$SPOPS::Iterator::LDAP::VERSION  = '1.90';
$SPOPS::Iterator::LDAP::Revision = substr(q$Revision: 1.7 $, 10);

# Keys with _LDAP at the beginning are specific to this implementation;
# keys without _LDAP at the begining are used in all iterators.

sub initialize {
    my ( $self, $p ) = @_;
    $self->{_LDAP_MSG}       = $p->{ldap_msg};
    $self->{_LDAP_OFFSET}    = $p->{offset};
    $self->{_LDAP_MAX}       = $p->{max};
    $self->{_LDAP_ID_LIST}   = $p->{id_list};
    $self->{_LDAP_COUNT}     = 1;
    $self->{_LDAP_RAW_COUNT} = 0;
}


# TODO [fetch_object]: Put the pre_fetch_action in here for when we
# don't have _LDAP_ID_LIST

sub fetch_object {
    my ( $self ) = @_;

    # First either grab the row with the ID if we've already got it or
    # kick the DBI statement handle for the next row

    my ( $obj );
    my $object_class = $self->{_CLASS};
    if ( $self->{_LDAP_ID_LIST} ) {
        my $id = $self->{_LDAP_ID_LIST}->[ $self->{_LDAP_RAW_COUNT} ];
        DEBUG() && _w( 1, "Trying to retrieve idx ($self->{_LDAP_RAW_COUNT}) with ",
                          "ID ($id) from class ($self->{_CLASS}" );
        $obj = eval { $object_class->fetch( $id,
                                            { skip_security => $self->{_SKIP_SECURITY} } ) };

        # If the object doesn't exist then it's likely a security issue,
        # in which case we bump up our internal count (but not the
        # position!) and try again.

        if ( $@ ) {
            $self->{_LDAP_RAW_COUNT}++;
            return $self->fetch_object;
        }

        unless( $obj ) {
            return ITER_IS_DONE;
        }

        if ( $self->{_LDAP_OFFSET} and 
             ( $self->{_LDAP_COUNT} < $self->{_LDAP_OFFSET} ) ) {
            $self->{_LDAP_COUNT}++;
            $self->{_LDAP_RAW_COUNT}++;
            return $self->fetch_object;
        }

    }
    else {
        my $entry = $self->{_LDAP_MSG}->shift_entry;
        unless ( $entry ) {
            return ITER_IS_DONE;
        }

        # It's ok to create the object now

        $obj = $object_class->new;
        $obj->_fetch_assign_row( undef, $entry );

        # Check security on the row unless overridden. If the security
        # check fails that's ok, just skip the row and move on -- DO
        # increase our internal index but DON'T increase the position.

        $obj->{tmp_security_level} = SEC_LEVEL_WRITE;
        unless ( $self->{_SKIP_SECURITY} ) {
            $obj->{tmp_security_level} = eval { $obj->check_action_security({
                                                   required => SEC_LEVEL_READ }) };
            if ( $@ ) {
                DEBUG() && _w( 1, "Security check for ($self->{_CLASS}) failed." );
                $self->{_LDAP_RAW_COUNT}++;
                return $self->fetch_object;
            }
        }

        # Now call the post_fetch callback; if it fails, fetch another row

        unless ( $obj->_fetch_post_process( {}, $obj->{tmp_security_level} ) ) {
            $self->{_LDAP_RAW_COUNT}++;
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

    if ( $self->{_LDAP_OFFSET} and 
         ( $self->{_LDAP_COUNT} < $self->{_LDAP_OFFSET} ) ) {
        $self->{_LDAP_COUNT}++;
        $self->{_LDAP_RAW_COUNT}++;
        return $self->fetch_object;
    }

    # Oops, we've gone past the max. Finish up.

    if ( $self->{_LDAP_MAX} and
         ( $self->{_LDAP_COUNT} > $self->{_LDAP_MAX} ) ) {
        return ITER_IS_DONE;
    }

    # Ok, we've navigated everything we need to, which means we can
    # actually return this record. So bump up both counts. Note that
    # we also use this count for the ID list.

    $self->{_LDAP_COUNT}++;
    $self->{_LDAP_RAW_COUNT}++;

    return ( $obj, $self->{_LDAP_COUNT} );
}


# Might need to wrap this in an eval

sub finish {
    my ( $self ) = @_;
    undef $self->{_LDAP_MSG};
    return $self->{ ITER_FINISHED() } = 1;
}

1;

__END__

=pod

=head1 NAME

SPOPS::Iterator::LDAP - Implementation of SPOPS::Iterator for SPOPS::LDAP

=head1 SYNOPSIS

  my $iter = My::SPOPS->fetch_iterator({ 
                             skip_security => 1,
                             filter => '&(objectclass=person)(mail=chris*)' });
  while ( my $person = $iter->get_next ) {
      print "Item ", $iter->position, ": $person->{first_name}: $person->{mail}",
            " (", $iter->is_first, ") (", $iter->is_last, ")\n";
  }

=head1 DESCRIPTION

This is an implementation of the C<SPOPS::Iterator> interface -- for
usage guidelines please see the documentation for that module. The
methods listed here are for SPOPS developers (versus SPOPS users).

=head1 METHODS

B<initialize()>

Store the L<Net::LDAP::Message|Net::LDAP::Message> object so we can
peel off one record at a time, along with the various other pieces of
information.

B<fetch_object()>

Peel off a record, see if it fits in our min/max requirements and if
this user can see it. If so return, otherwise try again.

B<finish()>

Just clear out the C<Net::LDAP::Message> object.

=head1 SEE ALSO

L<SPOPS::Iterator|SPOPS::Iterator>

L<SPOPS::LDAP|SPOPS::LDAP>

L<Net::LDAP|Net::LDAP>

=head1 COPYRIGHT

Copyright (c) 2001 Marketing Service Northwest, GmbH. All rights
reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut