package SPOPS::Import::DBI::TableTransform::InterBase;

# $Id: InterBase.pm,v 1.1 2002/04/27 19:06:26 lachoy Exp $

use strict;
use base qw( SPOPS::Import::DBI::TableTransform );

$SPOPS::Import::DBI::TableTransform::InterBase::VERSION  = substr(q$Revision: 1.1 $, 10);

sub increment {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT%%/INT NOT NULL/g;
}

sub increment_type {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT_TYPE%%/INT/g;
}

1;
