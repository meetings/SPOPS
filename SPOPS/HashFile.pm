package SPOPS::TieFileHash;

# $Id: HashFile.pm,v 1.11 2000/11/18 21:09:05 cwinters Exp $

use strict;

@SPOPS::TieFileHash::ISA       = ();
$SPOPS::TieFileHash::VERSION   = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

# These are all very standard routines for a tied hash; more info: see
# 'perldoc Tie::Hash'

# Ensure that the file exists and can be read (unless they pass in
# 'new' for the permissions, which means it's ok to start out with
# blank data); store the meta info (permission and filename) in the
# object, and the 'data' key holds the actual information
sub TIEHASH {
 my $class = shift;
 my ( $filename, $perm ) = @_;
 $perm ||= 'read';
 die "Valid permissions: read | write | new (Value: $perm)\n" if ( $perm !~ /^(read|write|new)$/ );
 unless ( $filename ) {
   die "You must pass a filename to use for reading and writing.\n";
 }
 my $file_exists = 0;
 $file_exists++  if ( -f $filename );
 if ( $perm ne 'new' and ! $file_exists ) {
   die "Cannot create object without existing file or 'new' permission (File: $filename)\n";
 }
 my $data = undef;
 if ( $file_exists ) {
   open( PD, $filename ) || die "Cannot open ($filename). Reason: $!";
   local $/ = undef;
   my $info = <PD>;
   close( PD );

   # Note that we create the SIG{__WARN__} handler here to trap any
   # messages that might be sent to STDERR; we want to capture the
   # message and send it along in a 'die' instead
   {
     local $SIG{__WARN__} = sub { return undef };
     no strict 'vars';
     $data = eval $info;
   }
   die "Error reading in perl code: $@"  if ( $@ );
 }
 else {
   $data = {};
   $perm = 'write';
 }
 return bless( { data     => $data,
                 filename => $filename,
                 perm     => $perm }, $class );
}

sub FETCH  { my ( $self, $key ) = @_; return $self->{data}->{ $key }; }

sub STORE  { my ( $self, $key, $value ) = @_; return $self->{data}->{ $key } = $value; }

sub EXISTS { my ( $self, $key ) = @_;  return exists $self->{data}->{ $key }; }

sub DELETE { my ( $self, $key ) = @_; return delete $self->{data}->{ $key }; }

# This allows people to do '%{ $obj } = ();' and remove the object;
# is this too easy to mistakenly do? I don't think so.
sub CLEAR {
 my ( $self ) = @_;
 die "Cannot remove $self->{filename}; permission set to read-only.\n" if ( $self->{perm} ne 'write' );
 unlink( $self->{filename} ) 
       || die "Cannot remove file $self->{filename}. Reason: $!";
 $self->{data} = undef;
 $self->{perm} = undef;
}

sub FIRSTKEY {
 my ( $self ) = @_;
 keys %{ $self->{data} };
 my $first_key = each %{ $self->{data} };
 return undef unless ( $first_key );
 return $first_key;
}

sub NEXTKEY {
 my ( $self ) = @_;
 my $next_key = each %{ $self->{data} };
 return undef unless ( $next_key );
 return $next_key;
}

1;





package SPOPS::HashFile;

use strict;
use SPOPS;
use Data::Dumper;

@SPOPS::HashFile::ISA       = qw( SPOPS );
$SPOPS::HashFile::VERSION   = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

# Just grab the tied hash from the package above
sub new {
 my $pkg   = shift;
 my $class = ref $pkg || $pkg;
 my $p     = shift;
 my ( %data );
 my $int = tie %data, 'SPOPS::TieFileHash', $p->{filename}, $p->{perm};
 return bless( \%data, $class );
}

# Just pass on the parameters to 'new'
sub fetch {
 my ( $class, $filename, $p ) = @_;
 $p ||= {};
 return $class->new( { filename => $filename, %{ $p } } );
}

