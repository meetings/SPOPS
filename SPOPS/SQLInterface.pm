package SPOPS::SQLInterface;

# $Header: /usr/local/cvsdocs/SPOPS/SPOPS/SQLInterface.pm,v 1.32 2000/10/27 12:49:27 cwinters Exp $

use strict;
use Carp         qw( carp );
use Data::Dumper qw( Dumper );
use DBI          ();

@SPOPS::SQLInterface::ISA     = ();
$SPOPS::SQLInterface::VERSION = sprintf("%d.%02d", q$Revision: 1.32 $ =~ /(\d+)\.(\d+)/);

use constant DEBUG            => 0;
use constant DEBUG_SELECT     => 0;
use constant DEBUG_INSERT     => 0;
use constant DEBUG_UPDATE     => 0;
use constant DEBUG_DELETE     => 0;

my %TYPE_INFO = ();

my %FAKE_TYPES = (
 'int'   => DBI::SQL_INTEGER(),
 'num'   => DBI::SQL_NUMERIC(), 
 'float' => DBI::SQL_FLOAT(),
 'char'  => DBI::SQL_VARCHAR(), 
 'date'  => DBI::SQL_DATE(),
);

sub sql_quote {
 my $class = shift;
 my $value = shift;
 my $type  = shift;
 my $db    = shift || $class->global_db_handle;
 return $db->quote( $value );
}

