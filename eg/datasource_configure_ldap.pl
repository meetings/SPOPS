#!/usr/bin/perl

# $Id: datasource_configure_ldap.pl,v 1.1 2002/01/08 02:32:48 lachoy Exp $

use strict;
use Data::Dumper qw( Dumper );
use SPOPS::Initialize;

# Assumes you have user entries in $LDAP_BASE_DN

my $LDAP_BASE_DN = 'ou=People,dc=yourcompany,dc=com';
{
    my $config = {
          user => {
             class          => 'My::User',
             isa            => [ 'SPOPS::LDAP' ],
             rules_from     => [ 'My::LDAP::DatasourceConfigure' ],
             id_field       => 'uid',
             field          => [ qw/ cn sn givenname displayname mail
                                     telephonenumber objectclass uid ou / ],
             ldap_base_dn   => $LDAP_BASE_DN,
             multivalue     => [ qw/ objectclass / ],
          },
    };
    SPOPS::Initialize->process({ config => $config });
    my $iter = eval { My::User->fetch_iterator({ filter => "(givenname=*)" }) };
    if ( $@ ) {
        print "Error trying action [", $@->action, "]: $@\n",
              $@->trace->as_string;
        exit;
    }
    while ( my $user = $iter->get_next ) {
        print "User: ", $user->dn, "\n";
    }
}
