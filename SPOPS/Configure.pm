package SPOPS::Configure;

# $Id: Configure.pm,v 1.19 2001/10/12 21:00:26 lachoy Exp $

use strict;
use SPOPS::ClassFactory;

@SPOPS::Configure::ISA       = ();
$SPOPS::Configure::VERSION   = '1.90';
$SPOPS::Configure::Revision  = substr(q$Revision: 1.19 $, 10);

sub process_config {
    my ( $class, $p ) = @_;
    warn "WARNING -- DEPRECATED CLASS CALLED\n",
         "As of version 0.50, SPOPS::Configure (and all subclasses)\n",
         "have been replaced by SPOPS::ClassFactory. Your call is\n",
         "being forwarded, but you should replace the calling code ASAP\n",
         "because it won't work forever.\n";
    my $all_config = $p->{config};
    delete $p->{config};
    return SPOPS::ClassFactory->create( $all_config, $p );
}

1;

__END__

=pod

=head1 NAME

SPOPS::Configure - DEPRECATED

=head1 SYNOPSIS

See L<SPOPS::ClassFactory|SPOPS::ClassFactory>

=head1 DESCRIPTION

THIS CLASS IS DEPRECATED. As of SPOPS 0.50 it has been entirely
replaced by L<SPOPS::ClassFactory|SPOPS::ClassFactory>, and the main
interface into this class (C<process_config()>) simply forwards the
call. In the future the class will be removed entirely.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