# Note: not sure how to integrate the fieldtype discovery
# stuff in here. What if you do:
#
# select u.username from users u, logins l 
#  where l.login_date > ?  and 
#        l.user_id = u.user_id
#
# and pass '2000/1/13' is passed in? This seems to be a little
# too much in-depth sql processing than this library is 
# appropriate for; so you can still pass in values for binding,
# but they'll all be bound with SQL_VARCHAR
#
# select   => \@ of fields to select
# select_modifier => $ to insert between 'SELECT' and fields (e.g., DISTINCT)
# from     => \@ of tables to select from
# order    => $ clause to order by
# where    => $ clause to limit results
# return   => single | list | hash | single-list
# value    => \@ of values to bind, all as SQL_VARCHAR; they must match order of '?' in where
# sql      => $ statement to execute
sub db_select {
 my $class = shift;
 my $p     = shift;

 my $DEBUG = DEBUG_SELECT || $p->{DEBUG} || 0;
 my $db    = $p->{db} || $class->global_db_handle;

 $p->{from} ||= $p->{table}; # allow an alias

 # Don't do anything if the SQL isn't passed in and you don't have
 # either a list of fields to select or a table to select them from
 if ( ! $p->{sql} and ( ! $p->{select} or ! $p->{from} ) ) {
   my $msg = 'SELECT failed';
   SPOPS::Error->set( { user_msg => $msg, type => 'db', 
                        system_msg => 'Cannot run db_select without select/from statements!' } );
   die $msg;
 }
 warn " (db_select): Entering db_select with ", Dumper( $p ), "\n"         if ( $DEBUG > 1 );
 $p->{return} ||= 'list';
 $p->{value}  ||= [];
 my $sql = $p->{sql};

 # If we don't have any SQL, build it (straightforward).
 if ( ! $sql ) {
   warn " (db_select): No SQL passed in to execute directly; building.\n"  if ( $DEBUG );
   $p->{select_modifier} ||= '';
   my $select = join ', ', @{ $p->{select} };
   my $from   = join ', ', @{ $p->{from} };
   my $order  = ( $p->{order} ) ? "ORDER BY $p->{order}" : '';
   my $where  = ( $p->{where} ) ? "WHERE $p->{where}" : '';
   $sql = qq/
     SELECT $p->{select_modifier} $select
       FROM $from
      $where
      $order
   /;
 }
 warn " (db_select): SQL for select: $sql\n"                               if ( $DEBUG );

 # First prepare and check for errors...
 my ( $sth );
 eval { $sth = $db->prepare( $sql ); };
 if ( $@ ) {
   my $msg = 'SELECT failed; cannot retrieve records';
   SPOPS::Error->set( { user_msg => $msg, type => 'db',
                        system_msg => "Prepare failed. Error: $@", 
                        extra => { sql => $sql } } );
   die $msg;
 }

 # If they asked for the handle back, give it to them
 return $sth if ( $p->{return} eq 'sth' );

 # Execute with any bound parameters; note that for Sybase you do 
 # not need to pass any types at all.
 warn " (db_select): Values bound: ", join( '//', @{ $p->{value} } ), "\n" if ( $DEBUG );
 eval { $sth->execute( @{ $p->{value} } ); };
 if ( $@ ) {
   my $msg = 'SELECT failed; cannot retrieve records';
   SPOPS::Error->set( { user_msg => $msg, type => 'db',
                        system_msg => "Execute of SELECT failed. Error: $@", 
                        extra => { sql => $sql, value => @{ $p->{value} } } } );
   die $msg;
 }

 # If they asked for a single row, return it in arrayref format [ field1, field2, ...] 
 if ( $p->{return} eq 'single' ) {
   warn " (db_select): Returning single row.\n"                            if ( $DEBUG );
   my $row =  eval { $sth->fetchrow_arrayref; };
   if ( $@ ) {
     my $msg = 'Fetch failed; cannot retrieve single record';
     SPOPS::Error->set( { user_msg => $msg, type => 'db',
                          system_msg => "Cannot fetch record. Error: $@", 
                          extra => { sql => $sql, value => @{ $p->{value} } } } );
     die $msg;
   }
   return $row;
 }

 # If they asked for a list of results, return an arrayref of arrayrefs
 elsif ( $p->{return} eq 'list' ) {
   warn " (db_select): Returning list of lists.\n"                         if ( $DEBUG );
   my $rows = eval { $sth->fetchall_arrayref; };
   if ( $@ ) {
     my $msg = 'Fetch failed; cannot retrieve multiple records';
     SPOPS::Error->set( { user_msg => $msg, type => 'db',
                          system_msg => "Cannot fetch multiple records. Error: $@", 
                          extra => { sql => $sql, value => @{ $p->{value} } } } );
     die $msg;
   }
   return $rows;
 }

 # return the first element of each record in an arrayref
 elsif ( $p->{return} eq 'single-list' ) {
   warn " (db_select): Returning list of single items.\n"                  if ( $DEBUG );
   my $rows = eval { $sth->fetchall_arrayref };
   if ( $@ ) {
     my $msg = 'Fetch failed; cannot retrieve multiple records';
     SPOPS::Error->set( { user_msg => $msg, type => 'db',
                          system_msg => "Cannot fetch multiple records. Error: $@", 
                          extra => { sql => $sql, value => @{ $p->{value} } } } );
     warn ">> Failure to fetch: $msg;\n$@\n";
     die $msg;
   }
   return [ map { $_->[0] } @{ $rows } ];
 }

 # If they asked for a hash, return a list of hashrefs
 elsif ( $p->{return} eq 'hash' ) {
   warn " (db_select): Returning list of hashrefs.\n"                      if ( $DEBUG );
   my @rows = ();

   # Note -- we may need to change this to 
   # zip through $row every time and push a 
   # new reference onto @rows
   eval {
     while ( my $row = $sth->fetchrow_hashref ) {
       push @rows, \%{ $row };
     }
     return \@rows;
   };
   if ( $@ ) {
     my $msg = 'Fetch failed; cannot retrieve multiple records';
     SPOPS::Error->set( { user_msg => $msg, type => 'db',
                          system_msg => "Cannot fetch multiple records as hashrefs. Error: $@", 
                          extra => { sql => $sql, value => @{ $p->{value} } } } );
     die $msg;
   }
 }
 return [];
}

