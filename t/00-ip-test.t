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

my @TESTS6 := (
    {
        ip      => '2001:db8::1',
        full    => '2001:0db8:0000:0000:0000:0000:0000:0001',
        val     => 42540766411282592856903984951653826561,
        compact => '2001:db8::1',
    },
    {
        ip      => '2001:db8:0:2:3::1',
        full    => '2001:0db8:0000:0002:0003:0000:0000:0001',
        val     => 42540766411282592893798317524003061761,
        compact => '2001:db8:0:2:3::1',
    },
    {
        ip      => '2001:db8:0:002:03::1',
        full    => '2001:0db8:0000:0002:0003:0000:0000:0001',
        val     => 42540766411282592893798317524003061761,
        compact => '2001:db8:0:2:3::1',
    },
    {
        ip      => '2605:2700:0:3::4713:93e3',
        full    => '2605:2700:0000:0003:0000:0000:4713:93e3',
        val     => 50537416338094019778974086937420469219,
        compact => '2605:2700:0:3::4713:93e3',
    },
);

for @TESTS6 -> $test {
    is ipv6-expand($test<ip>), $test<full>, "$test<ip> ipv6-expand";
    is ipv6-expand($test<full>), $test<full>, "$test<ip> ipv6-expand (full)";
    is ipv6-to-int($test<ip>), $test<val>, "$test<ip> ipv6-to-int";
    is ipv6-compact($test<ip>), $test<compact>, "$test<ip> ipv6-compact";
    is int-to-ipv6($test<val>), $test<compact>, "$test<ip> int-to-ipv6";
}

done-testing;

