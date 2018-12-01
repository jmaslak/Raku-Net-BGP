use v6.c;

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

# We need to register all the parameter types, which happens when the
# module is loaded.
use Net::BGP::Parameter;
use Net::BGP::Parameter::Generic;

# We need to register all the message types, which happens when the
# module is loaded.
use Net::BGP::Message;
use Net::BGP::Message::Generic;
use Net::BGP::Message::Open;
use Net::BGP::Message::Notify;
use Net::BGP::Message::Notify::Generic;
use Net::BGP::Message::Notify::Open;
use Net::BGP::Message::Notify::Open::Bad-Peer-AS;
use Net::BGP::Message::Notify::Open::Generic;
use Net::BGP::Message::Notify::Open::Unsupported-Version;

class Net::BGP:ver<0.0.0>:auth<cpan:JMASLAK> {
    our subset PortNum of Int where ^65536;

    has PortNum:D $.port is default(179);

    has Channel  $.listener-channel;    # Listener channel
    has Supplier $!user-supplier;       # Supplier object (to send events to the user)
    has Channel  $.user-channel;        # User channel (for the user to receive the events)

    has Net::BGP::Controller $.controller is rw;

    has Int:D $.my-asn is required where ^65536;

    submethod BUILD( *%args ) {
        for %args.keys -> $k {
            given $k {
                when 'port'   { $!port   = %args{$k} if %args{$k}.defined }
                when 'my-asn' { $!my-asn = %args{$k} }
                default { die("Invalid attribute set in call to constructor: $k") }
            }
        }

        $!user-supplier = Supplier.new;
        $!user-channel  = $!user-supplier.Supply.Channel;
        $!controller    = Net::BGP::Controller.new(:my-asn($!my-asn));
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
                    if $msg.message-type eq "Stop" {
                        $listen-socket = Nil;
                        $promise.keep();
                        done();
                        # XXX Do we need to kill the children?
                    } elsif $msg.message-type eq "Dead-Child" {
                        $!controller.connections.remove($msg.connection-id);
                    } else {
                        !!!;
                    }
                }
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
        Int:D :$peer-asn,
        Str:D :$peer-ip,
        Int:D :$peer-port? = 179,
    ) {
        $.controller.peers.add(:$peer-asn, :$peer-ip, :$peer-port);
    }

    method peer-remove ( Str:D :$peer-ip, Int:D :$peer-port? = 179 ) {
        $.controller.peers.remove(:$peer-ip, :$peer-port);
    }

}

