package SPOPS::Key::DBI::HandleField;

# $Id: HandleField.pm,v 1.8 2001/06/03 22:43:34 lachoy Exp $

use strict;
use SPOPS  qw( _w DEBUG );

@SPOPS::Key::DBI::HandleField::ISA      = ();
$SPOPS::Key::DBI::HandleField::VERSION  = '1.7';
$SPOPS::Key::DBI::HandleField::Revision = substr(q$Revision: 1.8 $, 10);

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
  if ( $id ) { return $id }
  
  my $msg = 'Record saved, but ID of record unknown';
  SPOPS::Error->set({ user_msg   => $msg, 
                      type       => 'db',
                      system_msg => "Cannot retrieve just-inserted ID from table using field ($field)",
                      method     => 'post_fetch_id' });
  die $msg;
}

1;

__END__



