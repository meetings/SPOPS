package SPOPS::Key::Random;

# $Id: Random.pm,v 1.16 2002/02/23 05:35:54 lachoy Exp $

use strict;
use SPOPS  qw( _w DEBUG );
use SPOPS::Utility;

$SPOPS::Key::Random::VERSION  = substr(q$Revision: 1.16 $, 10);

use constant DEFAULT_ID_WIDTH => 8;

sub pre_fetch_id  {
    my ( $class, $p ) = @_;
    my $width = $p->{id_width};
    unless ( $width ) {
        my $config = eval { $class->CONFIG };
        if ( ref $config ) {
            $width = $class->CONFIG->{id_width};
        }
        $width ||= DEFAULT_ID_WIDTH;
    }
    my $code =  SPOPS::Utility->generate_random_code( $width );
    DEBUG() && _w( 0, "Created insert ID [$code]" );
    return ( $code, 1 );
}

sub post_fetch_id { return undef }

1;

__END__

=pod

=head1 NAME

SPOPS::Key::Random - Creates a random alphanumeric code for the ID field

=head1 SYNOPSIS

 # In your SPOPS configuration

 $spops  = {
   'myspops' => {
       'isa'      => [ qw/ SPOPS::Key::Random  SPOPS::DBI / ],
       'id_width' => 12,
       ...
   },
 };

=head1 DESCRIPTION

Very, very simple. We just use the I<generate_random_code()> method
from L<SPOPS::Utility|SPOPS::Utility> to generate an n character
code. The width of the code is determined by the configuration key
C<id_width> in your object class, or we use a default width (eight
characters).

=head1 BUGS

B<Getting a 'random' value>

If you are using this under mod_perl, you might have the problem of
colliding ID fields. This seems to happen because the httpd children
all have the same random seed, since they are all forked off from the
same parent.

The solution is to put a 'srand()' in the PerlChildInitHandler,
although mod_perl versions greater than 1.25 are reported to take care
of this for you.

=head1 TO DO

Nothing known.

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
