
BEGIN { print "1..9\n" }

use SPOPS::HashFile;
use File::Copy;

sub clean_config { unlink( 't/test.perl' ); File::Copy::cp( 't/hash_file_test.perl', 't/test.perl' ); }
sub cleanup      { unlink( 't/test.perl' ); unlink( 't/test-new.perl' ); }
 
# Test for reading file in using 'read' permission
{ 
 clean_config();
 my $config = eval { SPOPS::HashFile->new( { filename => 't/test.perl', perm => 'read' } ) };
 print "not " if ( $@ );
 print "ok 1\n";
}

# Test for reading file in using 'write' permission
{ 
 clean_config();
 my $config = eval { SPOPS::HashFile->new( { filename => 't/test.perl', perm => 'write' } ) };
 print "not " if ( $@ );
 print "ok 2\n";
}

# Tests for opening file that doesn't existing using 'new' permission
# (we want the second one to fail)
{ 
 clean_config();
 my $config     = eval { SPOPS::HashFile->new( { filename => 't/not_exist.perl', perm => 'new' } ) };
 print "not " if ( $@ );
 print "ok 3\n";

 my $config_two = eval { SPOPS::HashFile->new( { filename => 't/not_exist.perl', perm => 'write' } ) };
 print "not " unless ( $@ =~ /^Cannot create object without existing file or 'new' permission/ );
 print "ok 4\n";
}

{
 clean_config();
 my $config = SPOPS::HashFile->new( { filename => 't/test.perl', perm => 'write' } );
 $config->{smtp_host} = '192.168.192.1';
 $config->{dir}->{download} = '$BASE/downloads';
 eval { $config->save };
 print "not " if ( $@ );
 print "ok 5\n";
}

{
 clean_config();
 my $config = SPOPS::HashFile->new( { filename => 't/test.perl', perm => 'write' } );
 eval { $config->remove };
 print "not " if ( $@ or -f 't/test.perl' );
 print "ok 6\n";
}

{
 clean_config();
 my $config = SPOPS::HashFile->new( { filename => 't/test.perl', perm => 'read' } );
 my $newconf = eval { $config->clone( { filename => 't/test-new.perl', perm => 'new' } ) };
 print "not " if ( $@ );
 print "ok 7\n";

 my $conf_obj    = tied %{ $config };
 my $newconf_obj = tied %{ $newconf };
 print "not " if ( $newconf_obj->{filename} eq $conf_obj->{filename} or
                   $newconf_obj->{perm}     eq $conf_obj->{perm} );
 print "ok 8\n";

 $newconf->{dir}->{base} = '~/otherapp/spops.perl';
 eval { $newconf->save };
 print "not " if ( $@ );
 print "ok 9\n";
 unlink( 't/test-new.perl' );
}

cleanup();
