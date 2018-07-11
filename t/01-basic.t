use v6.c;
use Test;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

{
    use Net::BGP;

    subtest 'Basic Class', {
        my $bgp = Net::BGP.new();
        ok $bgp, "Created BGP Class";
        is $bgp.port, 179, 'Port has proper default';

        $bgp = Net::BGP.new( port => 1179 );
        is $bgp.port, 1179, 'Port is properly set to 1179';

        $bgp = Net::BGP.new( port => Nil );
        is $bgp.port, 179, 'Port is properly set to 179 by Nil';

        dies-ok { $bgp.port = 17991; }, 'Cannot change port';

        dies-ok { $bgp = Net::BGP.new( port =>    -1 ); }, '< 0 port rejected';
        dies-ok { $bgp = Net::BGP.new( port => 65536 ); }, '>65535 port rejected';

        dies-ok { $bgp = Net::BGP.new( foo => 1 ); }, 'Non-existent attribute causes failure';

        done-testing;
    };

}

done-testing;

