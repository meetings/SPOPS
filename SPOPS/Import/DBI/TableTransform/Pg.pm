package SPOPS::Import::DBI::TableTransform::Pg;

# $Id: Pg.pm,v 2.0 2002/03/19 04:00:02 lachoy Exp $

use strict;
use base qw( SPOPS::Import::DBI::TableTransform );

$SPOPS::Import::DBI::TableTransform::Pg::VERSION  = substr(q$Revision: 2.0 $, 10);

sub increment {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT%%/SERIAL/g;
}

sub increment_type {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT_TYPE%%/INT/g;
}

1;
