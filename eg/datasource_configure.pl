#!/usr/bin/perl

# $Id: datasource_configure.pl,v 2.0 2002/03/19 04:00:06 lachoy Exp $

use strict;
use SPOPS::Initialize;

# Assumes the tables in users_groups* are created. See README for
# info.

{
    my $config = {
          user => {
             class          => 'My::User',
             isa            => [ 'SPOPS::DBI' ],
             rules_from     => [ 'My::DBI::DatasourceConfigure', 'My::DiscoverField' ],
             field_discover => 'yes',
             id_field       => 'user_id',
             base_table     => 'spops_user',
             dbi_config     => { dsn      => 'DBI:mysql:test',
                                 username => 'test',
                                 password => 'test' },
          },
    };
    SPOPS::Initialize->process({ config => $config });
    my $iter = My::User->fetch_iterator({ order => 'login_name' });
    while ( my $user = $iter->get_next ) {
        print "User: $user->{first_name} $user->{last_name} ($user->{login_name})\n";
    }
}
