use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Conversions;
use Net::BGP::Message;
use Net::BGP::Message::Creation-Role;

class Net::BGP::Message::Notify:ver<0.0.0>:auth<cpan:JMASLAK>
    is Net::BGP::Message
    does Net::BGP::Message::Creation-Role
{
    method new() {
        die("Must use from-raw or from-hash to construct a new object");
    }

    has buf8 $.data is rw;

    method message-type() { 4 }
    method message-code() { "NOTIFY" }

    # Stuff unique to NOTIFY
    method error-code()    { $.data[1] }
    method error-subcode() { $.data[2] }

    method payload(-->buf8) {
        if $.data.bytes > 3 {
            return $.data.subbuf(3, $.data.bytes - 3);
        } else {
            return buf8.new();
        }
    }
    
    method from-raw(buf8:D $raw where $raw.bytes ≥ 3) {
        my $obj = self.bless(:data( buf8.new($raw) ));

        # Validate the parameters parse.
        # We could probably defer this - the controller will get to it,
        # but this is safer.
        # $obj.parameters;

        return $obj;
    };

    method from-hash(%params is copy)  {
        my @REQUIRED = «error-code error-subcode raw-data»;

        # Optional parameters
        %params<raw-data> //= buf8.new;

        # Delete unnecessary option
        if %params<message-type>:exists {
            if (%params<message-type> ≠ 4) { die("Invalid message type for NOTIFY"); }
            %params<message-type>:delete
        }

        if @REQUIRED.sort.list !~~ %params.keys.sort.list {
            die("Did not provide proper options");
        }

        # Now we need to build the raw data.
        my $data = buf8.new();

        $data.append( 4 );   # Message type (NOTIFY)
        $data.append( %params<error-code> );
        $data.append( %params<error-type> );
        $data.append( %params<raw-data> );

        return self.bless(:data( buf8.new($data) ));
    };
    
    method raw() { return $.data; }
}

# Register handler
Net::BGP::Message.register(Net::BGP::Message::Notify, 4, 'NOTIFY');

=begin pod

=head1 NAME

Net::BGP::Message::Notify - BGP Notify Message

=head1 SYNOPSIS

  # We create generic messages using the parent class.

  use Net::BGP::Message;

  my $msg = Net::BGP::Message.from-raw( $raw );  # Might return a child crash

=head1 DESCRIPTION

Notify BGP message type

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

=head2 error-code

Error code of the notification.

=head2 error-subcode

Error subtype of the notification.

=head2 raw

Returns the raw (wire format) data for this message.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
