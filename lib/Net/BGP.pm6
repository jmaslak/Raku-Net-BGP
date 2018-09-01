use v6.c;

use Net::BGP::Command;
use Net::BGP::Command::BGP-Message;
use Net::BGP::Command::Stop;
use Net::BGP::Conversions;
use Net::BGP::Error;
use Net::BGP::Error::Bad-Option-Length;
use Net::BGP::Error::Hold-Time-Too-Short;
use Net::BGP::Error::Length-Too-Long;
use Net::BGP::Error::Length-Too-Short;
use Net::BGP::Error::Marker-Format;
use Net::BGP::Error::Unknown-Version;
use Net::BGP::Message;
use Net::BGP::Message::Generic;
use Net::BGP::Message::Open;
use Net::BGP::Notify;
use Net::BGP::Notify::BGP-Message;
use Net::BGP::Notify::Closed-Connection;
use Net::BGP::Notify::New-Connection;

class Net::BGP:ver<0.0.0>:auth<cpan:JMASLAK> {
    our subset PortNum of Int where ^65536;

    has PortNum:D $.port is default(179);

    has Channel  $.listener-channel;    # Listener channel
    has Supplier $!user-supplier;       # Supplier object (to send events to the user)
    has Channel  $.user-channel;        # User channel (for the user to receive the events)

    has %!connection;                   # Connections that are established
    has Lock $!connlock = Lock.new;     # Lock for the connections hash

    submethod BUILD( *%args ) {
        for %args.keys -> $k {
            given $k {
                when 'port' { $!port = %args{$k} if defined %args{$k} }
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

                %!connection{$connection-id}<command>.send($msg);
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
                my $listen-tap = do whenever $listen-socket -> $conn {
                    start {
                        my %connhash;
                        my $id;
                        %connhash<socket>  = $conn;
                        %connhash<command> = Channel.new();  # Command channel

                        # Set up connection object
                        $!connlock.protect(
                            {
                                # Get conn number
                                $id = %!connection.elems ?? %!connection.elems.max + 1 !! 0;

                                %connhash<id> = $id;
                                %!connection{$id} = %connhash;
                            }
                        );

                        $!user-supplier.emit(
                            Net::BGP::Notify::New-Connection.new(
                                :client-ip( $conn.peer-host ),
                                :client-port( $conn.peer-port ),
                                :connection-id( $id ),
                            ),
                        );

                        my $msg = buf8.new;

                        react {
                            whenever $conn.Supply(:bin).list -> $buf {
                                $msg.append($buf);
                                my $bgpmsg = self.pop_bgp_message($msg);
                                if (defined($bgpmsg)) {
                                    # Send message to client
                                    $!user-supplier.emit(
                                        Net::BGP::Notify::BGP-Message.new(
                                            :message( $bgpmsg ),
                                            :connection-id( $id ),
                                        ),
                                    );
                                }
                                CATCH {
                                    when Net::BGP::Error {
                                        $!user-supplier.emit( $_ );
                                        $conn.close;

                                        $!connlock.protect( { %!connection{$id}:delete } );
                                        %connhash = Hash.new();
                                    }
                                }

                                LAST {
                                    $!user-supplier.emit(
                                        Net::BGP::Notify::Closed-Connection.new(
                                            :client-ip( $conn.peer-host ),
                                            :client-port( $conn.peer-port ),
                                            :connection-id( $id ),
                                        ),
                                    );
                                    $conn.close;

                                    $!connlock.protect( { %!connection{$id}:delete } );
                                    %connhash = Hash.new();
                                }
                                QUIT {
                                    $!user-supplier.emit(
                                        Net::BGP::Notify::Closed-Connection.new(
                                            :client-ip( $conn.peer-host ),
                                            :client-port( $conn.peer-port ),
                                            :connection-id( $id ),
                                        ),
                                    );
                                    $conn.close;

                                    $!connlock.protect( { %!connection{$id}:delete } );
                                    %connhash = Hash.new();
                                }
                            }

                            whenever %connhash<command> -> Net::BGP::Command $msg {
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
                                    $conn.write($outbuf);
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

                await $listen-tap.socket-port;
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

    # WARNING - THIS METHOD HAS SIDE EFFECTS!
    #
    # Side Effect 1 - It will REMOVE the message from the buffer!
    #
    # Side Effect 2 - Will throw on BGP message error
    #
    method pop_bgp_message(buf8 $msg is rw --> Net::BGP::Message) {
        # We need at least 19 bytes to have a BGP message (RFC4271 4.1)
        if $msg.bytes < 19 {
            return 0;  # We don't have a message
        }

        # Check for valid marker
        if !self.valid-marker($msg) {
            die Net::BGP::Error::Marker-Format.new();
        }

        # Parse length
        my $expected-len = nuint16($msg[16..17]);

        if $expected-len < 19 {
            # Too short - RFC4271 4.1
            die Net::BGP::Error::Length-Too-Short.new(:length($expected-len));
        }
        if $expected-len > 4096 {
            # Too long - RFC4271 4.1
            die Net::BGP::Error::Length-Too-Long.new(:length($expected-len));
        }

        if $msg.bytes < $expected-len {
            return; # We don't yet have the full message
        }

        # We delegate the hard work of parsing this message
        my $bgp-msg = Net::BGP::Message.from-raw( buf8.new($msg[18..*]) );

        # Remove message
        $msg.splice: 0, $expected-len, ();

        # Here we go - hand back parsed hash
        return $bgp-msg;
    }

    method valid-marker(buf8 $msg -->Bool) {
        if $msg.bytes < 16 { return False; }

        for ^16 -> $i {
            if $msg[$i] != 255 { return False; }
        }

        return True;
    }

}

