package SPOPS::Key::DBI::HandleField;

# $Id: HandleField.pm,v 1.3 2001/02/21 12:42:54 lachoy Exp $

use strict;
use SPOPS  qw( _w );

@SPOPS::Key::DBI::HandleField::ISA     = ();
$SPOPS::Key::DBI::HandleField::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

# Ensure only POST_fetch_id used

sub pre_fetch_id      { return undef }

# Retrieve the value of the just-inserted ID

sub post_fetch_id { 
  my ( $self, $p )  = @_;
  my $field = $self->CONFIG->{handle_field};
  unless ( $field ) {
    my $msg = 'Record saved, but cannot retrieve ID since handle field is unknown';
    SPOPS::Error->set({ user_msg => $msg, type => 'db',
                        system_msg => "Cannot retrieve just-inserted ID from table.",
                        method => 'post_fetch_id' });
    die $msg;
  }

  my $id = $p->{statement}->{ $field } || $p->{db}->{ $field };
  _w( 1, "Found inserted ID ($id)" );
  if ( $id ) { return $id }
  
  my $msg = 'Record saved, but ID of record unknown';
  SPOPS::Error->set({ user_msg => $msg, type => 'db',
                      system_msg => "Cannot retrieve just-inserted ID from table using field ($field)",
                      method => 'post_fetch_id' });
  die $msg;
}

1;

__END__



