package SPOPS::Import::DBI::TableTransform::Sybase;

# $Id: Sybase.pm,v 2.0 2002/03/19 04:00:02 lachoy Exp $

use strict;
use base qw( SPOPS::Import::DBI::TableTransform );

$SPOPS::Import::DBI::TableTransform::Sybase::VERSION  = substr(q$Revision: 2.0 $, 10);

sub increment {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT%%/NUMERIC( 10, 0 ) IDENTITY NOT NULL/g;
}

sub increment_type {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT_TYPE%%/NUMERIC( 10, 0 )/g;
}

1;
