package SPOPS::DBI::RandomCode;

# $Id: RandomCode.pm,v 1.13 2000/11/18 21:09:05 cwinters Exp $

use strict;

@SPOPS::DBI::RandomCode::ISA     = ();
$SPOPS::DBI::RandomCode::VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

use constant DEBUG => 0;

my $DEFAULT_WIDTH = 8;

sub pre_fetch_id  { 
 my $class = shift;
 my $width = shift || $class->CONFIG->{id_width} || $DEFAULT_WIDTH;
 my $code =  $class->generate_random_code( $width );
 warn " (SPOPS/DBI/RandomCode): Found inserted ID ($code)\n"               if ( DEBUG );
 return $code; 
}

sub post_fetch_id { return undef }

1;

__END__

=pod

=head1 NAME

SPOPS::DBI::RandomCode - Creates a random code for the ID field

=head1 SYNOPSIS

 package MySPOPS;

 @MySPOPS::ISA = qw( SPOPS::DBI::RandomCode SPOPS::DBI );

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

Copyright (c) 2000 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>


=cut
