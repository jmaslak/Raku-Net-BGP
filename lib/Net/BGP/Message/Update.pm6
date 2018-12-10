use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Conversions;
use Net::BGP::IP;
use Net::BGP::Message;
use Net::BGP::Parameter;

class Net::BGP::Message::Update:ver<0.0.0>:auth<cpan:JMASLAK>
    is Net::BGP::Message
{
    method new() {
        die("Must use from-raw or from-hash to construct a new object");
    }

    method implemented-message-code(--> Int) { 2 }
    method implemented-message-name(--> Str) { "UPDATE" }

    method message-code() { 2 }
    method message-name() { "UPDATE" }

    # Stuff unique to UPDATE
    method withdrawn-start(-->Int:D)  { 3 }
    method withdrawn-length(-->Int:D) { nuint16($.data.subbuf(1, 2)) }

    method path-start(-->Int:D)  { 5 + self.withdrawn-length }
    method path-length(-->Int:D) { nuint16( $.data.subbuf(3+self.withdrawn-length, 2) ) }

    method nlri-start(-->Int:D)  { self.path-start() + self.path-length; }
    method nlri-length(-->Int:D) { $.data.bytes - self.nlri-start() + 1; }

    method Str(-->Str) {
        my @lines;
        push @lines, "UPDATE";
        my $nlri = self.nlri;
        if $nlri.elems {
            push @lines, "NLRI: " ~ $nlri.join(" ");
        }
        return join("\n      ", @lines);
    }

    method from-raw(buf8:D $raw where $raw.bytes ≥ 2) {
        my $obj = self.bless(:data( buf8.new($raw) ));

        $obj.nlri-length();  # Just make sure we can read everything.

        return $obj;
    };

    method from-hash(%params is copy)  {
        my @REQUIRED = «»;

        # Delete unnecessary option
        if %params<message-code>:exists {
            if (%params<message-code> ≠ 2) { die("Invalid message type for UPDATE"); }
            %params<message-code>:delete
        }

        if @REQUIRED.sort.list !~~ %params.keys.sort.list {
            die("Did not provide proper options");
        }

        # Now we need to build the raw data.
        my $out = buf8.new();

        $out.append( 2 );   # Message type (UPDATE)

        return self.bless(:data( buf8.new($out) ));
    };

    method nlri(-->Array[Str:D]) {
        my $buf = $.data.subbuf( self.nlri-start(), self.nlri-length() );

        my Str:D @nlri = gather {
            while $buf.bytes {
                my $len = $buf[0];
                if $len > 32 { die("NLRI length too long"); }

                my $bytes = (($len+7) / 8).truncate;
                if $buf.bytes < (1 + $bytes) { die("NLRI payload too short") }

                my uint32 $ip = 0;
                if ($bytes > 0) { $ip += $buf[1] +< 24; }
                if ($bytes > 1) { $ip += $buf[2] +< 16; }
                if ($bytes > 2) { $ip += $buf[3] +< 8; }
                if ($bytes > 3) { $ip += $buf[4]; }

                $ip = $ip +> (32 - $len) +< (32 - $len);  # Zero any trailing bits
                take int-to-ipv4($ip) ~ "/$len";

                $buf.splice: 0, $bytes+1, ();
            }
        }

        return @nlri;
    }
    
    method raw() { return $.data; }
}

# Register handler
INIT { Net::BGP::Message.register: Net::BGP::Message::Update }

=begin pod

=head1 NAME

Net::BGP::Message::Update - BGP UPDATE Message

=head1 SYNOPSIS

  # We create generic messages using the parent class.

  use Net::BGP::Message;

  my $msg = Net::BGP::Message.from-raw( $raw );  # Might return a child crash

=head1 DESCRIPTION

UPDATE BGP message type

=head1 Constructors

=head2 from-raw

Constructs a new object for a given raw binary buffer.

=head2 from-hash

This simply throws an exception, since the hash format of a generic message
is not designed.

=head1 Methods

=head2 message-name

Returns a string that describes what message type the command represents.

Currently understood types include C<UPDATE>.

=head2 message-code

Contains an integer that corresponds to the message-code.

=head2 raw

Returns the raw (wire format) data for this message.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
