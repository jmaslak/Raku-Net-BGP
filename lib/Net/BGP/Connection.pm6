use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Conversions;
use Net::BGP::Message;
use Net::BGP::Error::Length-Too-Long;
use Net::BGP::Error::Length-Too-Short;
use Net::BGP::Error::Marker-Format;

class Net::BGP::Connection:ver<0.0.0>:auth<cpan:JMASLAK> {

    my Int $last_id = 0;

    has IO::Socket::Async $.socket;
    has Channel           $.command = Channel.new;
    has Int               $.id      = $last_id++;
    has buf8              $.buffer  = buf8.new;

    # WARNING - THIS METHOD HAS SIDE EFFECTS!
    #
    # Side Effect 1 - It will REMOVE the message from the buffer!
    #
    # Side Effect 2 - Will throw on BGP message error
    #
    method pop-bgp-message(--> Net::BGP::Message) {
        # We need at least 19 bytes to have a BGP message (RFC4271 4.1)
        if self.buffer.bytes < 19 {
            return 0;  # We don't have a message
        }

        # Check for valid marker
        if !self.valid-marker {
            die Net::BGP::Error::Marker-Format.new();
        }

        # Parse length
        my $expected-len = nuint16(self.buffer[16..17]);

        if $expected-len < 19 {
            # Too short - RFC4271 4.1
            die Net::BGP::Error::Length-Too-Short.new(:length($expected-len));
        }
        if $expected-len > 4096 {
            # Too long - RFC4271 4.1
            die Net::BGP::Error::Length-Too-Long.new(:length($expected-len));
        }

        if self.buffer.bytes < $expected-len {
            return; # We don't yet have the full message
        }

        # We delegate the hard work of parsing this message
        my $bgp-msg = Net::BGP::Message.from-raw( buf8.new(self.buffer[18..*]) );

        # Remove message
        self.buffer.splice: 0, $expected-len, ();

        # Here we go - hand back parsed hash
        return $bgp-msg;
    }

    method valid-marker(-->Bool) {
        if self.buffer.bytes < 16 { return False; }

        for ^16 -> $i {
            if self.buffer[$i] != 255 { return False; }
        }

        return True;
    }

}

=begin pod

=head1 NAME

Net::BGP::Connection - BGP Server Connection Class

=head1 SYNOPSIS

  use Net::BGP::Connection;

  my $conn    = Net::BGP::Connection.new(:socket($socket));
  my $id      = $conn.id;

  $conn.command.send($msg);

=head1 DESCRIPTION

Maintains the connection information for an active (in the TCP-sense) BGP
connection.

=head1 ATTRIBUTES

=head2 socket

The socket associated with this connection.

=head2 command

A channel used to send BGP commands to the connection.  See classes under
the C<Net::BGP::Command> namespace.

=head2 id

A unique ID number associated with this connection.

=head2 buffer

A C<buf8> buffer representing outstanding (unparsed) bytes.

=head1 METHODS

=head2 pop-bgp-message

  my $bgp-msg = $conn.pop-bgp-message;

Takes input from the connection buffer (C<$.buffer>) and removes (if possible)
one message from the buffer.  If a complete message is present, it returns
a C<Net::BGP::Message>.

It modifies the buffer when it removes the message.

This method also will throw BGP message errors if encountered.

=head2 valid-marker

  say "Valid marker received" if $conn.valid-marker;

Looks at the first 16 bytes of hte buffer to determine if a valid BGP marker
is present (I.E. 16 bytes consisting of value 255).  Returns a boolean true
or false value.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
