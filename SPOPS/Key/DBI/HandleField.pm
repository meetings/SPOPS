package SPOPS::Key::DBI::HandleField;

# $Id: HandleField.pm,v 1.13 2001/10/12 21:00:26 lachoy Exp $

use strict;
use SPOPS  qw( _w DEBUG );

@SPOPS::Key::DBI::HandleField::ISA      = ();
$SPOPS::Key::DBI::HandleField::VERSION  = '1.90';
$SPOPS::Key::DBI::HandleField::Revision = substr(q$Revision: 1.13 $, 10);

# Ensure only POST_fetch_id used

sub pre_fetch_id      { return undef }

# Retrieve the value of the just-inserted ID

sub post_fetch_id {
    my ( $self, $p )  = @_;
    my $field = $self->CONFIG->{handle_field};
    unless ( $field ) {
        my $msg = 'Record saved, but cannot retrieve ID since handle field is unknown';
        SPOPS::Error->set({ user_msg   => $msg,
                            type       => 'db',
                            system_msg => "Cannot retrieve just-inserted ID from table.",
                            method     => 'post_fetch_id' });
        die $msg;
    }

    my $id = $p->{statement}->{ $field } || $p->{db}->{ $field };
    DEBUG() && _w( 1, "Found inserted ID ($id)" );
    return $id if ( $id );

    my $msg = 'Record saved, but ID of record unknown';
    SPOPS::Error->set({ user_msg   => $msg,
                        type       => 'db',
                        system_msg => "Cannot retrieve just-inserted ID from table using field ($field)",
                        method     => 'post_fetch_id' });
    die $msg;
}

1;

__END__

=pod

=head1 NAME

SPOPS::Key::DBI::HandleField -- Retrieve an auto-increment value from a DBI statement or database handle

=head1 SYNOPSIS

 # In your SPOPS configuration

 $spops  = {
   'myspops' => {
       'isa'          => [ qw/ SPOPS::Key::DBI::HandleField  SPOPS::DBI / ],
       'handle_field' => 'mysql_insertid',
       ...
   },
 };

 # Note: Other classes (such as 'SPOPS::DBI::MySQL') use this class
 # without requiring you to specify the class or any of its
 # configuration information.

=head1 DESCRIPTION

This class simply reads an ID value from a statement or database
handle using the specified key. The value will generally represent the
unique ID of the row just inserted and was presumably retrieved by the
DBD library, which made it available by a particular key.

Currently, this is only known to work with the MySQL database and
L<DBD::mysql|DBD::mysql>. MySQL supports auto-incrementing fields
using the keyword 'AUTO_INCREMENT', such as:

 CREATE TABLE mytable (
   myid   INT NOT NULL AUTO_INCREMENT,
   ...
 )

With every INSERT into this table, the database will provide a
guaranteed-unique value for 'myid' if one is not specified in the
INSERT. Rather than forcing you to run a SELECT against the table to
find out the value of the unique key, the MySQL client libraries
provide (and L<DBD::mysql|DBD::mysql> supports) the value of the field
for you.

With MySQL, this is available through the 'mysql_insertid' key of the
L<DBI|DBI> database handle. (It is also currently available via the
statement handle using the same name, but this may go away in the
future.)

So if you were using straight DBI methods, a simplified example of
doing this same action would be (using MySQL):

 my $dbh = DBI->connect( 'DBI:mysql:test', ... );
 my $sql = "INSERT INTO mytable ( name ) VALUES ( 'european swallow' )";
 my $rv = $dbh->do( $sql );
 print "ID of just-inserted record: $dbh->{mysql_insertid}\n";

=head1 METHODS

B<post_fetch_id()>

Retrieve the just-inserted value from a key in the handle, as
described above.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<DBD::mysql|DBD::mysql>

L<DBI|DBI>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
