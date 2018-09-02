use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

class Net::BGP::Message:ver<0.0.0>:auth<cpan:JMASLAK> {
    my %registrations;
    my %message-types;

    # Message type Nil = handle all unhandled messages
    method register(Net::BGP::Message $class, Int $message-type, Str $message-code) {
        if defined $message-type {
            %registrations{ $message-type } = $class;
            %message-types{ $message-code } = $message-type;
        } else {
            %registrations<default> = $class;
        }
    }

    method new() {
        die("Must use from-raw or from-hash to construct a new object");
    }

    method raw() {
        die("Not implemented for parent class");
    }

    method from-raw(buf8:D $raw) {
        if %registrations{ $raw[0] }:exists {
            return %registrations{ $raw[0] }.from-raw($raw);
        } else {
            return %registrations<default>.from-raw($raw);
        }
    };

    method from-hash(%params is copy)  {
        if %params<message-code>:!exists and %params<message-type>:!exists {
            die "Could not determine message type";
        }
            
        # Normalize message-code
        if %params<message-code>:exists and %params<message-code> ~~ m/^ <[0..9]>+ $/ {
            if %params<message-type>:exists and %params<message-type> ≠ %params<message-code> {
                die("Message type and code don't agree");
            } else {
                %params<message-type> = Int(%params<message-code>);
                %params<message-code>:delete;
            }
        }

        # Fill in message type if needed
        if %params<message-type>:!exists {
            if %message-types{ %params<message-code> }:!exists {
                die("Unknown message code: %params<message-code>");
            }
            %params<message-type> = %message-types{ %params<message-code> };
        }

        # Make sure we have agreement 
        if %params<message-code>:exists and %params<message-type>:exists {
            if %message-types{ %params<message-code> } ne %params<message-type> {
                die("Message code and type don't agree");
            }
        }

        %params<message-code>:delete; # We don't use this in children.

        return %registrations{ %params<message-type> }.from-hash( %params );
    };

    method message-code() {
        die("Not implemented for parent class");
    }

    method message-type() {
        die("Not implemented for parent class");
    }
}

=begin pod

=head1 NAME

Net::BGP::Message - BGP Message Parent Class

=head1 SYNOPSIS

  use Net::BGP::Message;

  my $msg = Net::BGP::Message.from-raw( $raw );  # Might return a child crash

=head1 DESCRIPTION

Parent class for messages.

=head1 Constructors

=head2 from-raw

Constructs a new object (likely in a subclass) for a given raw binary buffer.

=head2 from-hash

Constructs a new object (likely in a subclass) for a given hash buffer.  This
module uses the C<message-type> or C<message-code> key of the hash to determine
which type of message should be returned.

=head1 Methods

=head2 message-type

Contains an integer that corresponds to the message-code.

=head2 message-code

Returns a string that describes what message type the command represents.

Currently understood types include C<OPEN>.

=head2 message-type

Contains an integer that corresponds to the message-code.

=head2 raw

Contains the raw message (not including the BGP header).


=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
