package SPOPS::Key::UUID;

# $Id: UUID.pm,v 1.2 2002/01/02 02:37:02 lachoy Exp $

use strict;
use SPOPS      qw( _w DEBUG );

@SPOPS::Key::UUID::ISA      = ();
$SPOPS::Key::UUID::VERSION  = '0.10';
$SPOPS::Key::UUID::Revision = substr(q$Revision: 1.2 $, 10);

BEGIN { eval { require Data::UUID } }

my $GENERATOR = Data::UUID->new();

sub pre_fetch_id  {
    my ( $class, $p ) = @_;
    return $GENERATOR->create_str();
}

sub post_fetch_id { return undef }

1;

__END__

=pod

=head1 NAME

SPOPS::Key::UUID - Creates a Universally Unique ID (UUID) as a key

=head1 SYNOPSIS

 # In your SPOPS configuration

 $spops  = {
   'myspops' => {
       'isa'      => [ qw/ SPOPS::Key::UUID  SPOPS::DBI / ],
       ...
   },
 };

=head1 DESCRIPTION

Very, very simple. We just use the L<Data::UUID|Data::UUID> module to
create a unique key. The key is created before the object is inserted.

The docs for L<Data::UUID|Data::UUID> say that it can handle millions
of new keys per second, which should be enough for anything Perl is
running.

=head1 BUGS

Unclear whether L<Data::UUID|Data::UUID> works on Win32.

=head1 TO DO

Nothing known.

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
