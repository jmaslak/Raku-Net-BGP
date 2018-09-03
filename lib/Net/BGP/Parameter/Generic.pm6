use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Error::Bad-Parameter-Length;
use Net::BGP::Parameter;

class Net::BGP::Parameter::Generic:ver<0.0.0>:auth<cpan:JMASLAK> is Net::BGP::Parameter {
    method new() {
        die("Must use from-raw or from-hash to construct a new object");
    }

    has buf8 $.data is rw;

    method parameter-type() {
        return $.data[0];
    }

    method parameter-code() {
        return "$.parameter-type";
    }

    method from-raw(buf8:D $raw) {
        # Validate length
        if $raw.bytes < 2 {
            die(Net::BGP::Error::Bad-Parameter-Length.new(:length($raw.bytes)));
        }
        if $raw.bytes < ($raw[1] + 2) {
            die(Net::BGP::Error::Bad-Parameter-Length.new(:length($raw[1])));
        }

        return self.bless( :data(buf8.new($raw)) );
    };

    method from-hash(%params)  {
        my @REQUIRED = «parameter-type parameter-value»;

        # Delete unnecessary option
        if %params<parameter-code>:exists {
            if %params<parameter-type>.Str ≠ %params<parameter-code> {
                die("Parameter type and code don't match");
            }
            %params<parameter-type> = %params<parameter-code>.Int;
            %params<parameter-code>:delete
        }

        if @REQUIRED.sort.list !~~ %params.keys.sort.list {
            die("Did not provide proper parameter options");
        }
        
        # Max length is 253, because 253 + one byte type + one byte len = 255
        if %params<parameter-value>.bytes > 253 { die("Parameter too long"); }

        my buf8 $parameter = buf8.new();
        $parameter.append( %params<parameter-type> );
        $parameter.append( %params<parameter-value>.bytes );
        $parameter.append( %params<parameter-value> );

        return self.bless(:data( buf8.new($parameter) ));
    };

    method raw() { return $.data; }

    method parameter-length() {
        return $.data[1];
    }

    method parameter-value() {
        return $.data.subbuf(2, $.data[1]);
    }
}

# Register handler
Net::BGP::Parameter.register(Net::BGP::Parameter::Generic, Int, Str);

=begin pod

=head1 NAME

Net::BGP::Parameter::Generic - BGP Generic Parameter

=head1 SYNOPSIS

  # We create generic parameters using the parent class.

  use Net::BGP::Parameter;

  my $msg = Net::BGP::Parameter.from-raw( $raw );

=head1 DESCRIPTION

Generic (undefined) BGP parameter type

=head1 Constructors

=head2 from-raw

Constructs a new object for a given raw binary buffer.

=head2 from-hash

This simply throws an exception, since the hash format of a generic parameter
is not designed.

=head1 Methods

=head2 parameter-code

Returns a string that describes what parameter type the command represents.

This is the string representation of C<parameter-type()>.

=head2 parameter-type

Contains an integer that corresponds to the parameter-code.

=head2 parameter-length

Returns an integer that corresponds to the parameter value's length.

=head2 parameter-value

Returns a buffer that corresponds to the parameter value.

=head2 raw

Contains the raw (wire format) data for this parameter.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
