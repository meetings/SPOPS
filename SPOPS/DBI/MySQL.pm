package SPOPS::DBI::MySQL;

# $Id: MySQL.pm,v 2.1 2002/05/06 16:12:48 lachoy Exp $

use strict;
use SPOPS  qw( _w DEBUG );
use SPOPS::ClassFactory qw( OK NOTIFY );
use SPOPS::Key::DBI::HandleField;

$SPOPS::DBI::MySQL::VERSION  = substr(q$Revision: 2.1 $, 10);

sub sql_current_date  { return 'NOW()' }

sub sql_quote {
    my ( $class, $value, $type, $db ) = @_;
    $db ||= $class->global_datasource_handle;
    unless ( ref $db ) {
        SPOPS::Exception->throw( "No database handle could be found!" );
    }
    return $db->quote( $value, $type );
}


# Backward compatibility (basically) -- you just have to set a true
# value in the config if you have an auto-increment field in the
# table. If so we call the post_fetch_id method from
# SPOPS::Key::DBI::HandleField.

sub post_fetch_id {
    my ( $item, @args ) = @_;
    return undef unless ( $item->CONFIG->{increment_field} );
    $item->CONFIG->{handle_field} ||= 'mysql_insertid';
    DEBUG() && _w( 1, "Setting to handle field: $item->CONFIG->{handle_field}" );
    return SPOPS::Key::DBI::HandleField::post_fetch_id( $item, @args );
}


# Code generation behavior -- find defaults if asked

sub behavior_factory {
    my ( $class ) = @_;
    DEBUG() && _w( 1, "Installing MySQL default discovery for ($class)" );
    return { manipulate_configuration => \&find_mysql_defaults };
}


sub find_mysql_defaults {
    my ( $class ) = @_;
    my $CONFIG = $class->CONFIG;
    return ( OK, undef ) unless ( $CONFIG->{find_defaults} and $CONFIG->{find_defaults} eq 'yes' );
    my $dbh = $class->global_datasource_handle( $CONFIG->{datasource} );
    unless ( $dbh ) {
      return ( NOTIFY, "Cannot find defaults because no DBI database " .
                       "handle available to class ($class)" );
    }

    my $sql = "DESCRIBE $CONFIG->{base_table}";
    my ( $sth );
    eval {
        $sth = $dbh->prepare( $sql );
        $sth->execute;
    };
    if ( $@ ) {
      return ( NOTIFY, "Cannot find defaults because there was an error " .
                       "executing ($sql): $@. Class: $class" );
    }
    while ( my $row = $sth->fetchrow_arrayref ) {
        my $default = $row->[4];
        next unless ( $default );
        $CONFIG->{default_values}{ $row->[0] } = $default;
    }
}

1;

__END__

=pod

=head1 NAME

SPOPS::DBI::MySQL -- MySQL-specific code for DBI collections

=head1 SYNOPSIS

 myobject => {
   isa             => [ qw( SPOPS::DBI::MySQL SPOPS::DBI ) ],
   increment_field => 1,
 };

=head1 DESCRIPTION

This just implements some MySQL-specific routines so we can abstract
them out.

One of these items is to return the just-inserted ID. Only works for
tables that have at least one auto-increment field:

 CREATE TABLE my_table (
   id  int not null auto_increment,
   ...
 )

You must also specify a true value for the class configuration
variable 'increment_field' to be able to automatically retrieve
auto-increment field values.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::Key::HandleField|SPOPS::Key::HandleField>

L<DBD::mysql|DBD::mysql>

L<DBI|DBI>

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
