package GDBMTest;;

# $Header: /usr/local/cvsdocs/SPOPS/t/GDBMTest.pm,v 1.1 2000/09/14 21:53:36 cwinters Exp $

use strict;
use SPOPS::GDBM;

@GDBMTest::ISA      = qw( SPOPS::GDBM );
$GDBMTest::C        = {
 class        => 'GDBMTest',
 field_list   => [ qw/ name version author url / ],
 create_id    => sub { return join '-', $_[0]->{name}, $_[0]->{version} },
 gdbm_info    => { filename => 't/test.gdbm' }, 
};
$GDBMTest::C->{field} = { map { $_ => 1 } @{ $GDBMTest::C->{field_list} } };
$GDBMTest::RULESET  = {};

sub CONFIG  { return $GDBMTest::C };
sub RULESET { return $GDBMTest::RULESET };

1;