# field    => \@ of fieldnames
# value    => \@ of values
# table    => $ of table to insert into
# no_quote => \% of fields not to quote
# sql      => $ of sql to run
# return_sth => $ if true, return the statement handle rather than status
sub db_insert {
 my $class = shift;
 my $p     = shift;
 
 my $DEBUG   = DEBUG_INSERT || $p->{DEBUG} || 0;
 my $db    = $p->{db} || $class->global_db_handle;
 warn " (db_insert): Enter insert procedure\n", Dumper( $p ), "\n"         if ( $DEBUG > 1 );

 # If we weren't given direct sql or a list of values or table, bail
 if ( ! $p->{sql} and ( ! $p->{value} or ! $p->{table} ) ) {
   my $msg = 'INSERT failed';
   SPOPS::Error->set( { user_msg => $msg, type => 'db', 
                        system_msg => 'Cannot continue with no SQL, values or table name' } );
   die $msg;
 }

 # Find the types for all fields in this table (we don't
 # have to use them all...)
 # Let any errors trickle up
 my $type_info = $class->db_discover_types( $p->{table}, { dbi_type_info => $p->{dbi_type_info},
                                                           db => $db } );
 my $sql = $p->{sql};

 # If we weren't given SQL, build it.
 if ( ! $sql ) {
   my ( $fields, $values );

   # Be sure this is at least an empty hashref, otherwise we 
   # might get an error
   $p->{no_quote} ||= {};
   $p->{field}    ||= [];
   $p->{value}    ||= [];
   warn " (db_select): fields/values: ", Dumper( $p->{field}, $p->{value} ), "\n" if ( $DEBUG > 1 );
  
   # Cycle through the fields and values, creating lists
   # suitable for join()ing into the SQL statement.
   my @value_list = ();
   my $count = 0;
   foreach my $field ( @{ $p->{field} } ) {
	 warn " (db_insert): Trying to add value <<$p->{value}->[$count]>> with field <<$field>> \n",
          "              and type info <<$type_info->{ $field }>>\n"       if ( $DEBUG );

	 # Quote the value unless the user asked us not to
	 my $value = ( $p->{no_quote}->{ $field } ) 
                   ? $p->{value}->[ $count ]
                   : $class->sql_quote( $p->{value}->[ $count ], $type_info->{ $field }, $db );
	 push @value_list, $value;
	 $count++;
   }

   my $field_listing = join ', ', @{ $p->{field} };
   my $value_listing = join ', ', @value_list;
   $sql = qq/
     INSERT INTO $p->{table}
     ( $field_listing )
     VALUES
     ( $value_listing )
   /;
 }

 # Note that we use the prepare()/execute() method of
 # getting this data in rather than the simpler do(),
 # since the user might want the statement handle afterward;
 # if this becomes a performance hang (doubtful), we can only
 # do p/e if the user's asked for the statement handle
 warn " (db_insert): Preparing\n$sql\n"                                    if ( $DEBUG );
 my ( $sth );
 eval { 
   $sth = $db->prepare( $sql );
   $sth->execute;
 };
 if ( $@ ) {
   my $msg = 'INSERT failed; cannot create new record';
   SPOPS::Error->set( { user_msg => $msg, type => 'db',
                        system_msg => "Error: $@", 
                        extra => { sql => $sql } } );
   die $msg;
 }
 warn " (db_insert): Prepare/execute went ok.\n"                           if ( $DEBUG );

 # Everything is ok; return either a true value
 # or the statement handle, if they've asked for it.
 return $sth   if ( $p->{return_sth} );
 return 1;
}

