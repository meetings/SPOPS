# $Header: /usr/local/cvsdocs/SPOPS/t/gdbm.t,v 1.5 2000/09/15 17:52:50 cwinters Exp $

do "t/config.pl";
my $config = _read_config_file();
$config->{GDBM_test} ||= 'n';
if ( $config->{GDBM_test} ne 'y' ) {
  print "1..0\n";
  print "Skipping test on this platform\n";
  exit;
}

print "1..10\n";

use lib qw( t/ );
use GDBMTest;

sub cleanup { unlink( 't/test.gdbm' ) }

# Create an object
{
 my $obj = eval { GDBMTest->new( { name => 'MyProject', version => 1.14, 
                                   author => 'La Choy (lachoy@cwinters.com)' } ) };
 print "not " if ( $@ );
 print "ok 1\n";

 # See whether creating a file works using the GDBM_WRITER constant
 eval { $obj->save };
 print "not " if ( $@ );
 print "ok 2\n";
}

# Fetch an object, then clone it and save it
{
 my $obj = eval { GDBMTest->fetch( 'MyProject-1.14' ) };
 print "not " if ( $@ );
 print "ok 3\n";
 
 print "not " if ( $obj->{name} ne 'MyProject' );
 print "ok 4\n";

 my $new_obj = eval { $obj->clone( { name => 'YourProject', version => 1.02 } ) };
 print "not " if ( $@ );
 print "ok 5\n";

 print "not " if ( $new_obj->{name} eq $obj->{name} );
 print "ok 6\n";

 eval { $new_obj->save };
 print "not " if ( $@ );
 print "ok 7\n";
} 

# Fetch the two objects in the db and be sure we got them all
{
 my $obj_list = eval { GDBMTest->fetch_group };
 print "not " if ( $@ );
 print "ok 8\n";

 print "not " if ( ! ref $obj_list eq 'ARRAY' );
 print "ok 9\n";

 print "not " if ( scalar @{ $obj_list } != 2 );
 print "ok 10\n";
}
 
cleanup();
