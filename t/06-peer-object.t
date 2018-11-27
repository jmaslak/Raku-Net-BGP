use v6.c;
use Test;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Peer;

my $peer = Net::BGP::Peer.new(:peer-ip('192.0.2.1'), :peer-asn(65001), :my-asn(65000));
ok $peer, "Created BGP Class";

is $peer.peer-ip, '192.0.2.1', "Peer IP is correct";
is $peer.peer-port, 179, "Peer port is okay";
is $peer.peer-asn, 65001, "Peer ASN is okay";
is $peer.my-asn, 65000, "My ASN is okay";
is $peer.state, PeerState::Idle, "Peer state is okay";

done-testing;

