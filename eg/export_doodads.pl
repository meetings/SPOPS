#!/usr/bin/perl

# $Id: export_doodads.pl,v 3.1 2003/07/15 12:18:28 lachoy Exp $

# To use this, first edit My/Common.pm with your database information
# and then run (mysql example)

# $ mysql test < users_groups_mysql.sql
# $ perl stock_user_group.pl
# $ perl stock_doodad.pl
# $ perl export_doodads.pl

# As XML:
# $ perl export_doodads.pl xml

use strict;
use SPOPS::Export;

require My::Security;
require My::User;
require My::Doodad;

{
    my $type = shift @ARGV || 'object';
    my $exporter = SPOPS::Export->new( $type );
    $exporter->object_class( 'My::Doodad' );
    print $exporter->run;
}


