package SPOPS::User;

# $Id: User.pm,v 1.1.1.1 2001/02/02 06:08:32 lachoy Exp $

use strict;
use Carp          qw( carp );
use SPOPS::Secure qw( :level :scope );

@SPOPS::User::ISA     = qw();
$SPOPS::User::VERSION = sprintf("%d.%02d", q$Revision: 1.1.1.1 $ =~ /(\d+)\.(\d+)/);
$SPOPS::User::C       = {};

$SPOPS::User::crypt_password = undef;

use constant DEBUG  => 0;

sub CONFIG { return $SPOPS::User::C; }

sub _class_initialize {
 my $class  = shift;
 my $CONFIG = shift;
 warn " (User/_class_initialize): Set $class to use crypt ($CONFIG->{crypt_password})\n" if ( DEBUG );
 no strict 'refs';
 ${ $class . '::crypt_password' } = $CONFIG->{crypt_password};
}

sub fetch_by_username {
 my $class    = shift;
 my $username = lc shift;
 my $p        = shift;
 $p->{where} = ' login_name = ? ';
 $p->{value} = [ $username ];
 my $obj = eval { $class->fetch_group( $p ) };
 if ( $@ ) {
   $SPOPS::Error::user_msg = 'Cannot retrieve user by username.';
   die $SPOPS::Error::user_msg;
 }
 if ( scalar @{ $obj } > 1 ) {
   carp " (User/fetch_by_username): Too many users found in response to <<$username>>!\n";
 }
 return $obj->[0];
}

sub make_public {
 my $self = shift;

 # First find the public group
 my $groups = eval { SPOPS::Group->fetch_group( { where => ' name = ? ', 
                                                  value => [ 'public' ] } ) };
 if ( $@ ) {
   $SPOPS::Error::user_msg = 'Cannot make user part of public group';
   die $SPOPS::Error::user_msg;
 }
 if ( my $public = $groups->[0] ) {

   # Then add the user to it
   eval { $self->group_add( [ $public->{group_id} ] ); };
   if ( $@ ) {
     warn " (User/make_public): Error trying to add group to public: $@\n";
     $SPOPS::Error::user_msg = 'Cannot make user part of public group';
     die $SPOPS::Error::user_msg;
   }
   
   # Then ensure the public can see (for now) this user 
   eval { $self->set_item_security( { class => ref $self, oid => $self->{user_id},
                                      scope => SEC_SCOPE_GROUP, scope_id => $public->{group_id},
                                      level => SEC_LEVEL_READ } ) };
   if ( $@ ) {
     $SPOPS::Error::user_msg = 'User is part of public group, but public group cannot see user.';
     die $SPOPS::Error::user_msg;
   }
 }
}

sub full_name { return join ' ', $_[0]->{first_name}, $_[0]->{last_name}; }

sub check_password {
 my $self     = shift;
 my $check_pw = shift;
 return undef if ( ! $check_pw );
 my $exist_pw = $self->{password};
 no strict 'refs';
 my $class = ref $self;
 my $use_crypt = ${ $class . '::crypt_password' };
 if ( $use_crypt ) {
   warn " (User/check_password): Checking using the crypt function.\n"     if ( DEBUG );
   return ( crypt( $check_pw, $exist_pw ) eq $exist_pw );
 } 
 return ( $check_pw eq $exist_pw );
}

1;

=pod

=head1 NAME

SPOPS::User - Create and manipulate users. 

=head1 SYNOPSIS

  use SPOPS::User;
  $user = SPOPS::User->new();

  # Increment the user's login total
  $user->increment_login();
  print "Username: $user->{username}\n";

=head1 DESCRIPTION

=head1 METHODS

B<fetch_by_username( $username, \%params )>

Class method. Retrieves a user object based on a $username rather than
a user_id. Returns undef if no user found by that name.

B<full_name()>

Returns the full name -- it is accessed often enough that we just made
an alias for concatenating the first and last names.

B<make_public()>

Make this user part of the public group.

B<check_password( $pw )>

Return a 1 if the password matches what is in the database, a 0 if
not.

=head1 TO DO

=head1 BUGS

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>


=cut