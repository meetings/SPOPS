package SPOPS::Import::DBI::TableTransform::Pg;

# $Id: Pg.pm,v 3.0 2002/08/28 01:16:30 lachoy Exp $

use strict;
use base qw( SPOPS::Import::DBI::TableTransform );

$SPOPS::Import::DBI::TableTransform::Pg::VERSION  = sprintf("%d.%02d", q$Revision: 3.0 $ =~ /(\d+)\.(\d+)/);

sub increment {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT%%/SERIAL/g;
}

sub increment_type {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT_TYPE%%/INT/g;
}

1;
