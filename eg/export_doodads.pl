#!/usr/bin/perl

# $Id: export_doodads.pl,v 1.4 2001/12/31 05:33:38 lachoy Exp $

# To use this, first edit My/Common.pm with your database information
# and then run (mysql example)

# $ mysql test < users_groups_mysql.sql
# $ perl stock_user_group.pl
# $ perl stock_doodad.pl

# Also, try changing the argument in new() from 'object' to 'xml'

use strict;
use SPOPS::Export;

require My::Security;
require My::User;
require My::Doodad;

{
    my $exporter = SPOPS::Export->new( 'object' );
    $exporter->object_class( 'My::Doodad' );
    print $exporter->run;
}


