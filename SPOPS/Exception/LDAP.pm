package SPOPS::Exception::LDAP;

# $Id: LDAP.pm,v 2.0 2002/03/19 04:00:01 lachoy Exp $

use strict;
use base qw( SPOPS::Exception );

$SPOPS::Exception::LDAP::VERSION   = substr(q$Revision: 2.0 $, 10);

my @FIELDS = qw( code action filter error_text error_name );
SPOPS::Exception::LDAP->mk_accessors( @FIELDS );
sub get_fields { return ( $_[0]->SUPER::get_fields, @FIELDS ) }

1;

__END__

=pod

=head1 NAME

SPOPS::Exception::LDAP - SPOPS exception with extra LDAP parameters

=head1 SYNOPSIS

 my $iterator = eval { My::LDAPUser->fetch_iterator };
 if ( $@ and $@->isa( 'SPOPS::Exception::LDAP' ) ) {
     print "Failed LDAP execution with: $@\n",
           "Action: ", $@->action, "\n",
           "Code: ", $@->code, "\n",
           "Error Name: ", $@->error_name, "\n",
           "Error Text: ", $@->error_text, "\n",
 }

=head1 DESCRIPTION

Same as L<SPOPS::Exception|SPOPS::Exception> but we add four new
properties:

B<code> ($)

The LDAP code returned by the server.

B<action> ($)

The LDAP action we were trying to execute when the error occurred.

B<error_name> ($)

Name of the error corresponding to C<code> as returned by
L<Net::LDAP::Util|Net::LDAP::Util>.

B<error_text> ($)

Text of the error corresponding to C<code> as returned by
L<Net::LDAP::Util|Net::LDAP::Util>. This is frequently the same as the
error message, but not necessarily.

=head1 METHODS

No extra.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::Exception|SPOPS::Exception>

L<Net::LDAP|Net::LDAP>

L<Net::LDAP::Util|Net::LDAP::Util>

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
