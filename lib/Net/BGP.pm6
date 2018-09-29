use v6.c;

use Net::BGP::Command;
use Net::BGP::Command::BGP-Message;
use Net::BGP::Command::Stop;
use Net::BGP::Connection;
use Net::BGP::Conversions;
use Net::BGP::Error;
use Net::BGP::Error::Bad-Option-Length;
use Net::BGP::Error::Bad-Parameter-Length;
use Net::BGP::Error::Unknown-Version;
use Net::BGP::IP;
use Net::BGP::Message;
use Net::BGP::Message::Generic;
use Net::BGP::Message::Open;
use Net::BGP::Notify;
use Net::BGP::Notify::BGP-Message;
use Net::BGP::Notify::Closed-Connection;
use Net::BGP::Notify::New-Connection;
use Net::BGP::Parameter;
use Net::BGP::Parameter::Generic;
use Net::BGP::Peer;

class Net::BGP:ver<0.0.0>:auth<cpan:JMASLAK> {
    our subset PortNum of Int where ^65536;

    has PortNum:D $.port is default(179);

    has Channel  $.listener-channel;    # Listener channel
    has Supplier $!user-supplier;       # Supplier object (to send events to the user)
    has Channel  $.user-channel;        # User channel (for the user to receive the events)

    has Net::BGP::Connection %!connection; # Connections that are established
    has Lock $!connlock = Lock.new;        # Lock for the connections hash

    has Int:D $.my-asn is required where ^65536;

    has Net::BGP::Peer %.peers = Hash[Net::BGP::Peer].new; # Peer Objects

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

        $!connlock.protect(
            {
                if %!connection{ $connection-id }:!exists {
                    die("Command sent to non-existant ID");
                };

                %!connection{$connection-id}.command.send($msg);
            }
        );
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
                    start {
                        my $conn = Net::BGP::Connection.new(:socket($socket));

                        # Set up connection object
                        $!connlock.protect( { %!connection{$conn.id} = $conn; } );

                        $!user-supplier.emit(
                            Net::BGP::Notify::New-Connection.new(
                                :client-ip( $socket.peer-host ),
                                :client-port( $socket.peer-port ),
                                :connection-id( $conn.id ),
                            ),
                        );

                        react {
                            whenever $socket.Supply(:bin).list -> $buf {
                                $conn.buffer.append($buf);
                                my $bgpmsg = $conn.pop-bgp-message();
                                if (defined($bgpmsg)) {
                                    # Send message to client
                                    $!user-supplier.emit(
                                        Net::BGP::Notify::BGP-Message.new(
                                            :message( $bgpmsg ),
                                            :connection-id( $conn.id ),
                                        ),
                                    );
                                }
                                CATCH {
                                    when Net::BGP::Error {
                                        $!user-supplier.emit( $_ );
                                        $socket.close;

                                        $!connlock.protect( { %!connection{$conn.id}:delete } );
                                    }
                                }

                                LAST {
                                    $!user-supplier.emit(
                                        Net::BGP::Notify::Closed-Connection.new(
                                            :client-ip( $socket.peer-host ),
                                            :client-port( $socket.peer-port ),
                                            :connection-id( $conn.id ),
                                        ),
                                    );
                                    $socket.close;

                                    $!connlock.protect( { %!connection{$conn.id}:delete } );
                                }
                                QUIT {
                                    $!user-supplier.emit(
                                        Net::BGP::Notify::Closed-Connection.new(
                                            :client-ip( $socket.peer-host ),
                                            :client-port( $socket.peer-port ),
                                            :connection-id( $conn.id ),
                                        ),
                                    );
                                    $socket.close;

                                    $!connlock.protect( { %!connection{$conn.id}:delete } );
                                }
                            }

                            whenever $conn.command -> Net::BGP::Command $msg {
                                if $msg.message-type eq 'BGP-Message' {
                                    my $outbuf = buf8.new();

                                    # Marker
                                    $outbuf.append( 255, 255, 255, 255 );
                                    $outbuf.append( 255, 255, 255, 255 );
                                    $outbuf.append( 255, 255, 255, 255 );
                                    $outbuf.append( 255, 255, 255, 255 );

                                    # Length
                                    $outbuf.append( nuint16-buf8( 18 + $msg.message.raw.bytes ) );

                                    # Message
                                    $outbuf.append( $msg.message.raw );

                                    # Actually send them.
                                    $socket.write($outbuf);
                                } else {
                                    die("Received an unexpected message type: " ~ $msg.message-type);
                                }
                            }
                        }

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
                        $listen-socket.close();
                        $promise.keep();
                        done();
                        # XXX Do we need to kill the children?
                    } else {
                        !!!;
                    }
                }
            }

            await $promise;
        }
        await $listen-promise;

        return;
    }

    method add-peer(
        Int:D :$peer-asn,
        Str:D :$peer-ip,
        Int:D :$peer-port = 179,
    ) {
        my $key = self.peer-key($peer-ip, $peer-port);
        if %.peers{$key}:exists {
            die("Peer was already defined - IP: $peer-ip, Port: $peer-port");
        }

        %.peers{$key} = Net::BGP::Peer.new(
            :peer-ip($peer-ip),
            :peer-port($peer-port),
            :peer-asn($peer-asn),
            :my-asn($.my-asn)
        );
    }

    method remove-peer( Str:D :$peer-ip, Int:D :$peer-port = 179 ) {
        my $key = self.peer-key($peer-ip, $peer-port);
        if %.peers{$key}:exists {
            %.peers{$key}.destroy-peer();
            %.peers{$key}:delete;
        }
    }

    method peer-key(Str:D $peer-ip is copy, Int:D $peer-port = 179) {
        $peer-ip = ip-cannonical($peer-ip);
        return "$peer-ip $peer-port";
    }
}

