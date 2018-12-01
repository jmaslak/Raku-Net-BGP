use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Connection-List;
use Net::BGP::Controller-Handle-BGP;
use Net::BGP::Peer-List;
use Net::BGP::IP;

# NOTE: The controller is running on the connection thread.

class Net::BGP::Controller:ver<0.0.0>:auth<cpan:JMASLAK>
    does Net::BGP::Controller-Handle-BGP
{
    has Int:D $.my-asn is required where ^65536;

    has Net::BGP::Peer-List:D       $.peers       = Net::BGP::Peer-List.new(:$!my-asn);
    has Net::BGP::Connection-List:D $.connections = Net::BGP::Connection-List.new;

    # Handle open messages
    multi method receive-bgp(
        Net::BGP::Connection-Role:D $connection,
        Net::BGP::Message::Open:D $open
    ) {
        # Does the peer exist?
        my $p = self.peers.get($connection.remote-ip);
        if ! $p.defined {
            # Bad peer, we just close the connection, it's an invalid
            # peer.
            $connection.close;
            return;
        }

        if $open.asn ≠ $p.peer-asn {
            my $msg = Net::BGP::Message.from_hash(
                %{
                    message-type  => 'Notify',
                    error-name    => 'Open',
                    error-subname => 'Bad-Peer-AS',
                }
            );
            $connection.send-bgp($msg);
            $connection.close;
            return;
        }

        $p.lock.protect: {
            # We know we have a connection from a peer that is valid. So
            # lets see if we have a connection to that peer already
            if $p.connection.defined {
                # So we have a connection already to this peer.
                # We would do our collision detection here.
                !!!;
            }

            # So we know we're the best connection to be active
            $p.peer-identifier = $open.identifier;
            $p.connection      = $connection;
            if $connection.inbound {
                # XXX Send an Open
            }
            $p.state = Net::BGP::Peer::OpenConfirm;
        }

        # Add the connection to the connection table
        $!connections.add: $connection;
    }

    multi method receive-bgp(
        Net::BGP::Connection-Role:D $connection,
        Net::BGP::Message:D $msg
    ) {
        return; # XXX We don't do anything for most messages right now
    }

    method connection-closed(Net::BGP::Connection-Role:D $connection -->Nil) {
        if $!connections.exists($connection.id) {
            $!connections.remove($connection.id);
        }

        my $p = self.peers.get($connection.remote-ip);
        if ! $p.defined {
            # Do nothing;
            return;
        }

        $p.lock.protect: {
            if $p.connection.defined && $p.connection.id == $connection.id {
                $p.connection = Nil;
                $p.state = Net::BGP::Peer::Idle;  # XXX This might not be right
            }
        }
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

=head1 METHODS

=head2 receive-bgp(Net::BGP::Connection-Role:D, Net::BGP::Message:D)

Processes a received BGP message.

=head2 connection-closed(Net::BGP::Connection-Role:D) {

Removes a BGP connection from the connection list and peer object.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
