use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Conversions;
use Net::BGP::Message;

class Net::BGP::Message::Open:ver<0.0.0>:auth<cpan:JMASLAK> is Net::BGP::Message {
    method new() {
        die("Must use from-raw or from-hash to construct a new object");
    }

    has buf8 $.data is rw;

    method message-type() { 1 }
    method message-code() { "OPEN" }

    # Stuff unique to OPEN
    method version()    { $.data[1] }
    method asn()        { nuint16($.data.subbuf(2, 2)) };
    method hold-time()  { nuint16($.data.subbuf(4, 2)) };
    method identifier() { nuint32($.data.subbuf(6, 4)) };

    method from-raw(buf8:D $raw where $raw.bytes ≥ 11) {
        return self.bless(:data( buf8.new($raw) ));
    };

    method from-hash(%params is copy)  {
        my @REQUIRED = «version asn hold-time identifier options»;

        # Optional parameters
        %params<version> //= 4;
        %params<options> //= buf8.new();

        # Delete unnecessary option
        if %params<message-type>:exists {
            if (%params<message-type> ≠ 1) { die("Invalid message type for OPEN"); }
            %params<message-type>:delete
        }

        if @REQUIRED.sort.list !~~ %params.keys.sort.list {
            die("Did not provide proper options"); # XXX Should this be a BGP::Error???
                # XXX: I think not, because this is a programming error,
                # not a data error.  But I'll need to stew on this a few
                # days.
        }

        if %params<version> ≠ 4 {
            die BGP::Notify::Error::Unknown-Version.new( :version(%params<version> ) );
        }

        if %params<hold-time> ≠ 0 and %params<hold-time> < 3 { die "Invalid hold time" }

        if %params<options>.bytes > 255 { die("Options too long for BGP message") }

        # Now we need to build the raw data.
        my $data = buf8.new();

        $data.append( 1 );   # Message type (OPEN)
        $data.append( %params<version> );
        $data.append( nuint16-buf8( %params<asn> ) );
        $data.append( nuint16-buf8( %params<hold-time> ) );
        $data.append( nuint32-buf8( %params<identifier>) );

        # Options
        $data.append( %params<options>.bytes );
        $data.append( %params<options> );

        return self.bless(:data( buf8.new($data) ));
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

=head2 version

Version field of the BGP message (currently this only supports version 4).

=head2 asn

The ASN field of the source of the OPEN message

=head hold-time

The hold time in seconds provided by the sender of the OPEN message

=head identifier

The BGP identifier of the sender.

=head2 raw

Returns the raw (wire format) data for this message.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
