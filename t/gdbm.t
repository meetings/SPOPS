# $Id: gdbm.t,v 1.2 2001/02/11 21:07:07 lachoy Exp $

do "t/config.pl";
my $config = _read_config_file();
$config->{GDBM_test} ||= 'n';
if ( $config->{GDBM_test} ne 'y' ) {
  print "1..0\n";
  print "Skipping test on this platform\n";
  exit;
}

print "1..12\n";

use lib qw( t/ );
use GDBMTest;

sub filename { 't/test.gdbm' }
sub cleanup  { unlink filename }
sub create   { open F, '>' . filename; close F; }

sub new_object {
  eval { GDBMTest->new( { name => 'MyProject', version => 1.14, 
                          author => 'La Choy (lachoy@cwinters.com)' } ) };
}

# Time for a test drive
{

 # Make sure we can at least create an object
 my $obj = new_object;
 print "not " if ( $@ );
 print "ok 1\n";

 # Make sure GDBM_WRCREAT really creates a new file
 cleanup();
 $obj = new_object;
 eval { $obj->save( { perm => 'create' } ) };
 print "not " if $@ || !-w filename;
 print "ok 2\n";


 # Make sure GDBM_WRITE gets changed to GDBM_WRCREAT if the file doesn't exist
 cleanup();
 $obj = new_object;
 eval { $obj->save( { perm => 'write' } ) };
 print "not " if $@ || !-w filename;
 print "ok 3\n";

 # See if it does the Right Thing on its own
 cleanup();
 $obj = new_object;
 eval { $obj->save };
 print "not " if ( $@ || ! -w filename );
 print "ok 4\n";
}

# Fetch an object, then clone it and save it
{
 my $obj = eval { GDBMTest->fetch( 'MyProject-1.14' ) };
 print "not " if ( $@ );
 print "ok 5\n";
 
 print "not " if ( $obj->{name} ne 'MyProject' );
 print "ok 6\n";

 my $new_obj = eval { $obj->clone( { name => 'YourProject', version => 1.02 } ) };
 print "not " if ( $@ );
 print "ok 7\n";

 print "not " if ( $new_obj->{name} eq $obj->{name} );
 print "ok 8\n";

 eval { $new_obj->save };
 print "not " if ( $@ );
 print "ok 9\n";
} 

# Fetch the two objects in the db and be sure we got them all
{
 my $obj_list = eval { GDBMTest->fetch_group };
 print "not " if ( $@ );
 print "ok 10\n";

 print "not " if ( ! ref $obj_list eq 'ARRAY' );
 print "ok 11\n";

 print "not " if ( scalar @{ $obj_list } != 2 );
 print "ok 12\n";
}
 
cleanup();
