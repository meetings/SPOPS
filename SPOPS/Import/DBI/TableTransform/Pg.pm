package SPOPS::Import::DBI::TableTransform::Pg;

# $Id: Pg.pm,v 1.2 2002/01/02 02:32:39 lachoy Exp $

use strict;
use base qw( SPOPS::Import::DBI::TableTransform );

$SPOPS::Import::DBI::TableTransform::Pg::VERSION  = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

sub increment {
  my ( $self, $sql ) = @_;
  $$sql =~ s/%%INCREMENT%%/SERIAL/g;
}

sub increment_type {
  my ( $self, $sql ) = @_;
  $$sql =~ s/%%INCREMENT_TYPE%%/INT/g;
}

1;
