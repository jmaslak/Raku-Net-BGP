use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Message;

class Net::BGP::Message::Open:ver<0.0.0>:auth<cpan:JMASLAK> is Net::BGP::Message {
    method new() {
        die("Must use from-raw or from-hash to construct a new object");
    }

    has buf8 $.data is rw;

    method message-type() { 1 }
    method message-code() { "OPEN" }

    method from-raw(buf8:D $raw where $raw.bytes ≥ 10) {
        return self.bless(:data( buf8.new($raw) ));
    };

    method from-hash(%params)  {
        die("Not implemented for generic BGP messages");
    };
    
    method raw() { return $.data; }
}

# Register handler
Net::BGP::Message.register(Net::BGP::Message::Open, 1, 'OPEN');

=begin pod

=head1 NAME

Net::BGP::Message::Open - BGP OPEN Message

=head1 SYNOPSIS

  # We create generic messages using the parent class.

  use Net::BGP::Message;

  my $msg = Net::BGP::Message.from-raw( $raw );  # Might return a child crash

=head1 DESCRIPTION

OPEN BGP message type

=head1 Constructors

=head2 from-raw

Constructs a new object for a given raw binary buffer.

=head2 from-hash

This simply throws an exception, since the hash format of a generic message
is not designed.

=head1 Methods

=head2 message-code

Returns a string that describes what message type the command represents.

Currently understood types include C<OPEN>.

=head2 message-type

Contains an integer that corresponds to the message-code.

=head2 raw

Returns the raw (wire format) data for this message.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
