#!/usr/bin/perl
use Test::More tests => 3;

use_ok('RPSL::Parser');

my $class = 'RPSL::Parser';

can_ok $class, qw( new parse );

fail qw{ Failing test };

{   my $parser = new RPSL::Parser;
    isa_ok $parser, $class;
}

# vim: expandtab ts=4
