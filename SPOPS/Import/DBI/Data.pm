package SPOPS::Import::DBI::Data;

# $Id: Data.pm,v 1.3 2002/01/08 04:31:53 lachoy Exp $

use strict;
use base qw( SPOPS::Import );
use SPOPS::Exception;
use SPOPS::SQLInterface;

my @FIELDS = qw( table fields db );
SPOPS::Import::DBI::Data->mk_accessors( @FIELDS );

########################################
# Core API

sub get_fields { return ( $_[0]->SUPER::get_fields(), @FIELDS ) }

sub run {
    my ( $self ) = @_;
    eval {
        unless ( $self->db )     { die "Cannot run w/o a database handle available!" }
        unless ( $self->table )  { die "Cannot run w/o table defined!" }
        unless ( $self->fields ) { die "Cannot run w/o fields defined!" }
        unless ( $self->data )   { die "Cannot run w/o data defined" }
    };
    if ( $@ ) { SPOPS::Exception->throw( $@ ) }

    my %insert_args = ( db    => $self->db,
                        table => $self->table,
                        field => $self->fields, );
    my @status = ();
    foreach my $data ( @{ $self->data } ) {
        $insert_args{value} = $data;
        my $rv = eval { SPOPS::SQLInterface->db_insert( \%insert_args ) };
        if ( $@ ) {
            push @status, [ undef, $data, $@ ];
        }
        else {
            push @status, [ 1, $data, undef ];
        }
    }
    return \@status;
}

########################################
# Property manipulation

sub fields_as_hashref {
    my ( $self ) = @_;
    my $field_list = $self->fields;
    unless ( ref $field_list eq 'ARRAY' and scalar @{ $field_list } ) {
        SPOPS::Exception->throw(
                    "Before using this method, please set the fields in the " .
                    "importer object using:\n\$importer->fields( \\\@fields" );
    }
    my $count = 0;
    return { map { $_ => $count++ } @{ $field_list } };
}

########################################
# I/O and property assignment

sub data_from_file {
    my ( $self, $filename ) = @_;
    $self->assign_raw_data( $self->raw_data_from_file( $filename ) );
}


sub data_from_fh {
    my ( $self, $fh ) = @_;
    $self->assign_raw_data( $self->raw_data_from_fh( $fh ) );
}


sub assign_raw_data {
    my ( $self, $raw_data ) = @_;
    my $meta = shift @{ $raw_data };
    $self->table( $meta->{table} || $meta->{sql_table} );
    $self->fields( $meta->{fields} || $meta->{field_order} );
    $self->data( $raw_data );
    return $self;
}

1;

__END__

=pod

=head1 NAME

SPOPS::Import::DBI::Data - Import raw data to a DBI table

=head1 SYNOPSIS

 #!/usr/bin/perl

 use strict;
 use DBI;
 use SPOPS::Import;

 {
     my $dbh = DBI->connect( 'DBI:Pg:dbname=test' );
     $dbh->{RaiseError} = 1;

     my $table_sql = qq/
       CREATE TABLE import ( import_id SERIAL,
                             name varchar(50),
                             bad int,
                             good int,
                             disco int ) /;
     $dbh->do( $table_sql );

     my $importer = SPOPS::Import->new( 'dbdata' );
     $importer->db( $dbh );
     $importer->table( 'import' );
     $importer->fields( [ 'name', 'bad', 'good', 'disco' ] );
     $importer->data( [ [ 'Saturday Night Fever', 5, 10, 15 ],
                        [ 'Grease', 12, 5, 2 ],
                        [ "You Can't Stop the Music", 15, 0, 12 ] ] );
     my $status = $importer->run;
     foreach my $entry ( @{ $status } ) {
         if ( $entry->[0] ) { print "$entry->[1][0]: OK\n" }
         else               { print "$entry->[1][0]: FAIL ($entry->[2])\n" }
     }

     $dbh->do( 'DROP TABLE import' );
     $dbh->do( 'DROP SEQUENCE import_import_id_seq' );
     $dbh->disconnect;
}

=head1 DESCRIPTION

Import raw (non-object) data to a DBI table.

=head1 METHODS

=head1 BUGS

None known.

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

