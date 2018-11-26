use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Connection;
use Net::BGP::Connection-List;
use Net::BGP::Controller-Handle-BGP;
use Net::BGP::Peer;
use Net::BGP::IP;

class Net::BGP::Controller:ver<0.0.0>:auth<cpan:JMASLAK>
    does Net::BGP::Controller-Handle-BGP
{

    has Int:D $.my-asn is required where ^65536;

    # Private Attributes
    has Lock:D           $!peerlock = Lock.new;
    has Net::BGP::Peer:D %!peers;

    has Net::BGP::Connection-List:D $.connections = Net::BGP::Connection-List.new;

    # Handle open messages
    multi method receive-bgp(Int:D $connection-id, Net::BGP::Message::Open:D $msg) {
        # Does the peer exist?
        my $c = $!connections.get($connection-id);
        if ! $c.defined {
            ### XXX Likely unreachable
            die("Connection ID not found");
        }
        my $p = self.peer-get(:peer-ip($c.remote-ip));
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

    method peer-get(
        Str:D :$peer-ip,
        -->Net::BGP::Peer
    ) {
        my $key = self.peer-key($peer-ip);
          
        $!peerlock.protect: {
            if %!peers{$key}:exists {
                return %!peers{$key};
            } else {
                return;
            }
        };
    }

    method peer-add(Int:D :$peer-asn, Str:D :$peer-ip, Int:D :$peer-port? = 179) {
        my $key = self.peer-key($peer-ip);

          $!peerlock.protect: {
              if %!peers{$key}:exists {
                  die("Peer was already defined - IP: $peer-ip");
              }

              %!peers{$key} = Net::BGP::Peer.new(
                  :peer-ip($peer-ip),
                  :peer-port($peer-port),
                  :peer-asn($peer-asn),
                  :my-asn($.my-asn)
              );
          };
      }

      method peer-remove ( Str:D :$peer-ip ) {
          my $key = self.peer-key($peer-ip);

          $!peerlock.protect: {
              if %!peers{$key}:exists {
                  %!peers{$key}.destroy-peer();
                  %!peers{$key}:delete;
              }
          }
      }

      method peer-key(Str:D $peer-ip is copy -->Str:D) {
          return ip-cannonical($peer-ip);
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