# field    => \@ of fieldnames
# value    => \@ of values
# table    => $ of table to insert into
# where    => $ clause for which we're updating
# no_quote => \% of fields not to quote
# sql      => $ of sql to run
sub db_update {
 my $class = shift;
 my $p     = shift;

 my $DEBUG   = DEBUG_UPDATE || $p->{DEBUG} || 0;
 my $db    = $p->{db} || $class->global_db_handle;

 # If we weren't given direct sql or a list of values or table, bail
 if ( ! $p->{sql} and ( ! $p->{value} or ! $p->{table} ) ) {
   my $msg = 'UPDATE failed';
   SPOPS::Error->set( { user_msg => $msg, type => 'db', 
                        system_msg => 'Cannot continue with no SQL, values or table name' } );
   die $msg;
 } 
 my $sql = $p->{sql};

 # Find the types for all fields in this table (we don't
 # have to use them all...)
 # Let the error trickle up
 my $type_info = $class->db_discover_types( $p->{table}, { dbi_type_info => $p->{dbi_type_info},
                                                           db => $db } );

 # Build the SQL
 if ( ! $sql ) {
   my ( @update );
   my @values = ();
   
   # Go through each field and setup an update assign subset
   # for each; most of them get a bound parameter and push the
   # value onto the stack, but values that cannot be bound push
   # the direct information onto the stack.
   my $count  = 0;
   $p->{no_quote} ||= {};
   foreach my $field ( @{ $p->{field} } ) {
	 warn " (db_update): Trying to add value <<$p->{value}->[$count]>> with field <<$field>> \n",
          "              and type info <<$type_info->{ $field }>>\n"       if ( $DEBUG );

	 # Quote the value unless the user asked us not to
	 my $value = ( $p->{no_quote}->{ $field } ) 
                   ? $p->{value}->[ $count ]
                   : $class->sql_quote( $p->{value}->[ $count ], $type_info->{ $field }, $db );
	 push @update, "$field = $value";
	 $count++;
   }
   my $update = join ', ', @update;
   my $where  = ( $p->{where} ) ? "WHERE $p->{where}" : '';
   $sql = qq/
     UPDATE $p->{table}
        SET $update
      $where
   /;
 }
 warn " (db_update): Prepare/execute\n$sql\n"                              if ( $DEBUG );
 my ( $sth );
 eval {
   $sth = $db->prepare( $sql );
   $sth->execute; 
 };
 if ( $@ ) {
   my $msg = 'UPDATE failed';
   SPOPS::Error->set( { user_msg => $msg, type => 'db',
                        system_msg => "Error: $@", 
                        extra => { sql => $sql } } );
   die $msg;
 }

 # Return true if successful
 return 1;
}

# table  => $ of table we're deleting from
# where  => $ limiting our deletes
# value  => \@ of values to bind
# sql    => $ of statement to execute directly
sub db_delete {
 my $class = shift;
 my $p     = shift;

 my $DEBUG   = DEBUG_DELETE || $p->{DEBUG} || 0;
 my $db    = $p->{db} || $class->global_db_handle;

 # Gotta have a table to delete from
 unless ( $p->{table} or $p->{sql} ) {
   my $msg = 'DELETE failed';
   SPOPS::Error->set( { user_msg => $msg, type => 'db', 
                        system_msg => 'Cannot delete records without SQL or a table name' } );
   die $msg;
 }

 # If we weren't given SQL, build it.
 my $sql = $p->{sql};
 unless ( $sql ) {
   
   # Hopefully you'll have a WHERE clause... but we'll let
   # you shoot yourself in the foot if you forget :)
   my $where = ( $p->{where} ) ? "WHERE $p->{where}" : '';
   $sql = qq/
	 DELETE FROM $p->{table}
      $where
   /;
 }
 warn " (db_delete): SQL for DELETE:\n$sql\n"                              if  ( $DEBUG );
 $p->{value} ||= [];
 my ( $sth );
 eval {
   $sth = $db->prepare( $sql );
   $sth->execute( @{ $p->{value} } );
 };
 if ( $@ ) { 
   my $msg = 'DELETE failed; cannot remove records';
   SPOPS::Error->set( { user_msg => $msg, type => 'db',
                        system_msg => "Execute of DELETE failed. Error: $@", 
                        extra => { sql => $sql, value => @{ $p->{value} } } } );
   die $msg;
 }
 return 1;
}

