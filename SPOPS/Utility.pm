package SPOPS::Utility;

# $Id: Utility.pm,v 1.12 2001/10/12 21:00:26 lachoy Exp $

use strict;
use Date::Format  qw( time2str );
use Date::Calc    ();

@SPOPS::Utility::ISA      = qw();
$SPOPS::Utility::VERSION  = '1.90';
$SPOPS::Utility::Revision = substr(q$Revision: 1.12 $, 10);


# Return a random code of length $length. If $opt is 'mixed', then the
# code is filled with both lower- and upper-case charaters.
#
# Signature: $code = $class->generate_random_code( $length, [ 'mixed' ] );

sub generate_random_code {
    my ( $class, $length, $opt ) = @_;
    return undef unless ( $length );
    if ( $opt eq 'mixed' ) {
        return join '', map { ( $_ % 2 == 0 )
                              ? chr( int( rand(26) ) + 65 )
                              : chr( int( rand(26) ) + 97 ) } ( 1 .. $length );
    }
    return join '', map { chr( int( rand(26) ) + 65 ) } ( 1 .. $length );
}


# Return a 'crypt'ed version of $text
#
# Signature: $crypted = $class->crypt_it( $text );

sub crypt_it {
    my ( $class, $text ) = @_;
    return undef unless ( $text );
    my $salt = $class->generate_random_code( 2 );
    return crypt( $text, $salt );
}


# Return a { time } (or the current time) formatted with { format }
#
# Signature: $time_string = $class->now( [ { format => $strftime_format, 
#                                            time => $time_in_seconds } ] );

sub now {
    my ( $class, $p ) = @_;
    $p->{format} ||= '%Y-%m-%d %T';
    $p->{time}   ||= time;
    return time2str( $p->{format}, $p->{time} );
}


# Return the current time formatted 'yyyy-mm-dd'
#
# Signature: $date_string = $class->today();

sub today { return $_[0]->now( { format => '%Y-%m-%e' } ); }


# Return a true value if right now is between two other dates

# Signature:
#   DATE_FORMAT is [ yyyy,mm,dd ] or 'yyyy-mm-dd'
#   $rv = $class->date_between_dates( { begin => DATE_FORMAT,
#                                       end   => DATE_FORMAT } );

sub now_between_dates {
    my ( $class, $p ) = @_;
    return undef unless ( $p->{begin} or $p->{end} );
    my @now = Date::Calc::Today();
    my ( $begin_days, $end_days ) = undef;
    my ( $begin_date, $end_date );

    if ( $p->{begin} ) {
        if ( ref $p->{begin} eq 'ARRAY' ) {
            $begin_date = $p->{begin};
        }
        else {
            @{ $begin_date } = $p->{begin} =~ /^(\d+)\-(\d+)\-(\d+)/;
        }

        # Good result: 1 (meaning 'begin' is one day before 'now')

        $begin_days = Date::Calc::Delta_Days( @{ $begin_date }, @now );
        return undef if ( $begin_days < 0 );
    }

    if ( $p->{end} ) {
        if ( ref $p->{end} eq 'ARRAY' ) {
            $end_date = $p->{end};
        }
        else {
            @{ $end_date } = $p->{end} =~ /^(\d+)\-(\d+)\-(\d+)/;
        }

        # Good result: 1 (meaning 'now' is one day before begin)

        $end_days = Date::Calc::Delta_Days( @now, @{ $end_date } );
        return undef if ( $end_days < 0 );
    }
    return 1 unless ( defined $begin_days and defined $end_days );

    my $spread_days = Date::Calc::Delta_Days( @{ $begin_date }, @{ $end_date } );
    return undef if ( $end_days - $begin_days > $spread_days );
    return 1;
}


# Pass in \@existing and \@new and get back a hashref with:
#   add    => \@: items in \@new but not in \@existing,
#   keep   => \@: items in \@new and in \@existing,
#   remove => \@: items not in \@new but in \@existing  

sub list_process {
    my ( $class, $exist, $new ) = @_;

    # Create a hash of the existing items

    my %existing = map { $_ => 1 } @{ $exist };
    my ( @k, @a );

    # Go through the new items...

    foreach my $new_id ( @{ $new } ) {

        #... if it's existing, track it as a keeper and remove it
        # from the existing pile

        if ( $existing{ $new_id } ) {
            delete $existing{ $new_id };
            push @k, $new_id;
        }

        # otherwise, track it as an add

        else {
            push @a, $new_id;
        }
    }

    # now, the only items left in %existing are the ones
    # that were not specified in the new list; therefore,
    # these should be removed

    return { add => \@a, keep => \@k, remove => [ keys %existing ] };
}

1;


__END__

=pod

=head1 NAME

SPOPS::Utility - Utility methods for SPOPS objects

=head1 SYNOPSIS

 # In configuration file
  'isa' => [ qw/ SPOPS::Utility SPOPS::DBI / ],

 # Create an object and run a utility
 my $user = MyApp::User->fetch( $id );
 $user->{crypted_password} = $user->crypt_it( $new_password );

 # Also use them separately
 use SPOPS::Utility qw();

 my $now = SPOPS::Utility->now;
 my $random = SPOPS::Utility->generate_random_code( 16 );

=head1 DESCRIPTION

This class has a number of utility methods that can be used from SPOPS
objects or from the SPOPS classes. They were previously in the main
SPOPS module but were removed to make the classes more consistent and
focused.

The different methods are fairly unrelated.

=head1 METHODS

B<generate_random_code( $length )>

Generates a random code of $length length consisting of upper-case
characters in the english alphabet.

B<crypt_it( $text )>

Returns a crypt()ed version of $text. If $text not passed
in, returns undef.

B<now( \% )>

Return the current time, formatted: yyyy-mm-dd hh:mm:ss. Since we use
the L<Date::Format|Date::Format> module (which in turn uses standard
strftime formatting strings), you can pass in a format for the
date/time to fit your needs.

Parameters:

=over 4

=item *

B<format>: strftime format

=item *

B<time>: return of time command (or manipulation thereof); see C<perldoc -f time>

=back

B<today()>

Return a date (yyyy-mm-dd) for today.

B<now_between_dates( { begin => $dateinfo, end => $dateinfo } );

Where $dateinfo is either a simple scalar ('yyyy-mm-dd') or an
arrayref ([yyyy,mm,dd]).

Note that you can also just pass one of the dates and the check will
still perform ok.

Returns 1 if 'now' is between the two dates (inclusive), undef
otherwise.

Examples:

 # Today is '2000-10-31' in all examples

 SPOPS::Utility->now_between_days( { begin => '2000-11-01' } );
 ( returns 'undef' )

 SPOPS::Utility->now_between_days( { end => '1999-10-31' } );
 ( returns 'undef' )

 SPOPS::Utility->now_between_days( { begin => [2000, 10, 1 ] } );
 ( returns 1 )

 SPOPS::Utility->now_between_days( { begin => '2000-10-01',
                                     end   => '2001-10-01' } );
 ( returns 1 )

B<list_process( \@existing, \@new )>

Returns: hashref with three keys, each with an arrayref as the value:

 keep:   items found in both \@existing and \@new
 add:    items found in \@new but not \@existing
 remove: items found in \@existing but not \@new

Mainly used for determining one-to-many relationship changes, but you
can probably think of other applications.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

See the L<SPOPS|SPOPS> module for the full author list.

=cut
