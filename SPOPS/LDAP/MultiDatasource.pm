package SPOPS::LDAP::MultiDatasource;

# $Id: MultiDatasource.pm,v 1.5 2001/08/28 21:32:45 lachoy Exp $

use strict;
use SPOPS::LDAP;

@SPOPS::LDAP::MultiDatasource::ISA       = qw( SPOPS::LDAP );
$SPOPS::LDAP::MultiDatasource::VERSION   = '1.8';
$SPOPS::LDAP::MultiDatasource::Revision  = substr(q$Revision: 1.5 $, 10);

use constant DEFAULT_CONNECT_KEY => 'main';

sub base_dn  {
    my ( $class, $connect_key ) = @_;
    my $partial_dn = $class->get_partial_dn( $connect_key );
    unless ( $partial_dn ) {
        die "No Base DN defined in SPOPS configuration key 'ldap_base_dn', cannot continue!\n";
    }
    my $connect_info = $class->connection_info( $connect_key );
    return join( ',', $partial_dn, $connect_info->{base_dn} );
}

# Retrieves the 'partial dn', or the section that's prepended to the
# server's 'base DN' to identify the branch on which these objects
# live

sub get_partial_dn {
    my ( $class, $connect_key ) = @_;
    my $base_dn_info = $class->CONFIG->{ldap_base_dn};
    return $base_dn_info unless ( ref $base_dn_info eq 'HASH' );
    $connect_key ||= $class->get_connect_key;
    return $base_dn_info->{ $connect_key };
}


sub get_connect_key {
    my ( $class ) = @_;
    return $class->CONFIG->{default_datasource} || DEFAULT_CONNECT_KEY;
}


sub fetch {
    my ( $class, $id, $p ) = @_;

    my $R = OpenInteract::Request->instance;

    # If passed in a handle, we will always use only that

    if ( $p->{ldap} ) {
        return $class->SUPER::fetch( $id, $p );
    }

    my $ds_list = $class->CONFIG->{datasource};

    # If only one datasource is specified in the configuration, then
    # use it

    unless ( ref $ds_list eq 'ARRAY' and scalar @{ $ds_list } ) {
        return $class->SUPER::fetch( $id, $p );
    }

    # Otherwise step through the datasource listing and try to
    # retrieve each one in turn

    foreach my $ds ( @{ $ds_list } ) {
        $R->scrib( 1, "Trying to use datasource ($ds) for class ($class)" );
        $p->{connect_key} = $ds;

        # Trap security errors; if we don't fetch an object, we'll
        # just return undef.

        my $object = eval { $class->SUPER::fetch( $id, $p ) };
        return $object if ( $object );
    }
    return undef;
}


sub fetch_group_all {
    my ( $class, $p ) = @_;

    if ( $p->{ldap} ) {
        return $class->SUPER::fetch_group( $p );
    }
    my $ds_list = $class->CONFIG->{datasource};
    unless ( ref $ds_list eq 'ARRAY' and scalar @{ $ds_list } ) {
        return $class->SUPER::fetch_group( $p );
    }
    my @all_objects = ();
    foreach my $ds ( @{ $ds_list } ) {
        $p->{connect_key} = $ds;
        my $object_list = $class->SUPER::fetch_group( $p );
        push @all_objects, @{ $object_list } if ( $object_list and ref $object_list eq 'ARRAY' );
    }
    return \@all_objects;
}

1;

__END__

=pod

=head1 NAME

SPOPS::LDAP::MultiDatasource -- SPOPS::LDAP functionality but fetching objects from multiple datasources

=head1 SYNOPSIS

 # In your configuration
 my $config = {
    datasource => [ 'main', 'secondary', 'tertiary' ],
    isa => [ ... 'SPOPS::LDAP::MultiDatasource' ],
 };

=head1 DESCRIPTION

This class extends L<SPOPS::LDAP> with one purpose: be able to fetch
objects from multiple datasources. This can happen when you have got
objects dispersed among multiple directories -- for instance, your
'Accounting' department is on one LDAP server and your 'Development'
department on another. One class can (more or less -- see below) link
the two LDAP servers.

=head2 Caveats

The C<fetch()> method is the only functional method overridden from
C<SPOPS::LDAP>. The C<fetch_group()> or C<fetch_iterator()> methods
will only use the first datasource in the listing, whatever datasource
you pass in with the parameter 'connect_key' or whatever LDAP
connection handle you pass in with the parameter 'ldap'. If you want
to retrieve objects from multiple datasources using the same filter,
use the C<fetch_group_all()> method.

The C<fetch_iterator()> method is not supported at all for multiple
datasources -- use C<fetch_group_all()>.

=head1 SETUP

There are a number of items to configure and setup to use this class.

=head2 SPOPS Configuration

B<datasource> (\@)

If you want to use multiple datasources, you need to specify them. The
C<datasource> key holds an arrayref of datasources B<in the order you
want them searched>.

