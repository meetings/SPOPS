package My::Doodad;

# $Id: Doodad.pm,v 1.2 2001/12/19 06:32:04 lachoy Exp $

use strict;
use SPOPS::Initialize;
use SPOPS::Secure qw( :level :scope );

$My::Doodad::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

sub _base_config {
   my $config = {
         doodad => {
             class        => 'My::Doodad',
             isa          => [ 'SPOPS::Secure', 'My::Common' ],
             rules_from   => [ 'My::DiscoverField' ],
             field_discover => 'yes',
             field        => [],
             id_field     => 'doodad_id',
             increment_field => 1,
             no_insert    => [ 'doodad_id' ],
             skip_undef   => [],
             no_update    => [ 'doodad_id' ],
             base_table   => 'spops_doodad',
             sql_defaults => [],
             alias        => [],
             has_a        => { 'My::User' => 'created_by' },
             links_to     => {},
             fetch_by     => [ 'name' ],
             creation_security => {
                 u => undef,
                 g   => { 3 => 'WRITE' },
                 w   => 'READ',
             },
             track        => { create => 1, update => 1, remove => 1 },
             display      => { url => '/Doodad/show/' },
             name         => 'name',
             object_name  => 'Doodad',
         }
   };
   return $config;
}


sub config_class {
    require My::User;
    SPOPS::Initialize->process({ config => [ _base_config() ] });
}

&config_class;


########################################
# RULES
########################################

sub ruleset_factory {
    my ( $class, $ruleset ) = @_;
    push @{ $ruleset->{pre_save_action} }, \&set_creator;
    warn "Added 'set_creator' to $class\n";
    return __PACKAGE__;
}


sub set_creator {
    my ( $self ) = @_;
    return 1 if ( $self->is_saved );
    return 1 if ( $self->{created_by} );
    my $user = $self->global_user_current;
    $self->{created_by} = $user->id;
    return 1;
}



1;
