package SPOPS::Import::DBI::TableTransform::Sybase;

# $Id: Sybase.pm,v 1.1 2001/12/27 22:10:46 lachoy Exp $

use strict;
use base qw( SPOPS::Import::DBI::TableTransform );

$SPOPS::Import::DBI::TableTransform::Sybase::VERSION  = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub auto_increment {
  my ( $self, $sql ) = @_;
  $$sql =~ s/%%INCREMENT%%/NUMERIC( 10, 0 ) IDENTITY NOT NULL/g;
}

sub increment_type {
  my ( $self, $sql ) = @_;
  $$sql =~ s/%%INCREMENT_TYPE%%/NUMERIC( 10, 0 )/g;
}

1;
