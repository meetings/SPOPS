#!/usr/bin/perl

# $Id: ldap_multidatasource.pl,v 2.0 2002/03/19 04:00:06 lachoy Exp $

# ldap_multidatasource.pl
#   This is an example of how you can setup multiple datasources. You
#   will need to change the connection configuration information
#   located in eg/My/LDAPConnect.pm

use strict;
use SPOPS::Initialize;

{
    my $config = {
        user => {
          datasource   => [ 'main', 'remote' ],
          class        => 'My::LDAPUser',
          isa          => [ 'My::LDAPConnect', 'SPOPS::LDAP::MultiDatasource' ],
          field        => [ qw/ cn sn givenname displayname mail
                                telephonenumber objectclass uid ou / ],
          ldap_base_dn => 'ou=People',
          multivalue   => [ 'objectclass' ],
          id_field     => 'uid',
        },
    };

    SPOPS::Initialize->process({ config => $config });

    my $user_list = My::LDAPUser->fetch_group_all({ filter => 'givenname=User' });
    foreach my $user ( @{ $user_list } ) {
        print "I am ", $user->dn, " and I came from $user->{_datasource}\n";
    }
}
