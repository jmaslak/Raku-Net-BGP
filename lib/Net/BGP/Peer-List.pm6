use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::IP;
use Net::BGP::Peer;
use OO::Monitors;

monitor Net::BGP::Peer-List:ver<0.0.0>:auth<cpan:JMASLAK> {

    has Net::BGP::Peer:D %!peers;
    has Int:D $.my-asn is required where ^65536;

    method get(Str:D $peer-ip) {
        my $key = self.peer-key($peer-ip);
        if %!peers{$key}:exists {
            return %!peers{$key};
        } else {
            return;
        }
    }

    method add(Int:D :$peer-asn, Str:D :$peer-ip, Int:D :$peer-port? = 179) {
        my $key = self.peer-key($peer-ip);

        if %!peers{$key}:exists {
            die("Peer was already defined - IP: $peer-ip");
        }

        %!peers{$key} = Net::BGP::Peer.new(
            :$peer-ip,
            :$peer-port,
            :$peer-asn,
            :$!my-asn,
        );
    }

    method remove(Str:D $peer-ip) {
        my $key = self.peer-key($peer-ip);
        
        if %!peers{$key}:exists {
            %!peers{$key}.destroy-peer();
            %!peers{$key}:delete;
        }
    }

    method peer-key(Str:D $peer-ip) {
        return ip-cannonical($peer-ip);
    }

};