sub db_discover_types {
 my $class = shift;
 my $table = shift;
 my $p     = shift;

 my $DEBUG   = DEBUG || $p->{DEBUG} || 0;

 # Create the index used to find the table info later
 my $db    = $p->{db} || $class->global_db_handle;
 my $type_idx = join '-', lc $db->{Name}, $table;

 # If we've already discovered the types, get the cached copy
 return $TYPE_INFO{ $type_idx } if ( $TYPE_INFO{ $type_idx } );

 # Certain databases (or more specifically, DBD drivers) do
 # not process $sth->{TYPE} requests properly, so we need the
 # user to specify the types by hand (see assign_dbi_type_info() below)
 my $ti = $p->{dbi_type_info};
 if ( my $conf = eval { $class->CONFIG } ) {
   $ti = $conf->{dbi_type_info};
 }
 if ( $ti ) {
   warn " (db_discover_types): Class has type information specified\n"     if ( DEBUG );
   my $dbi_info = $class->assign_dbi_type_info( $ti )  unless ( $ti->{_dbi_assigned} );
   foreach my $field ( keys %{ $dbi_info } ) {
     warn " (db_discover_types): Set $field: $dbi_info->{ $field }\n"            if ( DEBUG );
     $TYPE_INFO{ $type_idx }->{ $field } = $dbi_info->{ $field };
   }
   return $TYPE_INFO{ $type_idx };
 }

 # Other statement necessary to get type info from the db? Let the 
 # class take care of it.
 my $sql = $class->sql_fetch_types( $table );
 my ( $sth );
 eval {
   $sth = $db->prepare( $sql );
   $sth->execute;
 };
 if ( $@ ) {
   my $msg = 'Data-type discovery failed';
   SPOPS::Error->set( { user_msg => $msg, type => 'db',
                        system_msg => "Error: $@", 
                        extra => { sql => $sql } } );
   carp " (db_discover_types): Failed to read data types: $@";
   die $msg;
 }

 # Go through the fields and match them up to types; note that
 # %TYPE_INFO is a package lexical, so all routines (db_insert,
 # db_update, etc.) should have access to it.
 my $fields = $sth->{NAME};
 my $types  = $sth->{TYPE};
 warn " (DB): List of fields: ", join( ", ", @{ $fields } ), "\n"          if ( $DEBUG );
 for ( my $i = 0; $i < scalar @{ $fields }; $i++ ) {
   $TYPE_INFO{ $type_idx }->{ $fields->[ $i ] } = $types->[ $i ];
 }
 return $TYPE_INFO{ $type_idx };
}

sub assign_dbi_type_info {
 my $class    = shift;
 my $user_info = shift;
 my $dbi_info = {};
 foreach my $field ( keys %{ $user_info } ) {
   warn " (assign_dbi_type_info): Field $field is $user_info->{ $field }\n" if ( DEBUG );
   $dbi_info->{ $field } = $FAKE_TYPES{ $user_info->{ $field } };
 }
 $user_info->{_dbi_assigned}++;
 return $dbi_info;
}

# Default data type discovery statement
sub sql_fetch_types { return "SELECT * FROM $_[1] where 1 = 0" }

1;

__END__

=pod

=head1 NAME

SPOPS::SQLInterface - Generic routines for DBI database interaction

=head1 SYNOPSIS

 # Make this class a parent of my class
 package My::DBIStuff;
 use SPOPS::SQLInterface;
 @My::DBIStuff::ISA = qw( SPOPS::SQLInterface );

 # You should also be able to use it directly, but you
 # need to pass in a database handler with every request
 use SPOPS::SQLInterface;
 my $dbc = 'SPOPS::SQLInterface';
 my $db = DBI->connect( ... ) || die $DBI::errstr;
 my $rows = $dbc->db_select( { select => [ qw/ uid first_name last_name / ],
                               from   => [ 'users' ],
                               where  => 'first_name = ? or last_name = ?',
                               value  => [ 'fozzie', "th' bear" ],
                               db     => $db } );
 foreach my $row ( @{ $results } ) {
   print "User ID $row->[0] is $row->[1] $row->[2]\n";
 }

=head1 DESCRIPTION

