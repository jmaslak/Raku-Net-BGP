use v6.c;

class Net::BGP:ver<0.0.0>:auth<cpan:JMASLAK> {
    use StrictNamedArguments;

    our subset PortNum of Int where ^65536;

    has PortNum:D $.port is default(179);

    has Channel $!listener-channel; # Listener supply

    submethod BUILD( *%args ) {
        for %args.keys -> $k {
            given $k {
                when 'port'     { $!port     = %args{$k} if defined %args{$k} }
                default { die("Invalid attribute set in call to constructor: $k") }
            }
        }
    }

    method listen-stop(--> Nil) {
        say "Sending Stop";
        if defined $!listener-channel {
            say "Sending Stop2";
            $!listener-channel.send("STOP");
        }
    }

    method listen(--> Nil) {
        say "Listening on $.port";
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
                        say "Connection established!";
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

                whenever $!listener-channel -> $msg {
                    say "Got MSG!";
                    say $msg;
                    if ($msg eq "STOP") {
                        say "Stopping!";
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
