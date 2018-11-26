use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Connection-List;
use Net::BGP::Controller-Handle-BGP;
use Net::BGP::Peer-List;
use Net::BGP::IP;

class Net::BGP::Controller:ver<0.0.0>:auth<cpan:JMASLAK>
    does Net::BGP::Controller-Handle-BGP
{

    has Int:D $.my-asn is required where ^65536;

    has Net::BGP::Peer-List:D       $.peers       = Net::BGP::Peer-List.new(:$!my-asn);
    has Net::BGP::Connection-List:D $.connections = Net::BGP::Connection-List.new;

    # Handle open messages
    multi method receive-bgp(Int:D $connection-id, Net::BGP::Message::Open:D $msg) {
        # Does the peer exist?
        my $c = $!connections.get($connection-id);
        if ! $c.defined {
            ### XXX Likely unreachable
            die("Connection ID not found");
        }
        my $p = self.peers.get($c.remote-ip);
        if ! $p.defined {
            # XXX We should handle a bad peer
            return;
        }
        if $p.asn ≠ $msg.peer-asn {
            # XXX We should handle a bad peer ASN
            return;
        }
    }
    multi method receive-bgp(Int:D $connection-id, Net::BGP::Message:D $msg) {
        return; # XXX We don't do anything for most messages right now
    }
}

=begin pod

=head1 NAME

Net::BGP::Controller - BGP Server Controller Class

=head1 SYNOPSIS

  use Net::BGP::Controller;

  my $controller = Net::BGP::Controller.new;

=head1 DESCRIPTION

Manages the state machine used to determine how to respond to BGP messages.
This manages the associations between peers and connections, handles some
BGP errors, and manages the conflict resolution.

=head1 ATTRIBUTES

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
