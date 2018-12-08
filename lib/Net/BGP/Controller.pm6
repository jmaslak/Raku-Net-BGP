use v6.d;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Connection-List;
use Net::BGP::Controller-Handle-BGP;
use Net::BGP::Peer-List;
use Net::BGP::IP;
use Net::BGP::Message::Keep-Alive;
use Net::BGP::Parameter::Capabilities;
use Net::BGP::Time;

# NOTE: The controller is running on the connection thread, for any
# method that takes a controller.

class Net::BGP::Controller:ver<0.0.0>:auth<cpan:JMASLAK>
    does Net::BGP::Controller-Handle-BGP
{
    has Int:D $.my-asn            is required where ^65536;
    has Int:D $.identifier        is required where ^(2³²);

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

        # Process Parmaters
        my @capabilities;
        for $open.parameters -> $param {
            if $param ~~ Net::BGP::Parameter::Capabilities {
                for $param.capabilities -> $cap {
                    @capabilities.push: $cap;
                }
            } else {
                # We don't speak this option yet
                # XXX We should thorw an event to the user so they know
                my $msg = Net::BGP::Message.from-hash(
                    %{
                        message-name  => 'NOTIFY',
                        error-name    => 'Open',
                        error-subname => 'Unsupported-Optional-Parameter',
                    }
                );
                $connection.send-bgp($msg);
                $connection.close;
                return;
            }
        }

        if $open.asn ≠ $p.peer-asn {
            my $msg = Net::BGP::Message.from-hash(
                %{
                    message-name  => 'NOTIFY',
                    error-name    => 'Open',
                    error-subname => 'Bad-Peer-AS',
                }
            );
            $connection.send-bgp($msg);
            $connection.close;
            return;
        }

        # Negotiate capabilities
        $p.lock.protect: {
            $p.last-message-received = monotonic-whole-seconds;

            # We know we have a connection from a peer that is valid. So
            # lets see if we have a connection to that peer already
            if $p.connection.defined && ($p.connection.id ≠ $connection.id) {
                # So we have a connection already to this peer.
                # We would do our collision detection here.
                !!!; # XXX
            }

            # So we know we're the best connection to be active
            $p.peer-identifier = $open.identifier;
            $p.connection      = $connection;
            
            # XXX If we think they don't support capabilities, but
            # they do, what do we do?
            $p.supports-capabilities = @capabilities.elems.so;

            if $connection.inbound {
                self.send-open(
                    $connection,
                    :supports-capabilities($p.supports-capabilities),
                    :hold-time($p.my-hold-time),
                );
                $p.state = Net::BGP::Peer::OpenConfirm;
            }

            self.send-keep-alive($connection);
        }

        # Add the connection to the connection table
        $!connections.add: $connection;
    }

    multi method receive-bgp(
        Net::BGP::Connection-Role:D $connection,
        Net::BGP::Message::Keep-Alive:D $keep-alive
    ) {
        # Does the peer exist?
        my $p = self.peers.get($connection.remote-ip);
        if ! $p.defined {
            # Bad peer, we just close the connection, it's an invalid
            # peer.
            $connection.close;
            return;
        }

        $p.lock.protect: {
            # If the peer exists and is the current peer, in OpenConfirm state,
            # move to ESTABLISHED
            if $p.connection.defined && ($p.connection.id == $connection.id ) {
                $p.last-message-received = monotonic-whole-seconds;

                if $p.state == Net::BGP::Peer::OpenConfirm {
                    $p.state = Net::BGP::Peer::Established;
                }
            }
        }
    }


    multi method receive-bgp(
        Net::BGP::Connection-Role:D $connection,
        Net::BGP::Message:D $msg
    ) {
        # Does the peer exist?
        my $p = self.peers.get($connection.remote-ip);
        if ! $p.defined {
            # Bad peer, we just close the connection, it's an invalid
            # peer.
            $connection.close;
            return;
        }

        $p.lock.protect: {
            if $p.connection.defined && ($p.connection.id == $connection.id ) {
                $p.last-message-received = monotonic-whole-seconds;
                return; # XXX We don't do anything for most messages right now
            }
        }
    }

    multi method handle-error(
        Net::BGP::Connection-Role:D $connection,
        Net::BGP::Error::Unknown-Version:D $e
        -->Nil
    ) {
        # Exception created on receipt of OPEN if there is an invalid versionn
        # number

        my $msg = Net::BGP::Message.from-hash(
            %{
                message-name  => 'NOTIFY',
                error-name    => 'Open',
                error-subname => 'Unsupported-Version',
            }
        );
        $connection.send-bgp($msg);
        $connection.close;
    }

    multi method handle-error(
        Net::BGP::Connection-Role:D $connection,
        Net::BGP::Error::Marker-Format:D $e
        -->Nil
    ) {
        # Exception created on receipt of OPEN if there is an invalid versionn
        # number

        my $msg = Net::BGP::Message.from-hash(
            %{
                message-name  => 'NOTIFY',
                error-name    => 'Header',
                error-subname => 'Connection-Not-Syncronized',
            }
        );
        $connection.send-bgp($msg);
        $connection.close;
    }

    multi method handle-error(
        Net::BGP::Connection-Role:D $connection,
        Net::BGP::Error:D $e
        -->Nil
    ) {
        return; # XXX We don't do anything for most messages right now.
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
                $p.last-connect-attempt = monotonic-whole-seconds;
                $p.state = Net::BGP::Peer::Idle;  # XXX This might not be right
            }
        }
    }

    method send-open(
        Net::BGP::Connection-Role:D $connection,
        Bool                        :$supports-capabilities,
        Int:D                       :$hold-time
        -->Nil
    ) { 
        my $asn16 = $.my-asn ≥ (2¹⁶) ?? 23456 !! $.my-asn;
        my $asn32 = $.my-asn;

        my %msg-hash =
            message-name  => 'OPEN',
            asn           => $asn16,
            hold-time     => $hold-time,
            identifier    => $.identifier;

        if $supports-capabilities // True {
            %msg-hash<capabilities> = (
                %{
                    capability-name => 'ASN32',
                    asn             => $asn32,
                },
            );
        }
        
        my $msg = Net::BGP::Message.from-hash(%msg-hash);
        $connection.send-bgp($msg);
    }
    
    method send-keep-alive(Net::BGP::Connection-Role:D $connection -->Nil) {
        my $msg = Net::BGP::Message.from-hash(
            %{
                message-name => 'KEEP-ALIVE'
            }
        );
        $connection.send-bgp($msg);
    }

    method update-last-sent(Net::BGP::Connection-Role:D $connection -->Nil) {
        my $p = self.peers.get($connection.remote-ip);
        if ! $p.defined {
            # Do nothing;
            return;
        }

        $p.lock.protect: {
            if $p.connection.defined && ($p.connection.id == $connection.id ) {
                if $p.state == Net::BGP::Peer::Established {
                    $p.last-message-sent = monotonic-whole-seconds;
                } elsif $p.state == Net::BGP::Peer::OpenSent {
                    $p.last-message-sent = monotonic-whole-seconds;
                } elsif $p.state == Net::BGP::Peer::OpenConfirm {
                    $p.last-message-sent = monotonic-whole-seconds;
                }
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

=head2 method handle-error(Net::BGP::Connection-Role:D, Net::BGP::Error:D)

Process a BGP exception.

=head2 connection-closed(Net::BGP::Connection-Role:D)

Removes a BGP connection from the connection list and peer object.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
