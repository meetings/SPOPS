package My::DiscoverField;

# $Id: DiscoverField.pm,v 1.6 2002/02/22 20:40:07 lachoy Exp $

use strict;
use SPOPS               qw( DEBUG _w );
use SPOPS::ClassFactory qw( ERROR OK NOTIFY );

sub behavior_factory {
    my ( $class ) = @_;
    DEBUG() && _w( 1, "Installing field discovery for ($class)" );
    return { manipulate_configuration => \&discover_fields };
}

sub discover_fields {
    my ( $class ) = @_;
    my $CONFIG = $class->CONFIG;
    return ( OK, undef ) unless ( $CONFIG->{field_discover} eq 'yes' );
    my $dbh = $class->global_datasource_handle( $CONFIG->{datasource} );
    unless ( $dbh ) {
      return ( NOTIFY, "Cannot discover fields because no DBI database " .
                       "handle available to class ($class)" );
    }
    my $sql = $class->sql_fetch_types( $CONFIG->{base_table} );
    my ( $sth );
    eval {
        $sth = $dbh->prepare( $sql );
        $sth->execute;
    };
    return ( NOTIFY, "Cannot discover fields: $@" ) if ( $@ );
    $CONFIG->{field} = [ map { lc $_ } @{ $sth->{NAME} } ];
    DEBUG() && _w( 1, "Table: ($CONFIG->{base_table}); ",
			          "Fields: (", join( ', ', @{ $CONFIG->{field} } ), ")" );
    return ( OK, undef );
}

1;

__END__

=pod

=head1 NAME

My::DiscoverField - Sample rule for SPOPS::ClassFactory implementing autofield discovery

=head1 SYNOPSIS

  my $config = {
        myobject => { class          => 'My::Object',
                      isa            => [ 'SPOPS::DBI' ],
                      field          => [], # just for show...
                      rules_from     => [ 'My::DiscoverField' ],
                      field_discover => 'yes',
                      base_table     => 'mydata',
                      ...  },
  };
  my $class_list = SPOPS::Initialize->process({ config => $config });

  # All fields in 'mydata' table now available as object properties

=head1 DESCRIPTION

Simple behavior rule to dynamically find all fields in a particular
database table and set them in our object.

Configuration is easy, just put:

 rules_from => [ 'My::DiscoverField' ],

in your object configuration, or add 'My::DiscoverField' to an
already-existing 'rules_from' list. Then add:

 field_discover => 'yes',

to your object configuration. Initialize the class and everything in
'field' will be overwritten.

=head1 GOTCHAS

These fields are only discovered once, when the class is created. If
you modify the schema of a table (such as with an 'ALTER TABLE'
statement while a process (like a webserver) is running with SPOPS
definitions the field modifications will not be reflected in the
object class definition. (This is actually true of all
L<SPOPS::DBI|SPOPS::DBI> objects, but probably more apt to pop up
here.)

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