You are meant to inherit from this class, although you can use it as a
standalone SQL abstraction tool as well, as long as you pass the
database handle into every routine you call.

=head1 DATABASE METHODS

Relatively simple (!) methods to do the select, update, delete and
insert statements, with the right values and table names being passed
in.

All parameters are passed in via named values, such as:

 $t->db_select( { select => [ 'this', 'that' ],
                  from => [ 'mytable' ] } );

B<VERY IMPORTANT>

The subclass that uses these methods must either pass in a DBI
database handle via a named parameter (B<db>) or make it available
through a method of the class called 'global_db_handle'.

=head1 METHODS

There are very few methods in this class, but each one can do quite a
bit.

=head2 db_select

Executes a SELECT. Return value depends on what you ask 
for. 

Parameters:

B<select> (\@)

Fields to select

B<select_modifier> ($)

Clause to insert between 'SELECT' and fields (e.g., DISTINCT)

B<from> (\@)

List of tables to select from

B<order> ($) 

Clause to order results by; if not given, the order depends
entirely on the database.

B<where> ($) 

Clause to limit results. Note that you can use '?' for 
field values but they will get quoted as if they were
a SQL_VARCHAR type of value.

B<return> ($)

B<list>: returns an arrayref of arrayrefs (default)

B<single>: returns a single arrayref

B<hash>: returns an arrayref of hashrefs

B<single-list>: returns an arrayref with the first value of each
record as the element.

B<value> (\@) 

List of values to bind, all as SQL_VARCHAR; they must match 
order of '?' in the where clause either passed in or 
within the SQL statement passed in.

B<sql> ($)

Full statement to execute, although you may put '?' in the
where clause and pass values for substitution. (No quoting
hassles...)

B<Examples>:

Perl statement:

 $t->db_select( { select => [ qw/ first_name last_name /],
                  from => [ 'users' ],
                  where => 'last_name LIKE ?',
                  value => 'moo%' } );

SQL statement:

 SELECT first_name, last_name
   FROM users
  WHERE last_name LIKE 'moo%'

Returns:

 [ [ 'stephen', 'moore' ],
   [ 'charles', 'mooron' ],
   [ 'stacy', 'moonshine' ] ]

Perl statement:

 $t->db_select( { select => [ qw/ u.username l.login_date / ],
                  from => [ 'users u', 'logins l' ],
                  where => "l.login_date > '2000-04-18' and u.uid = l.uid"
                  return => 'hash' } );

SQL statement:

 SELECT u.username, l.login_date
   FROM users u, logins l
  WHERE l.login_date > '2000-04-18' and u.uid = l.uid

Returns:

 [ { username => 'smoore',
     login_date => '2000-05-01' },
   { username => 'cmooron', 
     login_date => '2000-04-19' },
   { username => 'smoonshine',
     login_date => '2000-05-02' } ]

Perl statement:

 $t->db_select( { select => [ qw/ login_name first_name last_name /],
                  from => [ 'users' ],
                  where => 'last_name LIKE ?',
                  value => 'moo%', 
                  return => 'single-list' } );

SQL statement:

 SELECT login_name, first_name, last_name
   FROM users
  WHERE last_name LIKE 'moo%'

Returns:

 [ 'smoore',
   'cmooron',
   'smoonshine' ]


=head2 db_insert

Create and execute an INSERT statement given the 
parameters passed in.

Parameters:

B<table> ($)

Name of table to insert into

B<field> (\@) 

List of fieldnames to insert

B<value> (\@)

List of values, matching up with order of field list.

B<no_quote> (\%)

Fields that we should not quote

B<sql> ($)

Full SQL statement to run; you can still pass in values
to quote/bind if you use '?' in the statement.

B<return_sth> ($)

If true, return the statement handle rather than a status.

B<Examples>:

Perl statement:

 $t->db_insert( { table => 'users',
                  field => [ qw/ username first_name last_name password / ],
                  value => [ 'cmw817', "Chris O'Winters" ] } );

