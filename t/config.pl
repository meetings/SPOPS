#!/usr/bin/perl

# $Id: config.pl,v 1.1.1.1 2001/02/02 06:08:35 lachoy Exp $

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
