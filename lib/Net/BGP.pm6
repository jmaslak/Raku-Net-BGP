use v6.d;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Command;
use Net::BGP::Command::BGP-Message;
use Net::BGP::Command::Stop;
use Net::BGP::Controller;
use Net::BGP::Connection;
use Net::BGP::Conversions;
use Net::BGP::IP;
use Net::BGP::Event::New-Connection;
use Net::BGP::Peer;
use Net::BGP::Time;

# We need to register all the parameter types, which happens when the
# module is loaded.
use Net::BGP::Parameter;
use Net::BGP::Parameter::Capabilities;
use Net::BGP::Parameter::Generic;

# We need to register all the message types, which happens when the
# module is loaded.
use Net::BGP::Message;
use Net::BGP::Message::Generic;
use Net::BGP::Message::Keep-Alive;
use Net::BGP::Message::Open;
use Net::BGP::Message::Notify;
use Net::BGP::Message::Notify::Generic;
use Net::BGP::Message::Notify::Header;
use Net::BGP::Message::Notify::Header::Connection-Not-Syncronized;
use Net::BGP::Message::Notify::Header::Generic;
use Net::BGP::Message::Notify::Open;
use Net::BGP::Message::Notify::Open::Bad-Peer-AS;
use Net::BGP::Message::Notify::Open::Generic;
use Net::BGP::Message::Notify::Open::Unsupported-Optional-Parameter;
use Net::BGP::Message::Notify::Open::Unsupported-Version;
use Net::BGP::Message::Notify::Hold-Timer-Expired;

class Net::BGP:ver<0.0.0>:auth<cpan:JMASLAK> {
    our subset PortNum of Int where ^65536;

    has PortNum:D $.port is default(179);

    has Channel  $.listener-channel;    # Listener channel
    has Supplier $!user-supplier;       # Supplier object (to send events to the user)
    has Channel  $.user-channel;        # User channel (for the user to receive the events)

    has Net::BGP::Controller $.controller is rw;

    has Int:D $.my-asn     is required where ^65536;
    has Int:D $.identifier is required where ^(2³²);

    submethod BUILD( *%args ) {
        for %args.keys -> $k {
            given $k {
                when 'port'       { $!port       = %args{$k} if %args{$k}.defined }
                when 'my-asn'     { $!my-asn     = %args{$k} }
                when 'identifier' { $!identifier = %args{$k} }
                default { die("Invalid attribute set in call to constructor: $k") }
            }
        }

        $!user-supplier = Supplier.new;
        $!user-channel  = $!user-supplier.Supply.Channel;
        $!controller    = Net::BGP::Controller.new(
            :$!my-asn,
            :identifier($!identifier),
        );
    }

    method listen-stop(--> Nil) {
        if defined $!listener-channel {
            $!listener-channel.send(Net::BGP::Command::Stop.new);
        }
    }

    method send-bgp(Int:D $connection-id, Net::BGP::Message:D $bgp) {
        my $msg = Net::BGP::Command::BGP-Message.new(
            :connection-id($connection-id),
            :message($bgp),
        );

        $!controller.connections.get($connection-id).command.send($msg);
    }

    method listen(--> Nil) {
        my $promise = Promise.new;

        my $listen-socket;

        if defined $!listener-channel {
            die("BGP is already listening");
        }

        $!listener-channel = Channel.new;
        my $listen-promise = Promise.new;

        start {
            $listen-socket = IO::Socket::Async.listen("::", $.port);

            react {
                my $listen-tap = do whenever $listen-socket -> $socket {
                    my $conn = Net::BGP::Connection.new(
                        :socket($socket),
                        :listener-channel($!listener-channel),
                        :user-supplier($!user-supplier),
                        :bgp-handler($.controller),
                        :remote-ip($socket.peer-host),
                        :remote-port($socket.peer-port),
                        :inbound(True),
                    );

                    # Set up connection object
                    $!controller.connections.add($conn);
                    $!user-supplier.emit(
                        Net::BGP::Event::New-Connection.new(
                            :client-ip( $socket.peer-host ),
                            :client-port( $socket.peer-port ),
                            :connection-id( $conn.id ),
                        ),
                    );

                    # Do this in a child process.
                    start {
                        $conn.handle-messages;

                        CATCH {
                            default {
                                # We should log better
                                $*ERR.say("Error in child process!");
                                $*ERR.say(.message);
                                $*ERR.say(.backtrace.join);
                                .rethrow;
                            }
                        }
                    }
                }

                await $listen-tap.socket-port;      # make sure the socket is ready
                $!port = $listen-tap.socket-port.result;
                $listen-promise.keep($.port);

                whenever $!listener-channel -> Net::BGP::Command $msg {
                    if $msg.message-name eq "Stop" {
                        $listen-socket = Nil;
                        $promise.keep();
                        done();
                        # XXX Do we need to kill the children?
                    } elsif $msg.message-name eq "Dead-Child" {
                        $!controller.connections.remove($msg.connection-id);
                    } else {
                        !!!;
                    }
                }

                whenever Supply.interval(1) { self.tick }
            }

            await $promise;

            CATCH {
                default {
                    # We should log better
                    $*ERR.say("Error in child process!");
                    $*ERR.say(.message);
                    $*ERR.say(.backtrace.join);
                    .rethrow;
                }
            }

        }
        await $listen-promise;

        return;
    }