SQL statement:

 INSERT INTO users
 ( username, first_name, last_name, password )
 VALUES
 ( 'cmw817', 'Chris', 'O''Winters', NULL )

Perl statement:

 my $sql = qq/
   INSERT INTO users ( username ) VALUES ( ? )
 /;

 foreach my $username ( qw/ chuck stinky jackson / ) {
   $t->db_insert( { sql => $sql, value => [ $username ] } );
 }

SQL statements:

 INSERT INTO users ( username ) VALUES ( 'chuck' )
 INSERT INTO users ( username ) VALUES ( 'stinky' )
 INSERT INTO users ( username ) VALUES ( 'jackson' )

=head2 db_update

Create and execute an UPDATE statement given the 
parameters passed in.

Parameters:

B<field> (\@) 

List of fieldnames we are updating 

B<value> (\@) 

List of values corresponding to the fields we are
updating.

B<table> ($) 

Name of table we are updating

B<where> ($) 

Clause that specifies the rows we are updating

B<no_quote> (\%) 

Specify fields not to quote

B<sql> ($) 

Full SQL statement to run; note that you can use '?' for 
values and pass in the raw values via the 'value' parameter,
and they will be quoted as necessary.

B<Examples>:

Perl statement:

 $t->db_update( { field => [ qw/ first_name last_name / ],
                  value => [ 'Chris', "O'Donohue" ],
                  table => 'users',
                  where => 'user_id = 98172' } );

SQL statement:

 UPDATE users
    SET first_name = 'Chris',
        last_name = 'O''Donohue',
  WHERE user_id = 98172

=head2 db_delete 

Removes the record indicated by %params from the database.

Parameters:

B<table> ($) 

Name of table from which we are removing records.

B<where> ($) 

Specify the records we are removing

B<value> (\@) 

List of values to bind to '?' that may be found either in 
the where clause passed in or in the where clause found
in the SQL statement.

B<sql> ($) 

Full SQL statement to execute directly, although you can 
use '?' for values and pass the actual values in via the
'value' parameter.

Be careful: if you pass in the table but not the criteria,
you will clear out your table! (Just like real SQL...)

B<Examples>:

Perl statement:

 $t->db_delete( { table => 'users', where => 'user_id = 98172' } );

SQL statement:

 DELETE FROM users
  WHERE user_id = 98172

Perl statement:

 $t->db_delete( { table => 'users', where => 'last_name LIKE ?',
                  value => [ 'moo%' ] } );

SQL statement:

 DELETE FROM users
  WHERE last_name LIKE 'moo%'

Perl statement:

 $t->db_delete( { table => 'users' } );

SQL statement:

 DELETE FROM users

Oops, just cleared out the 'users' table. Be careful!

=head2 db_discover_types

Basically issue a dummy query to a particular table to get
its schema. We save the DBI type information in the %TYPE_INFO
lexical that all routines here can access. 

If a DBD driver does not support the {TYPE} attribute of the statement
handle, you have to specify some simple types in your class
configuration or provide them somehow. This is still slightly tied to
SPOPS implementations in OpenInteract, but only slightly.

Return a hashref of fieldnames as keys and DBI types as values.

Parameters:

B<table> ($)

The name of a particular table. Note that this routine is not
smart enough to distinguish between: B<users> and B<dbo.users> 
even though they might be the same table in the database. It is
not particularly harmful if you use the same name twice in 
this manner, the module just has to do a little extra work.

=head1 ERROR HANDLING

Like other classes in SPOPS, all errors encountered will result in the
error information saved in L<SPOPS::Error> and a die() being
thrown. (More later.)

=head1 TO DO

B<DBI binding conventions>

One of the things the DBI allows you to do is prepare a statement once
and then execute it many times. It would be nice to allow that
somehow.

=head1 BUGS

=head1 SEE ALSO

L<DBI>

=head1 COPYRIGHT

Copyright (c) 2000 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <cwinters@intes.net>

Rusty Foster <rusty@kuro5hin.org> was also influential in the early
days of this library.



=cut
