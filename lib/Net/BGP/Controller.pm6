use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Connection;
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

    has Lock:D                 $!connlock     = Lock.new;
    has Net::BGP::Connection:D %!connections;

    method connection(Int:D $id) {
        $!connlock.protect: {
            if %!connections{$id}:exists {
                return %!connections{$id};
            } else {
                die("Command sent to non-existant ID");
            }
        };
    }

    method connection-add(Net::BGP::Connection:D $connection) {
        $!connlock.protect: { %!connections{ $connection.id } = $connection; };
    }

    method connection-remove(Int:D $id) {
        $!connlock.protect: { %!connections{ $id }:delete };
    }

    # Handle open messages
    multi method receive-bgp(Int:D $connection-id, Net::BGP::Message::Open:D $msg) {
        # Does the peer exist?
        my $c = self.connection($connection-id);
        if ! $c.defined {
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
