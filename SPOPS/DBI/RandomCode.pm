package SPOPS::DBI::RandomCode;

# $Id: RandomCode.pm,v 1.7 2001/06/03 22:43:34 lachoy Exp $

use strict;
use SPOPS  qw( _w DEBUG );

@SPOPS::DBI::RandomCode::ISA      = ();
$SPOPS::DBI::RandomCode::VERSION  = '1.7';
$SPOPS::DBI::RandomCode::Revision = substr(q$Revision: 1.7 $, 10);

my $DEFAULT_WIDTH = 8;

sub pre_fetch_id  { 
  my ( $class, $width ) = @_;
  warn "****SPOPS::DBI::RandomCode is deprecated and will probably be\n",
       "removed in a future version of SPOPS. Please change your\n",
       "classes to use 'SPOPS::Key::Random' instead.\n";
  $width ||= $class->CONFIG->{id_width} || $DEFAULT_WIDTH;
  my $code =  $class->generate_random_code( $width );
  DEBUG() && _w( 1, "Created insert ID ($code)" );
  return $code; 
}

sub post_fetch_id { return undef }

1;

__END__

=pod

=head1 NAME

SPOPS::DBI::RandomCode - Creates a random code for the ID field

=head1 SYNOPSIS

THIS PACKAGE IS DEPRECATED. PLEASE USE 'SPOPS::Key::Random'
INSTEAD. THIS PACKAGE WILL BE DISCONTINUED WITH THE 0.41 RELEASE.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
