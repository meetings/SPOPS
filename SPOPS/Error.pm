package SPOPS::Error;

# $Id: Error.pm,v 1.6 2001/06/03 22:43:34 lachoy Exp $

use strict;
use SPOPS qw( _w DEBUG );

@SPOPS::Error::ISA      = ();
$SPOPS::Error::VERSION  = '1.7';
$SPOPS::Error::Revision = substr(q$Revision: 1.6 $, 10);

$SPOPS::Error::user_msg   = undef;
$SPOPS::Error::system_msg = undef;
$SPOPS::Error::type       = undef;
$SPOPS::Error::package    = undef;
$SPOPS::Error::filename   = undef;
$SPOPS::Error::line       = undef;
$SPOPS::Error::method     = undef;
$SPOPS::Error::extra      = ();

sub clear {
 $SPOPS::Error::user_msg   = undef;
 $SPOPS::Error::system_msg = undef;
 $SPOPS::Error::type       = undef;
 $SPOPS::Error::package    = undef;
 $SPOPS::Error::filename   = undef;
 $SPOPS::Error::line       = undef;
 $SPOPS::Error::method     = undef;
 $SPOPS::Error::extra      = {};
}

sub get {
  my ( $class ) = @_;
  return { user_msg   => $SPOPS::Error::user_msg,
           system_msg => $SPOPS::Error::system_msg,
           type       => $SPOPS::Error::type,
           package    => $SPOPS::Error::package,
           filename   => $SPOPS::Error::filename,
           line       => $SPOPS::Error::line,
           method     => $SPOPS::Error::method,
           extra      => $SPOPS::Error::extra };
}

sub set {
  my ( $class, $p ) = @_;

  # First clean everything up

  $class->clear;

 # Then set everything passed in

  {
    no strict 'refs';
    foreach my $key ( keys %{ $p } ) {
      DEBUG() && _w( 1, "Setting error $key to $p->{ $key }" );
      ${ $class . '::' . $key } = $p->{ $key };
    }
  }

  # Set the caller information if the user didn't pass anything in

  unless ( $p->{package} and $p->{filename} and $p->{line} ) {
    ( $SPOPS::Error::package, 
      $SPOPS::Error::filename, 
      $SPOPS::Error::line ) = caller;
  }

  return $class->get;
}

1;

__END__

=pod

=head1 NAME

SPOPS::Error - Centralized error messages from all SPOPS objects.

=head1 SYNOPSIS

 # Using SPOPS in your application

 my $obj_list = eval { $obj->fetch_group( { where => 'this = that' } ) };
 if ( $@ ) {
   warn "Error found! Error: $@\n",
        "Error type: $SPOPS::Error::type\n",
        "More specific: $SPOPS::Error::system_msg\n", 
        "Extra stuff:\n",
        "--$SPOPS::Error::extra->{sql}\n",
        "--$SPOPS::Error::extra->{valuesb}\n";
 }

=head1 DESCRIPTION

This class provides a central location for error messages from all
SPOPS modules. The error information collected in these variables is
guaranteed to result from the most recent error generated by SPOPS.

=head1 VARIABLES

All of these variables are package variables, so you refer to them
like this:

  $SPOPS::Error::<variable_name>
  $SPOPS::Error::system_msg

See the L<NOTES> section below for hints on making the error variables
shorter.

B<user_msg> ($)

A generic message that is suitable for showing a user. When telling a
user something went wrong, you do not want to tell them:

 execute called with 2 bind variables when 1 are needed

instead, you want to tell them:

 Database query failed to execute

This variable is identical to the value thrown by the I<die()>
command, so you do not normally need to refer to it.

B<system_msg> ($)

Even though you do not want to show your users details of the error,
you still need to know them! The variable I<system_msg> gives you
details regarding the error.

B<type> ($)

SPOPS knows about a few types of errors. Some depend on your SPOPS
implementation (e.g., DBI, dbm, LDAP, etc.). Others can be:

 -security: There is a security violation and the action could not be
            completed

B<package> ($)

Set to the package from where the error was thrown.

B<method> ($)

Set to the method from where the error was thrown.

B<filename> ($)

Set to the filename from where the error was thrown.

B<line> ($)

Set to the line number from where the error was thrown.

B<extra> (\%)

Different SPOPS classes have different information related to the
current request. For instance, DBI errors will typically fill the
'sql' and 'values' keys. Other SPOPS implementations may use different
keys; see their documentation for details.

=head1 METHODS

B<clear>

Clears the current error saved in the class. Classes outside the
B<SPOPS::> hierarchy should never need to call this.

No return value.

B<get()>

Returns a hashref with all the currently set error values.

B<set( \% )>

First clears the variables then sets them all in one fell swoop. The
variables that are set are passed in the first argument, a
hashref. Also sets both the package and method variables for you,
although you can override by setting manually.

No return value;

=head1 NOTES

Some people might find it easier to alias a local package variable to
a SPOPS error variable. For instance, you can do:

 *err_user_msg   = \$SPOPS::Error::user_msg;
 *err_system_msg = \$SPOPS::Error::system_msg;
 *err_type       = \$SPOPS::Error::type;
 *err_extra      = \%SPOPS::Error::extra;

And then refer to the alias in your local package:

 my $obj_list = eval { $obj->fetch_group( { where => 'this = that' } ) };
 if ( $@ ) {
   warn "Error found! Error: $@\n",
        "Error type: $err_type\n",
        "More specific: $err_system_msg\n", 
        "Extra stuff:\n",
        "--$err_extra{sql}\n",
        "--$err_extra{values}\n";
 }

Whatever floats your boat.

=head1 TO DO

Nothing known.

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
