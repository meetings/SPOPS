package SPOPS::Import::DBI::Table;

# $Id: Table.pm,v 1.1 2001/12/27 22:10:46 lachoy Exp $

use strict;
use base qw( SPOPS::Import );
use Data::Dumper qw( Dumper );
use SPOPS::Import::DBI::TableTransform;

my @FIELDS = qw( database_type transforms print_only );
SPOPS::Import::DBI::Table->mk_accessors( @FIELDS );

########################################
# Core API

sub get_fields { return ( $_[0]->SUPER::get_fields(), @FIELDS ) }

sub run {
    my ( $self ) = @_;

    unless ( $self->data ) {
        die "Cannot import a table without data!\n",
            "Please set it using \$table_import->data( \$table_sql )\n",
            "or \$table_import->read_table_from_file( '/path/to/mytable.sql' )\n",
            "or \$table_import->read_table_from_fh( \$filehandle )\n",
    }

    unless ( $self->database_type ) {
        die "Cannot import a table without specifying a database type.\n",
            "Please set the database type using \$table_import->database_type( 'dbtype' )\n";
    }

    my $table_sql = $self->transform_table;

    if ( $self->print_only ) {
        print $table_sql;
        return;
    }

    my $object_class = $self->object_class;
    unless ( $object_class ) {
        die "Cannot retrieve a database handle without an object class being\n",
            "defined. Please set it using \$table_import->object_class( 'My::Class' )\n",
            "so I know what to use.\n";
    }

    my $db = $object_class->global_datasource_handle;
    unless ( $db ) {
        die "No datasource defined for ($object_class) -- please ensure that\n",
            "when I call \$object_class->global_datasource_handle() I get a\n",
            "DBI handle back.\n";
    }

    eval { $db->do( $table_sql ) };
    return [ undef, $table_sql, $@ ] if ( $@ );
    return [ 1, $table_sql, undef ];
}


########################################
# Table Transformations

sub transform_table {
    my ( $self ) = @_;

    # Make a copy of 'data' so that it will remain in the
    # untransformed state

    my $table_sql = $self->data;

    # Create a new transformer

    my $transform = SPOPS::Import::DBI::TableTransform->new( $self->database_type );

    # These are the built-ins

    $transform->auto_increment( \$table_sql );
    $transform->increment_type( \$table_sql );

    # Run the custom transformations

    my $transforms = $self->transforms;
    if ( ref $transforms eq 'ARRAY' and scalar @{ $transforms } ) {
        foreach my $transform_sub ( @{ $transforms } ) {
            next unless ( ref $transform_sub eq 'CODE'  );
            $transform_sub->( $transform, \$table_sql, $self );
        }
    }

    return $table_sql;
}


########################################
# I/O

sub read_table_from_file {
    my ( $self, $filename ) = @_;
    $self->data( $self->read_file( $filename ) );
}

sub read_table_from_fh {
    my ( $self, $fh ) = @_;
    $self->data( $self->read_fh( $fh ) );
}

1;

__END__

=pod

=head1 NAME

SPOPS::DBI::Table - Import a DBI table structure

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use SPOPS::Import;

 {
     my $table_import = SPOPS::Import->new( 'table' );
     $table_import->database_type( 'sybase' );
     $table_import->read_table_from_fh( \*DATA );
     $table_import->print_only( 1 );
     $table_import->transforms([ \&table_login ]);
     $table_import->run;
 }

 sub table_login {
    my ( $transformer, $sql, $importer ) = @_;
    $$sql =~ s/%%LOGIN%%/varchar(25)/g;
 }

 __DATA__
 CREATE TABLE sys_user (
  user_id       %%INCREMENT%%,
  login_name    %%LOGIN%% not null,
  password      varchar(30) not null,
  last_login    datetime null,
  num_logins    int null,
  theme_id      %%INCREMENT_TYPE%% default 1,
  first_name    varchar(50) null,
  last_name     varchar(50) null,
  title         varchar(50) null,
  email         varchar(100) not null,
  language      char(2) default 'en',
  notes         text null,
  removal_date  datetime null,
  primary key   ( user_id ),
  unique        ( login_name )
 )

=head1 DESCRIPTION

This class allows you to transform and import (or simply display) a
DBI table structure.

Transformations are done via two means. The first is the
database-specific classes and the standard modifications provided by
L<SPOPS::Import::DBI::TableTransform|SPOPS::Import::DBI::TableTransform>. The
second is custom code that you can write.

=head1 METHODS

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::Manual::ImportExport|SPOPS::Manual::ImportExport>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
