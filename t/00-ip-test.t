use v6.c;
use Test;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::IP;

my @TESTS := (
    { ip => '1.2.3.4', val => 16909060 },
);

for @TESTS -> $test {
    is ipv4-to-int($test<ip>), $test<val>, "$test<ip> ipv4-to-int";
    is int-to-ipv4($test<val>), $test<ip>, "$test<ip> int-to-ipv4";
    is int-to-ipv4(ipv4-to-int($test<ip>)), $test<ip>, "$test<ip> ipv4-to-int-to-ipv4";
    is ipv4-to-int(int-to-ipv4($test<val>)), $test<val>, "$test<ip> int-to-ipv4-to-int";
}

done-testing;