# Ensure we can write and that the filename is kosher, then
# dump out the data to the file.
sub save {
 my $self = shift;
 my $p    = shift;
 my $obj = tied %{ $self };
 unless ( $obj->{perm} eq 'write' ) {
   die "Cannot save $obj->{filename}: it was opened as read-only.\n";
 }
 unless ( $obj->{filename} ) {
   die "Cannot save data: the filename has been erased. Did you assign an empty hash to the object?\n";
 }
 if ( -f $obj->{filename} ) {
   rename( $obj->{filename}, "$obj->{filename}.old" ) 
         || die "Cannot rename old file to make room for new one. Error: $!";
 }
 my %data = %{ $obj->{data} };
 $p->{dumper_level} ||= 2;
 local $Data::Dumper::Indent = $p->{dumper_level};
 my $string = Data::Dumper->Dump( [ \%data ], [ 'data' ] ); 
 eval { open( INFO, "> $obj->{filename}" ) || die $! };
 if ( $@ ) {
   rename( "$obj->{filename}.old", $obj->{filename} ) 
         || die "Cannot open file for writing (reason: $@ ) and ",
                "cannot move backup file to original place. Reason: $!";
   die "Cannot open file for writing. Backup file restored. Error: $@";
 }
 print INFO $string;
 close( INFO );
 if ( -f "$obj->{filename}.old" ) {
   unlink( "$obj->{filename}.old" ) 
         || warn "Cannot remove the old data file. It still lingers in $obj->{filename}.old....\n";
 }
 return 1;
}

sub remove {
 my $self = shift;
 my $p    = shift;
 my $obj = tied %{ $self };
 unless ( $obj->{perm} eq 'write' ) {
   die "Cannot save $obj->{filename}: it was opened as read-only.\n";
 }
 unless ( $obj->{filename} ) {
   die "Cannot save data: the filename has been erased. Did you assign an empty hash to the object?\n";
 }
 return %{ $self } = ();
}

# Create a new object from an old one, allowing any passed-in
# values to override the ones from the old object
sub clone {
 my $self = shift;
 my $p    = shift;
 $p->{filename} ||= tied %{ $self }->{filename};
 my $new = $self->new( { filename => $p->{filename}, perm => $p->{perm} } ); 
 while ( my ( $k, $v ) = each %{ $self } ) {
   $new->{ $k } = $p->{ $k } || $v;
 }
 return $new;
}


1;

__END__

=pod

=head1 NAME

SPOPS::HashFile - Implement as objects files containing perl hashrefs
dumped to text

=head1 SYNOPSIS

 my $config = SPOPS::HashFile->new( { filename => '/home/httpd/myapp/server.perl',
                                      perm => 'read' } );
 print "My SMTP host is $config->{smtp_host}";

 # Setting a different value is ok...
 $config->{smtp_host} = 'smtp.microsoft.com';

 # ...but this will 'die' with an error, since you set the permission
 # to read-only 'read' in the 'new' call
 $config->save;

=head1 DESCRIPTION

Implement a simple interface that allows you to use a perl data
structure dumped to disk as an object. This is often used for
configuration files, since the key/value, and the flexibility of the
'value' part of the equation, maps well to varied configuration
directives.

=head1 METHODS

B<new( { filename =E<gt> $, [ perm =E<gt> $ ] } )>

Create a new C<SPOPS::HashFile> object that uses the given filename
and, optionally, the given permission. The permission can be one of
three values: 'read', 'write' or 'new'. If you try to create a new
object without passing the 'new' permission, the action will die
because it cannot find a filename to open. Any value passed in that is
not 'read', 'write' or 'new' will get changed to 'read', and if no
value is passed in it will also be 'read'.

Note that the 'new' permission does B<not> mean that a new file will
overwrite an existing file automatically. It simply means that a new
file will be created if one does not already exist; if one does exist,
it will be used.

The 'read' permission only forbids you from saving the object or
removing it entirely. You can still make modifications to the data in
the object.

This overrides the I<new()> method from SPOPS.

B<fetch( $filename, [ { perm =E<gt> $ } ] )>

Retrieve an existing config object (just a perl hashref data
structure) from a file. The action will result in a 'die' if you do
not pass a filename, if the file does not exist or for any reason you
cannot open it.

B<save>

Saves the object to the file you read it from.

B<remove>

Deletes the file you read the object from, and blanks out all data in
the object.

B<clone( { filename =E<gt> $, [ perm =E<gt> $ ] } )> 

Create a new object from the old, but you can change the filename and
permission at the same time. Example:

 my $config = SPOPS::HashFile->new( { filename => '~/myapp/spops.perl' } );
 my $new_config = $config->clone( { filename => '~/otherapp/spops.perl',
                                    perm => 'write' } );
 $new_config->{base_dir} = '~/otherapp/spops.perl';
 $new_config->save;

This overrides the I<clone()> method from SPOPS.

=head1 NOTES

B<No use of SPOPS::Tie>

This is one of the few SPOPS implementations that will never use the
C<SPOPS::Tie> class to implement its data holding. We still use a tied
hash, but it is much simpler -- no field checking, no ensuring that
the keys match in case, etc. This just stores some information about
the object (filename, permission, and data) and lets you go on your
merry way.

=head1 TO DO

=head1 BUGS

=head1 SEE ALSO

=head1 COPYRIGHT

Copyright (c) 2000 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>


=cut
