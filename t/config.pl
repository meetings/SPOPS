# -*-perl-*-

# $Id: config.pl,v 2.0 2002/03/19 04:00:07 lachoy Exp $

# Simple script used by the various tests to read the config
# file. Usually we just use as:

#     do( 't/config.pl' );
#     my $config = _read_config_file();

# Crude, but effective

my $CONFIG_FILE = 'spops_test.conf';

sub _read_config_file {
    return {}  unless ( -f $CONFIG_FILE );
    my $config = {};
    open( CONF, $CONFIG_FILE ) || die "Cannot open config file! $!";
    while ( <CONF> ) {
        chomp;
        next if ( /^\s*$/ );
        my ( $tag, $value ) = /^(\w+):\s+(.*)$/;
        $config->{ $tag } = $value;
    }
    close( CONF );
    return $config;
}

sub _cleanup_config_file {
    my $config = _read_config_file();
    if ( $config->{remove_config} =~ /^y$/i ) {
        unlink( $CONFIG_FILE );
    }
}

1;
