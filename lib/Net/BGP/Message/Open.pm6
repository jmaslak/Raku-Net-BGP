use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Conversions;
use Net::BGP::Error::Bad-Option-Length;
use Net::BGP::Error::Hold-Time-Too-Short;
use Net::BGP::Error::Unknown-Version;
use Net::BGP::Message;
use Net::BGP::Parameter;

class Net::BGP::Message::Open:ver<0.0.0>:auth<cpan:JMASLAK>
    is Net::BGP::Message
{
    method new() {
        die("Must use from-raw or from-hash to construct a new object");
    }

    method implemented-message-code(--> Int) { 1 }
    method implemented-message-name(--> Str) { "OPEN" }

    method message-code() { 1 }
    method message-name() { "OPEN" }

    # Stuff unique to OPEN
    method version()    { $.data[1] }
    method asn()        { nuint16($.data.subbuf(2, 2)) }
    method hold-time()  { nuint16($.data.subbuf(4, 2)) }
    method identifier() { nuint32($.data.subbuf(6, 4)) }
    method option-len() { $.data[10] }

    method option(-->buf8) {
        if $.data[10] {
            return $.data.subbuf(11, $.data[10]);
        } else {
            return buf8.new();
        }
    }
    
    method parameters() {
        my $buf = self.option;

        return gather {
            while $buf.bytes {
                my $opt = Net::BGP::Parameter.from-raw($buf);
                take $opt;

                my $len = $opt.parameter-length() + 2;
                if $len < $buf.bytes {
                    $buf = $buf.subbuf($len);
                } else {
                    $buf = buf8.new;
                }
            }
        }
    }

    method from-raw(buf8:D $raw where $raw.bytes ≥ 11) {
        my $obj = self.bless(:data( buf8.new($raw) ));
        if $obj.version ≠ 4 { die Net::BGP::Error::Unknown-Version.new(:version($obj.version)) }
        if $obj.hold-time ≠ 0 and $obj.hold-time < 3 {
            die Net::BGP::Error::Hold-Time-Too-Short.new(:hold-time($obj.hold-time))
        }
        if $obj.option-len > 0 and $obj.option-len < 2 { # Too short for valid options
            die Net::BGP::Error::Bad-Option-Length.new(:length($obj.option-len));
        }
        if (11 + $obj.option-len) > $raw.bytes {
            die Net::BGP::Error::Bad-Option-Length.new(:length($obj.option-len));
        }

        # Validate the parameters parse.
        # We could probably defer this - the controller will get to it,
        # but this is safer.
        $obj.parameters;

        return $obj;
    };

    method from-hash(%params is copy)  {
        my @REQUIRED = «version asn hold-time identifier parameters»;

        # Optional parameters
        %params<version>    //= 4;
        %params<parameters> //= [];

        # Delete unnecessary option
        if %params<message-code>:exists {
            if (%params<message-code> ≠ 1) { die("Invalid message type for OPEN"); }
            %params<message-code>:delete
        }

        if @REQUIRED.sort.list !~~ %params.keys.sort.list {
            die("Did not provide proper options"); # XXX Should this be a BGP::Error???
                # XXX: I think not, because this is a programming error,
                # not a data error.  But I'll need to stew on this a few
                # days.
        }

        if %params<version> ≠ 4 {
            die BGP::Event::Error::Unknown-Version.new( :version(%params<version> ) );
        }

        if %params<hold-time> ≠ 0 and %params<hold-time> < 3 { die "Invalid hold time" }

        my buf8 $options = buf8.new();
        for |%params<parameters> -> $param-hash {
            $options.append( Net::BGP::Parameter.from-hash( $param-hash ).raw );
        }
        if $options.bytes > 255 { die("Options too long for BGP message") }

        # Now we need to build the raw data.
        my $data = buf8.new();

        $data.append( 1 );   # Message type (OPEN)
        $data.append( %params<version> );
        $data.append( nuint16-buf8( %params<asn> ) );
        $data.append( nuint16-buf8( %params<hold-time> ) );
        $data.append( nuint32-buf8( %params<identifier>) );

        # Options
        $data.append( $options.bytes );
        $data.append( $options );

        return self.bless(:data( buf8.new($data) ));
    };
    
    method raw() { return $.data; }
}

# Register handler
INIT { Net::BGP::Message.register: Net::BGP::Message::Open }

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

=head2 message-name

Returns a string that describes what message type the command represents.

Currently understood types include C<OPEN>.

=head2 message-code

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

Copyright © 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
