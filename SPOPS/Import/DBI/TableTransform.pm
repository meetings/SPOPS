package SPOPS::Import::DBI::TableTransform;

# $Id: TableTransform.pm,v 1.1 2001/12/27 22:10:46 lachoy Exp $

use strict;

$SPOPS::Import::DBI::TableTransform::VERSION  = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

my %CLASSES = (
   sybase   => 'SPOPS::Import::DBI::TableTransform::Sybase',
   mssql    => 'SPOPS::Import::DBI::TableTransform::Sybase',
   asany    => 'SPOPS::Import::DBI::TableTransform::Sybase',
   postgres => 'SPOPS::Import::DBI::TableTransform::Pg',
   pg       => 'SPOPS::Import::DBI::TableTransform::Pg',
   mysql    => 'SPOPS::Import::DBI::TableTransform::MySQL',
);


sub new {
    my ( $pkg, $type ) = @_;
    my $class = $CLASSES{ $type };
    unless ( $class ) {
        die "You must specify a database type so we know what to\n",
            "transform -- available database types are\n",
            join( ', ', sort keys %CLASSES ), "\n",
            "(You specified: [$type])\n";
    }
    eval "require $class";
    return bless( {}, $class );
}

1;

__END__

=pod

=head1 NAME

SPOPS::Import::DBI::TableTransform - Factory class for database-specific transformations

=head1 SYNOPSIS

 my $table = qq/ CREATE TABLE blah ( id %%INCREMENT%% primary key , name varchar(50) ) /;
 my $transformer = SPOPS::Import::DBI::TableTransform->new( 'sybase' );
 $transformer->auto_increment( \$table );
 print $table;

=head1 DESCRIPTION

=head1 METHODS

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::Import::DBI::Table|SPOPS::Import::DBI::Table>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut

