#!/usr/bin/perl

use strict;

my $MODULE_WIDTH = 25;
my $FMT_PATTERN  = "%-${MODULE_WIDTH}s";

{
 print "Testing whether all files in this module compile.\n\n";
 printf( "$FMT_PATTERN  Status\n", 'Module');
 print '=' x $MODULE_WIDTH, '  ', '=' x 7, "\n";
 open ( LIST, 'MANIFEST' ) || die "Cannot open manifest! $!";
 while ( <LIST> ) {
   next if ( m|^t/| );
   chomp;
   if ( s/\.pm$// ) {	 
	 s|/|::|g;
	 eval "require $_";
	 printf( "$FMT_PATTERN  error\n%s", $_, $@ )	  if ( $@ );
	 printf( "$FMT_PATTERN  ok", $_ )                 if ( ! $@ );
	 print "\n";
   }
 }
 close( LIST );
}
