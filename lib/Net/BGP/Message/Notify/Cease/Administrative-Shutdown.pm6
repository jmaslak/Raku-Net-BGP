use v6;

#
# Copyright © 2018-2019 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Conversions;
use Net::BGP::Message::Notify::Cease;

use StrictClass;
unit class Net::BGP::Message::Notify::Cease::Administrative-Shutdown:ver<0.4.0>:auth<cpan:JMASLAK>
    is Net::BGP::Message::Notify::Cease
    does StrictClass;

method new() {
    die("Must use from-raw or from-hash to construct a new object");
}

# Administrative Shutdown Types
method implemented-error-subcode(-->Int) { 2 }
method implemented-error-subname(-->Str) { 'Administrative-Shutdown' }

method error-subname(-->Str) { .implemented-error-subname };

method from-raw(buf8:D $raw where $raw.bytes ≥ 3) {
    my $obj = self.bless(:data( buf8.new($raw) ));

    if $raw[0] ≠ 3 { # Not a notify
        die("Can only build a notification message");
    }
    if $raw[1] ≠ 6 { # Not an Cease error
        die("Can only build an Cease error notification message");
    }

    # Validate the parameters parse.
    # We could probably defer this - the controller will get to it,
    # but this is safer.
    # $obj.parameters;

    return $obj;
};

method from-hash(%params is copy)  {
    # Delete unnecessary options
    if %params<message-code>:exists {
        if (%params<message-code> ≠ 3) { die("Invalid message type for NOTIFY"); }
        %params<message-code>:delete;
    }
    if %params<error-code>:exists {
        if (%params<error-code> ≠ 6) { die("Invalid error type for Cease"); }
        %params<error-code>:delete;
    }

    if %params<error-subname>:exists {
        if (%params<error-subname> ne .implemented-error-subname) { die("Invalid error sub-name for Cease"); }
        %params<error-subcode> //= .implemented-error-subcode;
        %params<error-subcode>:delete;
    }

    my @REQUIRED = «error-subcode raw-data»;

    # Optional parameters
    %params<raw-data> //= buf8.new;

    if @REQUIRED.sort.list !~~ %params.keys.sort.list {
        die("Did not provide proper options");
    }
    
    if (%params<error-subcode> ≠ .implemented-error-subcode) { die("Invalid error subcode for Cease"); }

    # Now we need to build the raw data.
    my $data = buf8.new();

    $data.append( 3 );   # Message type (NOTIFY)
    $data.append( .implemented-error-code );   # Error code (Cease)
    $data.append( .implemented-error-subcode );
    $data.append( %params<raw-data> );

    return self.bless(:data( buf8.new($data) ));
};

method raw() { return $.data; }

method reason(-->Str:D) {
    if $.raw.bytes ≤ 3 { return '' }

    do {
        CATCH { return "Invalid UTF-8 Encoding - " ~ $.raw.perl };
        return $.raw.subbuf(3, $.raw.bytes - 3).decode('UTF-8');
    }
}

method Str(-->Str:D) {
    my $out = "NOTIFY CEASE Administrative-Shutdown";
    if self.reason ne '' {
        $out ~= " (Reason: " ~ self.reason ~ ")";
    }

    return $out;
}

# Register handler
INIT { Net::BGP::Message::Notify::Cease.register(Net::BGP::Message::Notify::Cease::Administrative-Shutdown) }

=begin pod

=head1 NAME

Net::BGP::Message::Notify::Cease::Administative-Shutdown - Administrative-Shutdown Cease Error BGP Notify Message

=head1 SYNOPSIS

  # We create Administrative-Shutdown messages using the parent class.

  use Net::BGP::Message;

  my $msg = Net::BGP::Message.from-raw( $raw );  # Might return a child crash

=head1 DESCRIPTION

Administrative-Shutdown Cease error BGP Notify message type

=head1 Constructors

=head2 from-raw

Constructs a new object for a given raw binary buffer.

=head2 from-hash

Constructs a new object from a given hash.

=head1 Methods

=head2 message-code

Returns a string that describes what message type the command represents.

Currently understood types include C<Cease>.

=head2 message-code

Contains an integer that corresponds to the message-code.

=head2 error-type

Error code of the notification.

=head2 error-subcode

Error subtype of the notification.

=head2 raw

Returns the raw (wire format) data for this message.

=head2 reason

Returns the reason code from the remote end (if sent)

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018-2019 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
