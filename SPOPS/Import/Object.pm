package SPOPS::Import::Object;

# $Id: Object.pm,v 3.0 2002/08/28 01:16:30 lachoy Exp $

use strict;
use base qw( SPOPS::Import );

$SPOPS::Import::Object::VERSION  = sprintf("%d.%02d", q$Revision: 3.0 $ =~ /(\d+)\.(\d+)/);

my @FIELDS = qw( include_id fields extra_metadata ); # skip_fields 
SPOPS::Import::Object->mk_accessors( @FIELDS );


########################################
# Core API

sub get_fields { return ( $_[0]->SUPER::get_fields(), @FIELDS ) }

sub run {
    my ( $self ) = @_;
    my $fields       = $self->fields;
    my $object_class = $self->object_class;
    eval {
        unless ( $fields )       { die "Cannot run w/o fields defined!\n" }
        unless ( $object_class ) { die "Cannot run w/o object class defined\n" }
        unless ( $self->data )   { die "Cannot run w/o data defined\n" }
    };
    if ( $@ ) { SPOPS::Exception->throw( $@ ) }

    my $num_fields = scalar @{ $fields };
    my @status = ();
    foreach my $data ( @{ $self->data } ) {
        my $obj = $object_class->new;
        for ( my $i = 0; $i < $num_fields; $i++ ) {
            $obj->{ $fields->[ $i ] } = $data->[ $i ];
        }
        eval { $obj->save({ is_add        => 1,
                            DEBUG         => $self->DEBUG }) };
        if ( $@ ) {
            push @status, [ undef, $data, "$@ - $SPOPS::Error::system_msg" ];
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
               "Please set the fields in the importer object using:\n",
               "\$importer->fields( \\\@fields" );
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


# Note that we support 'spops_class' and 'field_order' below for
# backward compatibility

sub assign_raw_data {
    my ( $self, $raw_data ) = @_;
    my $meta = shift @{ $raw_data };
    $self->object_class( $meta->{object_class} || $meta->{spops_class} );
    delete $meta->{object_class};
    delete $meta->{spops_class};
    $self->fields( $meta->{fields} || $meta->{field_order} );
    delete $meta->{fields};
    delete $meta->{field_order};
    $self->extra_metadata( $meta );
    $self->data( $raw_data );
    return $self;
}

1;

__END__

=pod

=head1 NAME

SPOPS::Import::Object - Import SPOPS objects

=head1 SYNOPSIS

 # Create the importer and read in the properties and data

 my $importer = SPOPS::Import->new( 'object' )
                             ->data_from_file( 'mydata.dat' );

 # Modify the 'name' field in every record

 my $fields_h = $importer->fields_as_hashref;
 my $name_idx = $fields_h->{name};
 foreach my $data ( @{ $self->data } ) {
     $data->[ $name_idx ] =~ s/YourClass/MyClass/;
 }

 # Run the import and display the results

 my $status = $importer->run;
 foreach my $entry ( @{ $status } ) {
   if ( $entry->[0] ) { print "$entry->[1][0]: OK\n" }
   else               { print "$entry->[1][0]: FAIL ($entry->[2])\n" }
 }

=head1 DESCRIPTION

This class implements simple data import for SPOPS objects using a
serialized Perl data structure for the data storage.

For more information on SPOPS importing in general, see
L<SPOPS::Manual::ImportExport|SPOPS::Manual::ImportExport> and
L<SPOPS::Import|SPOPS::Import>.

=head1 METHODS

B<fields_as_hashref()>

Translate the field arrayref (returned by the C<fields()> call) into a
hashref of fieldname to position in data record. This is useful if you
want to modify the data after they have been read in -- since the data
are position- rather than name-indexed, you will need to map the name
to the index.

So you you had:

 my $fields = $importer->fields
 print Dumper( $fields );
 my $fields_h = $importer->fields_as_hashref;
 print Dumper( $fields_h );

You might wind up with:

  $VAR1 = [
          'first',
          'second',
          'third',
          'fourth'
          ];
  $VAR1 = {
          'first' => 0,
          'fourth' => 3,
          'third' => 2,
          'second' => 1
          };

B<data_from_file( $filename )>

Read the metadata and data from C<$filename>. Runs
C<assign_raw_data()> to put the information into the object.

B<data_from_fh( $fh )>

Read the metadata and data from the filehandle C<$fh>. Runs
C<assign_raw_data()> to put the information into the object.

B<assign_raw_data( \@raw_data )>

Assigns the raw data C<\@raw_data> to the object. The first item
should be metadata, and all remaining items are the data to be
inserted.

The metadata should at least have the keys C<object_class> and
C<fields> (or C<spops_class> and C<field_order>, respectively, for
backward compatibility).

Other metadata you include is available through the C<extra_metadata>
property. These metadata might be for application-specific purposes.

After this is run the object should have available for inspection the
following properties:

=over 4

=item *

B<object_class>

=item *

B<fields>

=item *

B<data>

=back

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::Manual::ImportExport|SPOPS::Manual::ImportExport>

L<SPOPS::Import|SPOPS::Import>

L<SPOPS::Export::Object|SPOPS::Export::Object>

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
