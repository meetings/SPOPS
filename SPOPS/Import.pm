package SPOPS::Import;

# $Id: Import.pm,v 1.9 2002/01/08 04:31:53 lachoy Exp $

use strict;
use base qw( Class::Accessor );
use SPOPS::Exception;

use constant AKEY => '_attrib';

my %CLASSES = ();

my @FIELDS = qw( object_class data DEBUG );
SPOPS::Import->mk_accessors( @FIELDS );

sub new {
    my ( $pkg, $type, $params ) = @_;
    my $class = $CLASSES{ $type };
    unless ( $class ) {
        SPOPS::Exception->throw(
                 "You must specify a type of import to run -- available " .
                 "types are: ", join( ', ', sort keys %CLASSES ), "\n",
                 "(You specified: [$type])" );
    }

    my $self = bless( {}, $class );;
    foreach my $field ( $self->get_fields ) {
        $self->$field( $params->{ $field } );
    }
    return $self->initialize( $params );
}

sub initialize { return $_[0] }

sub get_fields { return @FIELDS }

# Class::Accessor stuff

sub get { return $_[0]->{ AKEY() }{ $_[1] } }
sub set { return $_[0]->{ AKEY() }{ $_[1] } = $_[2] }

# Import types

sub add_type {
    my ( $class, $import_type, $import_class ) = @_;
    unless ( $import_type )  { SPOPS::Exception->throw( "Cannot add import type: no type" ) }
    unless ( $import_class ) { SPOPS::Exception->throw( "Cannot add import type: no class" ) }

    eval "require $import_class";
    if ( $@ ) {
        SPOPS::Exception->throw( "Cannot add import type [$import_type]: " .
                                 "class [$import_class] cannot be required [$@]" );
    }

    if ( $CLASSES{ $import_type } ) {
        warn "[SPOPS::Import]: Attempt to add type ($import_type) redundant;\n",
             "type already exists with class: $CLASSES{ $import_type }\n";
    }
    else {
        $CLASSES{ $import_type } = $import_class;
    }
    return $CLASSES{ $import_type };
}

sub run { SPOPS::Exception->throw( "SPOPS::Import subclass should implement run()" ) }


########################################
# I/O
########################################

# Read import data from a file; the first item is metadata, the
# remaining ones are data. Subclasses should override and call

sub raw_data_from_file {
    my ( $class, $filename ) = @_;
    my $raw_data = $class->read_perl_file( $filename );
    unless ( ref $raw_data eq 'ARRAY' ) {
        SPOPS::Exception->throw( "Raw data must be in arrayref format." );
    }
    return $raw_data;
}


sub raw_data_from_fh {
    my ( $class, $fh ) = @_;
    no strict 'vars';
    my $raw = $class->read_fh( $fh );
    my $data = eval $raw;
    if ( $@ ) { SPOPS::Exception->throw( "Cannot parse data from filehandle: [$@]" ) }
    unless ( ref $data eq 'ARRAY' ) {
        SPOPS::Exception->throw( "Data must be in arrayref format" );
    }
    return $data;
}


# Read in a file and evaluate it as perl.

sub read_perl_file {
    my ( $class, $filename ) = @_;
    no strict 'vars';
    my $raw  = $class->read_file( $filename );
    my $data = eval $raw;
    if ( $@ ) { SPOPS::Exception->throw( "Cannot parse data file ($filename): $@" ) }
    return $data;
}


# Read in a file and return the contents

sub read_file {
    my ( $class, $filename ) = @_;

    unless ( -f $filename ) { SPOPS::Exception->throw( "Cannot read: [$filename] does not exist" ) }
    open( DF, $filename ) ||
        SPOPS::Exception->throw( "Cannot read data file: $!" );
    local $/ = undef;
    my $raw = <DF>;
    close( DF );
    return $raw;
}


sub read_fh {
    my ( $class, $fh ) = @_;
    local $/ = undef;
    my $raw = <$fh>;
    return $raw;
}


##############################
# Initialize

sub class_initialize {
    SPOPS::Import->add_type( object => 'SPOPS::Import::Object' );
    SPOPS::Import->add_type( dbdata => 'SPOPS::Import::DBI::Data' );
    SPOPS::Import->add_type( table  => 'SPOPS::Import::DBI::Table' );
}

class_initialize();

1;

__END__

=pod

=head1 NAME

SPOPS::Import - Factory and parent for importing SPOPS objects

=head1 SYNOPSIS

 my $importer = SPOPS::Import->new( 'object' );
 $importer->object_class( 'My::Object' );
 $importer->fields( [ 'name', 'title', 'average' ] );
 $importer->data( [ [ 'Steve', 'Carpenter', '160' ],
                    [ 'Jim', 'Engineer', '178' ],
                    [ 'Mario', 'Center', '201' ] ]);
 $importer->run;

=head1 DESCRIPTION

This class is a factory class for creating importer objects. It is
also the parent class for the importer objects.

=head1 METHODS

B<add_type( $type, $class )>

Lets C<SPOPS::Import> know about your custom import class so it can be
created via the normal factory method. For instance:

 use SPOPS::Import;

 SPOPS::Import->add_type( 'myimport'. 'My::Import' );
 my $importer = SPOPS::Import->new( 'myimport' );
 $importer->object_class( 'My::Object' );
 $importer->fields( [ 'name', 'title', 'average' ] );
 $importer->data( get_data_structure() );
 $importer->run;

=head2 I/O

B<read_file( $filename )>

Reads a file from C<$filename>, returning the content.

B<read_perl_file( $filename )>

Reads a file from C<$filename>, then does an L<eval|eval> on the
content to get back a Perl data structure. (Normal string C<eval>
caveats apply.)

Returns the Perl data structure.

B<read_fh( $filehandle )>

Reads all (or remaining) information from C<$filehandle>, returning
the content.

B<raw_data_from_file( $filename )>

Reads C<$filename> as a Perl data structure and does perliminary
checks to ensure it can be used in an import.

B<raw_data_from_fh( $filehandle )>

Reads C<$filehandle> as a Perl data structure and does perliminary
checks to ensure it can be used in an import.

=head2 Subclasses

Subclasses should override the following methods.

B<run()>

Runs the import and returns an arrayref of status entries, one for
each record it tried to import.

Each status entry is an arrayref formatted:

 [ status (boolean), record, message ]

If the import for this record was successful, the first (0) entry will
be true and the third (2) entry will be undefined.

If the import for this record failed, the first (0) entry will be
undefined and the third (2) entry will contain an error message.

Whether the import succeeds or fails, the second entry will contain
the record we tried to import. The record is an arrayref, and if you
want to map the values to fields just ask the importer object for its
fields:

 my $field_name = $importer->fields->[1];
 foreach my $item ( @{ $status } ) {
    print "Value of $field_name: $item->[1][1]\n";
 }

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::Import|SPOPS::Import>

L<SPOPS::Manual::ImportExport|SPOPS::Manual::ImportExport>

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
