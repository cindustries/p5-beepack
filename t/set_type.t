#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw( tempdir );
use Data::MessagePack;

use BeePack;

my $dir = tempdir( CLEANUP => 1 );
my $bee = BeePack->open("$dir/db.bee", "$dir/db.tmp", nil_exists => 1);
my $mp = Data::MessagePack->new->canonical->utf8;

# set_type dispatches on the first character of the type, so a long type name
# must land on the same branch as the single letter
my @cases = (
  [ integer => 'i',       '23',  23 ],
  [ integer => 'integer', '23',  23 ],
  [ bool    => 'b',       1,     Data::MessagePack::true() ],
  [ bool    => 'bool',    0,     Data::MessagePack::false() ],
  [ string  => 's',       '042', '042' ],
  [ string  => 'string',  42,    '42' ],
  [ nil     => 'n',       'ignored', undef ],
  [ nil     => 'nil',     undef, undef ],
);
for my $case (@cases) {
  my ( $key, $type, $in, $expect ) = @{$case};
  $bee->set_type( $key, $type, $in );
  is( $bee->get_raw($key), $mp->pack($expect), "set_type $type packs $key as get_raw expects" );
}

$bee->set_type( int => i => '23' );
is( $bee->get_raw('int'), "\x17", 'integer 23 is the MsgPack positive fixint' );
$bee->set_type( yes => b => 1 );
is( $bee->get_raw('yes'), "\xc3", 'bool true is MsgPack 0xc3' );
$bee->set_type( no => b => 0 );
is( $bee->get_raw('no'), "\xc2", 'bool false is MsgPack 0xc2' );
$bee->set_type( nil => n => undef );
is( $bee->get_raw('nil'), "\xc0", 'nil is MsgPack 0xc0' );
$bee->set_type( str => s => 42 );
is( $bee->get_raw('str'), "\xa2" . '42', 'string 42 is a MsgPack fixstr, not an integer' );
is( $bee->get_raw('missing'), undef, 'get_raw of an absent key is undef' );

# array and hash must round-trip equal to the direct set() form
$bee->set_type( arr_t => a => [qw( 1 2 3 )] );
$bee->set( arr_d => [qw( 1 2 3 )] );
is( $bee->get_raw('arr_t'), $bee->get_raw('arr_d'), 'set_type array bytes equal set() bytes' );
is_deeply( $bee->get('arr_t'), [qw( 1 2 3 )], 'set_type array round-trips' );

$bee->set_type( hash_t => h => { a => 1, b => 2 } );
$bee->set( hash_d => { a => 1, b => 2 } );
is( $bee->get_raw('hash_t'), $bee->get_raw('hash_d'), 'set_type hash bytes equal set() bytes' );
is_deeply( $bee->get('hash_t'), { a => 1, b => 2 }, 'set_type hash round-trips' );

# empty and undefined type is a plain set()
$bee->set_type( plain_e => '', [ 1, 2 ] );
$bee->set_type( plain_u => undef, [ 1, 2 ] );
$bee->set( plain_d => [ 1, 2 ] );
is( $bee->get_raw('plain_e'), $bee->get_raw('plain_d'), 'empty type behaves as set()' );
is( $bee->get_raw('plain_u'), $bee->get_raw('plain_d'), 'undefined type behaves as set()' );

# the packed bytes survive save and a fresh read-only open
$bee->save;
my $ro = BeePack->open("$dir/db.bee");
is( $ro->get_raw('arr_t'), $bee->get_raw('arr_d'), 'array bytes survive save and reopen' );
is_deeply( $ro->get('hash_t'), { a => 1, b => 2 }, 'hash survives save and reopen' );

done_testing;
