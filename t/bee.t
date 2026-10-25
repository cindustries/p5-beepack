#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw( tempdir );
use File::Spec;
use IPC::Open3;
use Symbol qw( gensym );
use Cwd qw( getcwd );

use BeePack;

my $bee_bin = File::Spec->rel2abs('bin/bee');
my $lib = File::Spec->rel2abs('lib');
plan skip_all => 'bin/bee not found' unless -f $bee_bin;

sub bee {
  my ( @args ) = @_;
  my $err = gensym;
  my $pid = open3( my $in, my $out, $err, $^X, "-I$lib", $bee_bin, @args );
  close $in;
  my $stdout = do { local $/; <$out> };
  my $stderr = do { local $/; <$err> };
  waitpid $pid, 0;
  return ( $stdout // '', $stderr // '', $? >> 8 );
}

sub dumped {
  my ( $text ) = @_;
  my $VAR1;
  eval $text; ## no critic
  return $VAR1;
}

# under the working directory, not the system temp dir: on a machine where
# /tmp is its own mount this is another filesystem than a tmpnam() file
my $dir = tempdir( 'beetest-XXXXXX', DIR => getcwd(), CLEANUP => 1 );
my $db = "$dir/test.bee";

# write each type through the command line
my %write = (
  nil    => [ n => () ],
  int    => [ i => 123 ],
  string => [ s => '0042' ],
  bool_t => [ b => 1 ],
  bool_f => [ b => 0 ],
  array  => [ a => qw( Peter Bruce Clark ) ],
  hash   => [ h => qw( spiderman Peter hulk Bruce ) ],
);
for my $key ( sort keys %write ) {
  my ( $out, $err, $exit ) = bee( $db, $key, @{$write{$key}} );
  is( $exit, 0, "bee sets $key on a file outside the system temp dir" ) or diag $err;
}
is_deeply( [ sort grep { !/^\.\.?$/ } map { s{.*/}{}r } glob "$dir/*" ], ['test.bee'],
  'no temp file left next to the target' );

# list keys
{
  my ( $out, $err, $exit ) = bee($db);
  is( $exit, 0, 'bee FILE lists keys' );
  is_deeply( [ sort split /\n/, $out ], [ sort keys %write ], 'all keys listed' );
}

# read scalars, arrays, hashes
is( ( bee( $db, 'int' ) )[0], '123', 'get integer prints ascii number' );
is( ( bee( $db, 'string' ) )[0], '0042', 'get string keeps leading zeros' );
is( ( bee( $db, 'nil' ) )[0], '', 'get nil prints nothing' );
is( ( bee( $db, 'missing' ) )[0], '', 'get missing key prints nothing' );
is_deeply( dumped( ( bee( $db, 'array' ) )[0] ), [qw( Peter Bruce Clark )], 'get array prints Dumper' );
is_deeply( dumped( ( bee( $db, 'hash' ) )[0] ), { spiderman => 'Peter', hulk => 'Bruce' }, 'get hash prints Dumper' );

# the CLI type dispatch has to stay in sync with set_type: the bytes bee
# wrote are the bytes set_type packs for the same letter and values
{
  my $ro = BeePack->open($db);
  my $mem = BeePack->open( "$dir/mem.bee", "$dir/mem.tmp" );
  my %cases = (
    nil    => [ n => undef ],
    int    => [ i => '123' ],
    string => [ s => '0042' ],
    bool_t => [ b => 1 ],
    bool_f => [ b => 0 ],
    array  => [ a => [qw( Peter Bruce Clark )] ],
    hash   => [ h => { spiderman => 'Peter', hulk => 'Bruce' } ],
  );
  for my $key ( sort keys %cases ) {
    $mem->set_type( $key, @{$cases{$key}} );
    is( $ro->get_raw($key), $mem->get_raw($key), "bee type $cases{$key}[0] packs like set_type" );
  }
}

# overwrite keeps the other keys
{
  bee( $db, 'int', 'i', 456 );
  is( ( bee( $db, 'int' ) )[0], '456', 'bee overwrites a key' );
  is( ( bee( $db, 'string' ) )[0], '0042', 'other keys survive an overwrite' );
}

# both sides reject what they do not know
{
  my ( $out, $err, $exit ) = bee( $db, 'k', 'x', 'v' );
  isnt( $exit, 0, 'bee fails on an unknown type' );
  like( $err, qr/Unknown type x/, 'bee names the unknown type' );
  my $mem = BeePack->open( "$dir/mem.bee", "$dir/mem.tmp" );
  eval { $mem->set_type( k => x => 'v' ) };
  like( $@, qr/Unknown type x/, 'set_type rejects it the same way' );
}

# argument checks
{
  my ( undef, $err, $exit ) = bee( $db, 'n', 'n', 'value' );
  isnt( $exit, 0, 'nil with a value fails' );
  ( undef, $err, $exit ) = bee( $db, 'h', 'h', 'odd' );
  isnt( $exit, 0, 'hash with an odd count fails' );
}

done_testing;
