package SPOPS::Configure::DBI;

# $Id: DBI.pm,v 1.14 2001/08/24 21:25:21 lachoy Exp $

use strict;
use SPOPS::Configure;

@SPOPS::Configure::DBI::ISA      = qw( SPOPS::Configure );
$SPOPS::Configure::DBI::VERSION  = '1.8';
$SPOPS::Configure::DBI::Revision = substr(q$Revision: 1.14 $, 10);

1;

=pod

=head1 NAME

SPOPS::Configure::DBI - DEPRECATED

=head1 SYNOPSIS

See L<SPOPS::ClassFactory>

=head1 DESCRIPTION

THIS CLASS IS DEPRECATED. As of SPOPS 0.50 it has been entirely
replaced by L<SPOPS::ClassFactory> and its behaviors -- see
L<SPOPS::ClassFactory::DBI> for replicated behaviors from
C<SPOPS::Configure::DBI>.

The main interface into this class (C<process_config()>) which was
inherited from C<SPOPS::Configure> is still inherited, but that method
simply forwards the call to L<SPOPS::ClassFactory>. In the near future
(probably as of SPOPS 0.60) all classes in the C<SPOPS::Configure>
tree will be removed entirely.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut

