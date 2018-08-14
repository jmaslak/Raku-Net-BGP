use v6.c;

use Net::BGP::Message;

class Net::BGP:ver<0.0.0>:auth<cpan:JMASLAK> {
    our subset PortNum of Int where ^65536;

    has PortNum:D $.port is default(179);

    has Channel $.listener-channel;     # Listener supply
    has Channel $.user-channel;         # Channel to communicate to the user

    submethod BUILD( *%args ) {
        for %args.keys -> $k {
            given $k {
                when 'port' { $!port = %args{$k} if defined %args{$k} }
                default { die("Invalid attribute set in call to constructor: $k") }
            }
        }

        $!user-channel = Channel.new;
    }

    method listen-stop(--> Nil) {
        if defined $!listener-channel {
            $!listener-channel.send(Net::BGP::Message::Stop.new);
        }
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
                        $.user-channel.send( Net::BGP::Message::New-Connection.new );
                        react { 
                            whenever $conn.Supply.lines -> $line {
                                $conn.print("Hello, $line!\n");
                                LAST { say "CLOSED" }
                                QUIT { say "QUIT"; $conn.close }
                            }
                        }
                    }
                }

                await $listen-tap.socket-port;
                $!port = $listen-tap.socket-port.result;
                $listen-promise.keep($.port);

                whenever $!listener-channel -> Net::BGP::Message $msg {
                    if ($msg.message-type eq "Stop") {
                        $listen-socket.close();
                        $promise.keep();
                        done();
                    }
                }
            }
            
            await $promise;
        }
        await $listen-promise;

        return;
    }
}

=begin pod

=head1 NAME

Net::BGP - BGP Server Support

=head1 SYNOPSIS

  use Net::BGP

  my $bgp = Net::BGP.new( port => 179 );  # Create a server object

=head1 DESCRIPTION

This provides framework to support the BGP protocol within a Perl6 application.

=head1 ATTRIBUTES

=head2 port

The port attribute defaults to 179 (the IETF assigned port default), but can
be set to any value between 0 and 65535.  It can also be set to Nil, meaning
that it will be an ephimeral port that will be set once the listener is
started.

=head2 server-channel

Returns the channel communicate to command the BGP server process.  This will
not be defined until C<listen()> is executed.  It is intended that user code
will send messages to the BGP server.

=head2 user-channel

Returns the channel communicate for the BGP server process to communicate to
user code.

=head1 METHODS

=head2 listen

  $bgp.listen();

Starts BGP listener, on the port provided in the port attribute.

For a given instance of the BGP class, only one listener can be active at any
point in time.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