Example:

 my $spops = {
   class      => 'My::Person',
   isa        => [ 'SPOPS::LDAP::MultiDatasource' ],
   datasource => [ 'main', 'accounting', 'development', 'etc' ],
 };

The 'etc' datasource will be the last one searched. This would
obviously be a performance hit if most of your objects were there.

B<ldap_base_dn> ($ or \%)

First, this should B<not> be a full DN, but rather a partial one that
when matched up with a datasource creates a full DN. For example:

 my $spops = {
   class      => 'My::Person',
   isa        => [ 'SPOPS::LDAP::MultiDatasource' ],
   ldap_base_dn => 'ou=People',
 };

Second, if you use a scalar for this key you are in effect saying 'use
the same partial DN for all my datasources'. But if you are using
different partial DNs for different datasources, you need to specify
them:

 my $spops = {
   class      => 'My::Person',
   isa        => [ 'SPOPS::LDAP::MultiDatasource' ],
   datasource => [ 'main', 'accounting', 'development', 'etc' ],
   ldap_base_dn => { main        => 'ou=People',
                     accounting  => 'ou=BeanCounters',
                     development => 'ou=Geeks',
                     etc         => 'ou=Commoners' },
 };

=head2 Methods You Must Implement

B<connection_info( $connect_key )>

This method should look at the C<$connect_key> and return a hashref of
information used to connect to the LDAP directory. Keys (hopefully
self-explanatory) should be:

=over 4

=item *

B<host> ($)

=item *

B<base_dn> ($)

=back

Other keys are optional and can be used in conjunction with a
connection/resource manager (example below).

=over 4

=item *

B<port> ($) (optional, default is '389')

=item *

B<bind_dn> ($) (optional, will use anonymous bind without)

=item *

B<bind_password> ($) (optional, only used if 'bind_dn' specified)

=back

For example:

 package My::ConnectionManage;

 use strict;

 my $connections = {
    main        => { host => 'localhost',
                     base_dn => 'dc=MyCompanyEast,dc=com' },
    accounting  => { host => 'accounting.mycompany.com',
                     base_dn => 'dc=MyCompanyWest,dc=com' },
    development => { host => 'dev.mycompany.com',
                     base_dn => 'dc=MyCompanyNorth,dc=com' },
    etc         => { host => 'etc.mycompany.com',
                     base_dn => 'dc=MyCompanyBranch,dc=com' },
 };

 sub connection_info {
     my ( $class, $connect_key ) = @_;
     return \%{ $connections->{ $connect_key } };
 }

Then put this class into the 'isa' for your SPOPS class:

 my $spops = {
   class      => 'My::Person',
   isa        => [ 'My::ConnectionManage', 'SPOPS::LDAP::MultiDatasource' ],
 };


B<global_datasource_handle( $connect_key )>

You will need an implementation that deals with multiple
configurations. For example:

 package My::DSManage;

 use strict;
 use Net::LDAP;

 my %DS = ();

 sub global_datasource_handle {
     my ( $class, $connect_key ) = @_;
     unless ( $connect_key ) {
         die "Cannot retrieve handle without connect key!\n";
     }
     unless ( $DS{ $connect_key } ) {
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
         $DS{ $connect_key } = $ldap;
     }
     return $DS{ $connect_key };
 }

Then put this class into the 'isa' for your SPOPS class:

 my $spops = {
   class      => 'My::Person',
   isa        => [ 'My::DSManage', 'SPOPS::LDAP::MultiDatasource' ],
 };

Someone with a thinking cap on might put the previous two items in the
same class :-)

=head1 METHODS

B<fetch( $id, \%params )>

Given the normal parameters for C<fetch()>, tries to retrieve an
object matching either the C<$id> or the 'filter' specified in
C<\%params> from one of the datasources. When it finds an object it is
immediately returned.

If you pass in the key 'ldap' in \%params, this functions as the
C<fetch()> does in C<SPOPS::LDAP> and multiple datasources are not
used.

Returns: SPOPS object (if found), or undef.

B<fetch_group_all( \%params )>

Given the normal parameters for C<fetch_group()>, retrieves B<all>
objects matching the parameters from B<all> datasources. Use with
caution.

Returns: Arrayref of SPOPS objects.

B<base_dn( $connect_key )>

Returns the B<full> base DN associated with C<$connect_key>.

B<get_partial_dn( $connect_key )>

Retrieves the B<partial> base DN associated with C<$connect_key>.

B<get_connect_key()>

If called, returns either the value of the config key
'default_datasource' or the value of the class constant
'DEFAULT_CONNECT_KEY', which is normally 'main'.

=head1 BUGS

None known.

=head1 TO DO

Test some more.

=head1 SEE ALSO

L<SPOPS::LDAP>

=head1 COPYRIGHT

fCopyright (c) 2001 MSN Marketing Service Nordwest, GmbH. All rights
reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
