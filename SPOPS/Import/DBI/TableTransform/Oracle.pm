package SPOPS::Import::DBI::TableTransform::Oracle;

# $Id: Oracle.pm,v 3.0 2002/08/28 01:16:30 lachoy Exp $

use strict;
use base qw( SPOPS::Import::DBI::TableTransform );

$SPOPS::Import::DBI::TableTransform::Oracle::VERSION  = sprintf("%d.%02d", q$Revision: 3.0 $ =~ /(\d+)\.(\d+)/);

sub increment {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT%%/INT NOT NULL/g;

# TODO: Think about doing something here like:
    #my ( $table_name ) = $$sql =~ /create\s+table\s+(\w+)\s*/;
    #$self->add_extra_statement( "CREATE SEQUENCE ${table_name}_id_seq" );
}

sub increment_type {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT_TYPE%%/INT/g;
}

1;
