package SPOPS::Import::DBI::TableTransform::SQLite;

# $Id: SQLite.pm,v 2.0 2002/03/19 04:00:02 lachoy Exp $

use strict;
use base qw( SPOPS::Import::DBI::TableTransform );

$SPOPS::Import::DBI::TableTransform::SQLite::VERSION  = substr(q$Revision: 2.0 $, 10);

sub increment {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT%%/INTEGER NOT NULL/g;
}

sub increment_type {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT_TYPE%%/INTEGER/g;
}

1;
