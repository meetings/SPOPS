package SPOPS::Tool::UTFConvert;

# $Id: UTFConvert.pm,v 3.1 2003/01/02 06:00:21 lachoy Exp $

# ***************WARNING***************
# This currently only works in 5.6.0 and earlier versions of Perl. It
# will barf with a syntax error on later versions.

use strict;
use utf8;
use SPOPS qw( _w DEBUG );

$SPOPS::Tool::UTFConvert::VERSION = sprintf("%d.%02d", q$Revision: 3.1 $ =~ /(\d+)\.(\d+)/);

sub ruleset_factory {
    my ( $class, $ruleset ) = @_;
    DEBUG && _w( 1, "Installing UTF8 conversion methods for ($class)" );
    push @{ $ruleset->{post_fetch_action} }, \&from_utf;
    push @{ $ruleset->{pre_save_action} }, \&to_utf;
}


sub from_utf {
    my ( $self ) = @_;
    my $convert_fields = $self->CONFIG->{utf_fields};
    return 1 unless ( ref $convert_fields eq 'ARRAY' and
                      scalar @{ $convert_fields } );
    foreach my $field ( @{ $convert_fields } ) {
        $self->{ $field } =~ tr/\0-\x{FF}//UC;
    }
    return 1;
}

sub to_utf {
    my ( $self ) = @_;
    my $convert_fields = $self->CONFIG->{utf_fields};
    return 1 unless ( ref $convert_fields eq 'ARRAY' and
                      scalar @{ $convert_fields } );
    foreach my $field ( @{ $convert_fields } ) {
        $self->{ $field } =~ tr/\0-\x{FF}//CU;
    }
    return 1;
}

1;

__END__

=head1 NAME

SPOPS::Tool::UTFConvert -- Provide automatic UTF-8 conversion

=head1 SYNOPSIS

 # Only use this in 5.6.0 and earlier versions of Perl!

 # In object configuration
 object => {
    rules_from => [ 'SPOPS::Tool::UTFConvert' ],
    utf_fields => [ 'field1', 'field2' ],
 },

=head1 WARNING

This currently only works in 5.6.0 and earlier versions of Perl. It
will barf with a syntax error on later versions.

=head1 DESCRIPTION

Provides translation from/to unicode datasources via UTF8. When an
object is fetched we do a translation on the fields specified in
'utf_fields' of the object configuration, and before an object is
saved we do a translation on those same fields.

=head1 METHODS

B<ruleset_factory( $class, $ruleset )>

Installs C<post_fetch_action> and C<pre_save_action> rules for the
given class.

B<from_utf>

Installed as C<post_fetch_action>. Translates all fields in the
configuration key C<utf_fields> from UTF.

B<to_utf>

Installed as C<pre_save_action>. Translates all fields in the
configuration key C<utf_fields> to UTF.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<utf8>

L<perlunicode>

=head1 COPYRIGHT

Copyright (c) 2001-2002 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

Andreas Nolte E<lt>andreas.nolte@bertelsmann.deE<gt>
