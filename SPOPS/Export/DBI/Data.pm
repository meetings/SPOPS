package SPOPS::Export::DBI::Data;

# $Id: Data.pm,v 1.2 2002/01/02 02:37:02 lachoy Exp $

use strict;
use base qw( SPOPS::Export::Object );

sub create_header {
    my ( $self, $fields ) = @_;
    my $table = $self->object_class->table_name;
    my $field_names_show = join ' ', @{ $fields };
    return join( "\n", '$item = [',
                       "  { table => '$table',",
                       "    field_order => [ qw/ $field_names_show / ] },\n" );
}

1;

__END__

=pod

=head1 NAME

SPOPS::Export::DBI::Data - Export SPOPS objects as data for importing directly into a DBI table

=head1 SYNOPSIS

 # See SPOPS::Export

=head1 DESCRIPTION

Implement raw DBI data output for L<SPOPS::Export|SPOPS::Export>. This
is almost exactly like L<SPOPS::Export::Object|SPOPS::Export::Object>
except we export the table name instead of the object class.

Output from this should be usable by
L<SPOPS::Import::DBI::Data|SPOPS::Import::DBI::Data>.

=head1 METHODS

=head1 BUGS

=head1 TO DO

Nothing known.

=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut


1;
