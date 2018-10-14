use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Connection;
use Net::BGP::Peer;
use Net::BGP::IP;

class Net::BGP::Controller:ver<0.0.0>:auth<cpan:JMASLAK> {

    has Int:D $.my-asn is required where ^65537;

    # Private Attributes
    has Lock           $!peerlock = Lock.new;
    has Net::BGP::Peer %!peers;

    has Lock                 $!connlock     = Lock.new;
    has Net::BGP::Connection %!connections;

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

    method peer-get(
        Int:D :$peer-asn,
        Str:D :$peer-ip,
        Int:D :$peer-port? = 179
        -->Net::BGP::Peer
    ) {
        my $key = self.peer-key($peer-ip, $peer-port);
          
        $!peerlock.protect: {
            if %!peers{$key}:exists {
                return %!peers{$key};
            } else {
                return;
            }
        };
    }

    method peer-add(Int:D :$peer-asn, Str:D :$peer-ip, Int:D :$peer-port? = 179) {
        my $key = self.peer-key($peer-ip, $peer-port);

          $!peerlock.protect: {
              if %!peers{$key}:exists {
                  die("Peer was already defined - IP: $peer-ip, Port: $peer-port");
              }

              %!peers{$key} = Net::BGP::Peer.new(
                  :peer-ip($peer-ip),
                  :peer-port($peer-port),
                  :peer-asn($peer-asn),
                  :my-asn($.my-asn)
              );
          };
      }

      method peer-remove ( Str:D :$peer-ip, Int:D :$peer-port? = 179 ) {
          my $key = self.peer-key($peer-ip, $peer-port);

          $!peerlock.protect: {
              if %!peers{$key}:exists {
                  %!peers{$key}.destroy-peer();
                  %!peers{$key}:delete;
              }
          }
      }

      method peer-key(Str:D $peer-ip is copy, Int:D $peer-port? = 179) {
          $peer-ip = ip-cannonical($peer-ip);
          return "$peer-ip $peer-port";
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
