# BeePack

[![CI](https://github.com/cindustries/p5-beepack/actions/workflows/ci.yml/badge.svg)](https://github.com/cindustries/p5-beepack/actions/workflows/ci.yml)

Primitive MsgPack based key value storage.

## Description

**BeePack** was made out of the requirement to encapsulate small key values and
giant binary blobs into a compact file format for exchange and easy update even
with the low amount of memory available on a microcontroller.

Technically a BeePack is a [CDB](https://cr.yp.to/cdb.html) (constant database)
that additionally uses [MsgPack](https://msgpack.org/) to store the values inside
the CDB. MsgPack was picked for the inner storage so as not to reinvent the wheel
of storing interoperable values — for example a BeePack generated on an x86 Linux
machine while being read by an ARM microcontroller.

For simplification BeePack does **not** store several values for a key inside the
CDB, even though CDB is capable of it. By default BeePack treats a key that holds
a nil value as if it does not exist; this can be turned off with the `nil_exists`
attribute on `open`.

The MsgPack usage inside BeePack is likewise simplified by not allowing certain
types. Because it relies on [Data::MessagePack](https://metacpan.org/pod/Data::MessagePack),
this implementation still reads such types flawlessly, while the excluded types
are exactly the ones Data::MessagePack cannot produce anyway — so the Perl side
can never add them to a BeePack. The C implementation will be stricter on this.

The distribution also ships [`bee`](bin/bee), a small command-line tool to read,
generate and manipulate BeePack files.

## Installation

```sh
cpanm BeePack
```

The storage backend is [CDB_File](https://metacpan.org/pod/CDB_File), which
carries its own constant-database implementation — there is no system `libcdb`
dependency, a plain `cpanm` install is enough.

## Synopsis

```perl
use BeePack;

# read only opening, error if fail
my $beepack_ro = BeePack->open('my.bee');
# read/write opening (with temp file), create if missing
my $beepack_rw = BeePack->open('my.bee', 'my.bee.'.$$);
# read only opening with nil_exists set
my $beepack_ro = BeePack->open('my.bee', undef, nil_exists => 1 );

$beepack_rw->set( key => $value ); # overwrite value

$beepack_rw->set_integer( key => $value );   # force integer
$beepack_rw->set_type( key => i => $value ); # alternative way
$beepack_rw->set_bool( key => $value );      # force bool
$beepack_rw->set_type( key => b => $value ); # alternative way
$beepack_rw->set_string( key => $value );    # force stringification
$beepack_rw->set_type( key => s => $value ); # alternative way
$beepack_rw->set_nil( 'key' );       # set nil value
$beepack_rw->set_type( key => 'n' ); # alternative way

# array of 2 true bool
$beepack_rw->set( key => [
  BeePack->true, BeePack->true,
]);

# hash with true and false bool
$beepack_rw->set( key => {
  false => BeePack->false,
  true => BeePack->true,
});

$beepack_rw->save; # save changes and reopen

my $value = $beepack_ro->get('key');

# getting the raw msgpack bytes
my $msgpack = $beepack_ro->get_raw('key');
```

## The `bee` command-line tool

```sh
# show keys
$ bee test.bee

# get key
# integer displays as ascii numbers
# bool displays as true or false
# nil value is not displayed
# arrays and hashs are displayed as Data::Dumper dump
$ bee test.bee key

# sample complex key, no need for escaping
$ bee test.bee web#img/background.jpg#content

# get is transparent on string
$ bee test.bee gzipped_value | gunzip -c

# set key to nil
$ bee test.bee key n

# set bool key
$ bee test.bee key b 0

# set integer key
$ bee test.bee key i 123

# set string key
$ bee test.bee key s "This is a test"

# set array key
$ bee test.bee key a "Peter Parker" "Bruce Banner" "Clark Jerome Kent"

# set hash key
$ bee test.bee key h \
  spiderman "Peter Parker" \
  hulk "Bruce Banner" \
  superman "Clark Jerome Kent"
```

## See also

- [CDB_File](https://metacpan.org/pod/CDB_File)
- [Data::MessagePack](https://metacpan.org/pod/Data::MessagePack)

## Copyright and license

This software is copyright (c) 2014-2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.