    method peer-get (
        Str:D :$peer-ip,
        -->Net::BGP::Peer
    ) {
        return $.controller.peers.get($peer-ip);
    }

    method peer-add (
        Int:D  :$peer-asn,
        Str:D  :$peer-ip,
        Int:D  :$peer-port? = 179,
        Bool:D :$passive? = False,
    ) {
        $.controller.peers.add(:$peer-asn, :$peer-ip, :$peer-port, :$passive);
    }

    method peer-remove ( Str:D :$peer-ip, Int:D :$peer-port? = 179 ) {
        $.controller.peers.remove(:$peer-ip, :$peer-port);
    }

    # Deal with clock tick
    method tick(-->Nil) {
        self.connect-if-needed;
        self.send-keepalives;
        self.reap-dead-connections;
    }

    method connect-if-needed(-->Nil) {
        state Lock $lock = Lock.new;
        $lock.protect: {
            loop {
                my $p = $.controller.peers.get-peer-due-for-connect;
                if ! $p.defined { return; }

                $p.lock.protect: {
                    if $p.connection.defined { next; }    # Someone created a connection

                    $p.last-connect-attempt = monotonic-whole-seconds;
                }

                my $promise = IO::Socket::Async.connect($p.peer-ip, $p.peer-port);
                start self.connection-handler($promise, $p);
            }
        }
    }

    method connection-handler(Promise:D $socket-promise, Net::BGP::Peer:D $peer) {
        my $socket = $socket-promise.result;

        my $conn;
        $peer.lock.protect: {
            if $peer.connection.defined { return } # Just in case it got defined

            $conn = Net::BGP::Connection.new(
                :socket($socket),
                :listener-channel($!listener-channel),
                :user-supplier($!user-supplier),
                :bgp-handler($.controller),
                :remote-ip($socket.peer-host),
                :remote-port($socket.peer-port),
                :inbound(False),
            );

            # Add peer to connection
            $peer.connection = $conn;

            # Set up connection object
            $!controller.connections.add($conn);

            # Send Open
            $peer.state = Net::BGP::Peer::OpenSent;
            $!controller.send-open($conn,
                :hold-time($peer.my-hold-time),
                :supports-capabilities($peer.supports-capabilities),
            );
        }

        # Let user know.
        $!user-supplier.emit(
            Net::BGP::Event::New-Connection.new(
                :client-ip( $socket.peer-host ),
                :client-port( $socket.peer-port ),
                :connection-id( $conn.id ),
            ),
        );

        $conn.handle-messages;

        CATCH {
            default {
                # We should log better
                $*ERR.say("Error in child process!");
                $*ERR.say(.message);
                $*ERR.say(.backtrace.join);
                .rethrow;
            }
        }
    }

    method send-keepalives(-->Nil) {
        loop {
            my $p = $.controller.peers.get-peer-due-for-keepalive;
            if ! $p.defined { return; }

            $p.lock.protect: {
                if ! $p.connection.defined { next; }
                $.controller.send-keep-alive($p.connection);
            }
        }
    }

    method reap-dead-connections(-->Nil) {
        loop {
            my $p = $.controller.peers.get-peer-dead;
            if ! $p.defined { return; }

            $p.lock.protect: {
                if ! $p.connection.defined { next; }
                my $msg = Net::BGP::Message.from-hash(
                    %{
                        message-name => 'NOTIFY',
                        error-name   => 'Hold-Timer-Expired',
                    },
                );
                $p.connection.send-bgp($msg);
                $p.connection.close;
            }
        }
    }

}

