#!/usr/bin/env perl6
use v6.d;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP;
use Net::BGP::IP;

my subset Port of UInt where ^2¹⁶;
my subset Asn  of UInt where ^2¹⁶;

sub MAIN(
    Int:D :$port = 179,
    Int:D :$my-asn,
    Int:D :$peer-asn,       # XXX should allow per-per spec
    Net::BGP::IP::ipv4:D :$my-bgp-id,
    *@peers
) {
    my $bgp = Net::BGP.new(
        :$port,
        :$my-asn,
        :identifier(ipv4-to-int($my-bgp-id))
    );

    # Add peers
    for @peers -> $peer-ip {
        $bgp.peer-add( :$peer-asn, :$peer-ip );  # XXX Should allow peer port spec
    }

    # Start the TCP socket
    $bgp.listen();
    lognote("Listening");

    my $channel = $bgp.user-channel;

    react {
        whenever $channel -> $event {
            logevent($event);
        }
    }
}

multi sub logevent(Net::BGP::Event:D $event) {
    lognote($event.Str);
}

sub lognote(Str:D $msg) {
    log('N', $msg);
}

sub log(Str:D $type, Str:D $msg) {
    say "[$type] $msg";
}


