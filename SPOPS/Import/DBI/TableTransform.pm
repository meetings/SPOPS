package SPOPS::Import::DBI::TableTransform;

# $Id: TableTransform.pm,v 1.3 2002/01/08 04:31:53 lachoy Exp $

use strict;
use SPOPS::Exception;

$SPOPS::Import::DBI::TableTransform::VERSION  = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

my %CLASSES = ();

sub new {
    my ( $pkg, $type ) = @_;
    my $class = $CLASSES{ $type };
    unless ( $class ) {
        SPOPS::Exception->throw(
               "You must specify a database type so we know what to\n" .
               "transform -- available database types are\n" .
               join( ', ', sort keys %CLASSES ), "\n" .
               "(You specified: [$type])" );
    }
    eval "require $class";
    return bless( {}, $class );
}

sub add_type {
    my ( $class, $transform_type, $transform_class ) = @_;
    eval {
        unless ( $transform_type )  { die "Cannot add transform type: no type" }
        unless ( $transform_class ) { die "Cannot add transform type: no class" }
    };
    if ( $@ ) { SPOPS::Exception->throw( $@ ) }

    eval "require $transform_class";
    if ( $@ ) {
        SPOPS::Exception->throw(
               "Cannot add transform type [$transform_type]: class [$transform_class]\n",
               "cannot be required: [$@]" );
    }

    if ( $CLASSES{ $transform_type } ) {
        warn "[SPOPS::Import::DBI::TransformTable]: Attempt to add\n",
             "type ($transform_type) redundant; type already exists\n",
             "with class: $CLASSES{ $transform_type }\n";
    }
    else {
        $CLASSES{ $transform_type } = $transform_class;
    }
    return $CLASSES{ $transform_type };

}

sub class_initialize {
    SPOPS::Import::DBI::TableTransform->add_type(
                              sybase => 'SPOPS::Import::DBI::TableTransform::Sybase' );
    SPOPS::Import::DBI::TableTransform->add_type(
                              mssql => 'SPOPS::Import::DBI::TableTransform::Sybase' );
    SPOPS::Import::DBI::TableTransform->add_type(
                              asany => 'SPOPS::Import::DBI::TableTransform::Sybase' );
    SPOPS::Import::DBI::TableTransform->add_type(
                              postgres => 'SPOPS::Import::DBI::TableTransform::Pg' );
    SPOPS::Import::DBI::TableTransform->add_type(
                              pg => 'SPOPS::Import::DBI::TableTransform::Pg' );
    SPOPS::Import::DBI::TableTransform->add_type(
                              mysql => 'SPOPS::Import::DBI::TableTransform::MySQL' );
}

class_initialize();

1;

__END__

=pod

=head1 NAME

SPOPS::Import::DBI::TableTransform - Factory class for database-specific transformations

=head1 SYNOPSIS

 my $table = qq/ CREATE TABLE blah ( id %%INCREMENT%% primary key,
                                     name varchar(50) ) /;
 my $transformer = SPOPS::Import::DBI::TableTransform->new( 'sybase' );
 $transformer->auto_increment( \$table );
 print $table;

=head1 DESCRIPTION

This class is a factory class for database-specific
transformations. This means that
L<SPOPS::Import::DBI::Table|SPOPS::Import::DBI::Table> supports
certain keys that can be replaced by database-specific values. This
class is a factory for objects that take SQL data and do the
replacements.

=head1 METHODS

B<new( $database_type )>

Create a new transformer using the database type C<$database_type>.

Available database types are:

=over 4

=item sybase: Sybase SQL Server/ASE

=item asany: Sybase Adaptive Server Anywhere

=item mssql: Microsoft SQL Server

=item postgres: PostgreSQL

=item mysql: MySQL

=back

B<add_type( $database_type, $transform_class )>

Registers a new database type for a transformation class. You will
need to run this every time you run the program.

If you develop a transformation class for a database not represented
here, please email the author so it can be included with future
distributions.

=head1 CREATING A TRANSFORMATION CLASS

Creating a new subclass is extremely easy. You just need to subclass
this class, then create a subroutine for each of the built-in
transformations specified in
L<SPOPS::Import::DBI::Table|SPOPS::Import::DBI::Table>.

Each transformation takes two arguments: C<$self> and a scalar
reference to the SQL to be transformed. For example, here is a
subclass for a made up database:

 package SPOPS::Import::DBI::TableTransform::SavMor;

 use strict;
 use base qw( SPOPS::Import::DBI::TableTransform );

 sub increment {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT%%/UNIQUE_VALUE/g;
 }

 sub increment_type {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT_TYPE%%/INT/g;
 }

 1;

And then we could register the transformation agent with every run:

 SPOPS::Import::DBI::TableTransform->add_type(
          'savmor', 'SPOPS::Import::DBI::TableTransform::SavMor' );
 my $transformer = SPOPS::Import::DBI::TableTransform->new( 'savmor' );
 my $sql = qq/ CREATE TABLE ( id %%INCREMENT%% primary key ) /;
 $transformer->increment( \$sql );
 print $sql;

Output:

 CREATE TABLE ( id UNIQUE_VALUE primary key )

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::Import::DBI::Table|SPOPS::Import::DBI::Table>

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut

