package SPOPS::Key::Random;

# $Id: Random.pm,v 1.3 2001/02/21 12:29:46 lachoy Exp $

use strict;
use SPOPS  qw( _w );

@SPOPS::Key::Random::ISA     = ();
$SPOPS::Key::Random::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use constant DEFAULT_WIDTH => 8;

sub pre_fetch_id  { 
  my ( $class, $p ) = @_;
  my $width = $p->{width} || $class->CONFIG->{id_width} || DEFAULT_WIDTH;
  my $code =  $class->generate_random_code( $width );
  _w( 1, "Created insert ID ($code)" );
  return $code; 
}

sub post_fetch_id { return undef }

1;

__END__

=pod

=head1 NAME

SPOPS::Key::Random - Creates a random alphanumeric code for the ID field

=head1 SYNOPSIS

 package MySPOPS;

 @MySPOPS::ISA = qw( SPOPS::Key::Random SPOPS::DBI );

=head1 DESCRIPTION

Very, very simple. We just use the I<generate_random_code()> 
method in all SPOPS  classes to generate an n character
code. The width of the code is determined by the field 
{id_width} in the CONFIG of the SPOPS implementation.

=head1 BUGS

B<Getting a 'random' value>

If you are using this under mod_perl, you might have the problem of
colliding ID fields. This seems to happen because the httpd children
all have the same random seed, since they are all forked off from the
same parent. 

The solution is to put a 'srand()' in the PerlChildInitHandler,
although mod_perl versions from 1.25 on might take care of this for
you.

=head1 TO DO

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
