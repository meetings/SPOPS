package SPOPS::Import::DBI::TableTransform::Pg;

# $Id: Pg.pm,v 1.1 2001/12/27 22:10:46 lachoy Exp $

use strict;
use base qw( SPOPS::Import::DBI::TableTransform );

$SPOPS::Import::DBI::TableTransform::Pg::VERSION  = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub auto_increment {
  my ( $self, $sql ) = @_;
  $$sql =~ s/%%INCREMENT%%/SERIAL/g;
}

sub increment_type {
  my ( $self, $sql ) = @_;
  $$sql =~ s/%%INCREMENT_TYPE%%/INT/g;
}

1;
