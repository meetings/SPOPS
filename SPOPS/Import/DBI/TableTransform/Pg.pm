package SPOPS::Import::DBI::TableTransform::Pg;

# $Id: Pg.pm,v 3.1 2003/01/02 05:57:40 lachoy Exp $

use strict;
use base qw( SPOPS::Import::DBI::TableTransform );

$SPOPS::Import::DBI::TableTransform::Pg::VERSION  = sprintf("%d.%02d", q$Revision: 3.1 $ =~ /(\d+)\.(\d+)/);

sub increment {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT%%/SERIAL/g;
}

sub increment_type {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT_TYPE%%/INT/g;
}

1;


__END__

=head1 NAME

SPOPS::Import::DBI::TableTransform::Pg - Table transformations for PostgreSQL

=head1 SYNOPSIS

 my $table = qq/
   CREATE TABLE blah ( id %%INCREMENT%% primary key,
                       name varchar(50) )
 /;
 my $transformer = SPOPS::Import::DBI::TableTransform->new( 'pg' );
 $transformer->increment( \$table );
 print $table;

 # Output:
 # CREATE TABLE blah ( id SERIAL primary key,
 #                     name varchar(50) )

=head1 DESCRIPTION

PostgreSQL-specific type conversions for the auto-increment field
type.

=head1 METHODS

B<increment>

Returns 'SERIAL'

B<increment_type>

Returns 'INT'

=head1 BUGS

None known.

=head1 TO DO

B<Add hook for extra statement>

Since PostgreSQL supports a sequence-based increment type, think about
adding a hook for an extra statement to be registered and modifying
'%%INCREMENT%%' to be 'INT NOT NULL' and the extra statement to create
a sequence of a given name.

=head1 SEE ALSO

L<SPOPS::Import::DBI::TableTransform|SPOPS::Import::DBI::TableTransform>

=head1 COPYRIGHT

Copyright (c) 2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

