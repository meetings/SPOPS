package My::LDAPConnect;

# $Id: LDAPConnect.pm,v 1.2 2001/10/26 03:21:35 lachoy Exp $

# Simple LDAP connection manager -- change %DATASOURCE as needed for testing

use strict;
use Carp qw( cluck );

my %HANDLES = ();

my %DATASOURCE = (
   main   => { host    => 'localhost',
               base_dn => 'dc=mycompany,dc=com' },
   remote => { host    => 'localhost',
               port    => 3890,
               base_dn => 'dc=mycompany,dc=com' },
);

sub connection_info {
    my ( $class, $connect_key ) = @_;
    return \%{ $DATASOURCE{ $connect_key } };
}


sub global_datasource_handle {
    my ( $class, $connect_key ) = @_;
    cluck "Cannot retrieve handle without connect key!\n" unless ( $connect_key );

    unless ( $HANDLES{ $connect_key } ) {
        my $ldap_info = $class->connection_info( $connect_key );
        $ldap_info->{port} ||= 389;
        my $ldap = Net::LDAP->new( $ldap_info->{host},
                                   port => $ldap_info->{port} );
        die "Cannot create LDAP connection!\n" unless ( $ldap );
        my ( %bind_params );
        if ( $ldap_info->{bind_dn} ) {
            $bind_params{dn}       = $ldap_info->{bind_dn};
            $bind_params{password} = $ldap_info->{bind_password};
        }
        my $bind_msg = $ldap->bind( %bind_params );
        die "Cannot bind! Error: ", $bind_msg->error, "\n" if ( $bind_msg->code );
        $HANDLES{ $connect_key } = $ldap;
    }
    return $HANDLES{ $connect_key };
}

1;
