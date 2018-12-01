use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Conversions;
use Net::BGP::Message::Notify::Open;

class Net::BGP::Message::Notify::Open::Unsupported-Version:ver<0.0.0>:auth<cpan:JMASLAK>
    is Net::BGP::Message::Notify::Open
{
    method new() {
        die("Must use from-raw or from-hash to construct a new object");
    }

    # Generic Types
    method implemented-error-subcode(-->Int) { 1 }
    method implemented-error-subname(-->Str) { "Unsupported-Version" }

    method from-raw(buf8:D $raw where $raw.bytes == 4) {
        my $obj = self.bless(:data( buf8.new($raw) ));

        if $raw[0] ≠ 4 { # Not a notify
            die("Can only build a notification message");
        }
        if $raw[1] ≠ 2 { # Not an Open error
            die("Can only build an Open error notification message");
        }

        # Validate the parameters parse.
        # We could probably defer this - the controller will get to it,
        # but this is safer.
        # $obj.parameters;

        return $obj;
    };

    method from-hash(%params is copy)  {
        my @REQUIRED = «max-supported-version»;

        # Optional parameters
        %params<max-supported-version> //= 4;

        if @REQUIRED.sort.list !~~ %params.keys.sort.list {
            die("Did not provide proper options");
        }

        # Now we need to build the raw data.
        my $data = buf8.new();

        $data.append( 4 );   # Message type (NOTIFY)
        $data.append( 2 );   # Error code (OPEN)
        $data.append( 1 );   # Unsupported version
        $data.append( nuint16-buf8( %params<max-supported-version> ) ); # Version supported

        return self.bless(:data( buf8.new($data) ));
    };

    method max-supported-version(-->Int) {
        return nuint16(self.data[2..3]);
    }
}

# Register handler
INIT { Net::BGP::Message::Notify.register(Net::BGP::Message::Notify::Open::Unsupported-Version) }

=begin pod

=head1 NAME

Net::BGP::Message::Notify::Open::Unsupported-Version - Unsupported Version Open Error BGP Notify Message

=head1 SYNOPSIS

  # We create generic messages using the parent class.

  use Net::BGP::Message;

  my $msg = Net::BGP::Message.from-raw( $raw );  # Might return a child crash

=head1 DESCRIPTION

Unsupported-Version Open error BGP Notify message type

=head1 Constructors

=head2 from-raw

Constructs a new object for a given raw binary buffer.

=head2 from-hash

Takes a hash with a single (optional) key - C<max-supported-version>.  If this
key isn't provided or is not defined, a max version of 4 is used.

=head1 Methods

=head2 message-code

Returns a string that describes what message type the command represents.

Currently understood types include C<OPEN>.

=head2 message-type

Contains an integer that corresponds to the message-code.

=head2 error-code

Error code of the notification.

=head2 error-subcode

Error subtype of the notification.

=head2 max-supported-version

Maximum supported version of BGP (16 bit unsigned integer).

=head2 raw

Returns the raw (wire format) data for this message.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
