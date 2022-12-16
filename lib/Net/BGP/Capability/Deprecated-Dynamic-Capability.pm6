use v6;

#
# Copyright © 2018-2019 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Capability;

use StrictClass;
unit class Net::BGP::Capability::Deprecated-Dynamic-Capability:ver<0.7.1>:auth<cpan:JMASLAK>
    is Net::BGP::Capability
    does StrictClass;

# Generic Types
method implemented-capability-code(-->Int) { 66 }
method implemented-capability-name(-->Str) { "Deprecated-Dynamic-Capability" }

method capability-name(-->Str:D) { self.implemented-capability-name }

method new() {
    die("Must use from-raw or from-hash to construct a new object");
}

method from-raw(buf8:D $raw where $raw.bytes == 2) {
    if $raw[0] ≠ self.implemented-capability-code {
        die("Can only build a {self.implemented-capability-name} capability");
    }
    if $raw[1] ≠ 0  { die("Bad capability length"); }

    my $obj = self.bless(:$raw);
    return $obj;
};

method from-hash(%params is copy)  {
    my @REQUIRED = «»;

    if %params<capability-code>:exists {
        if %params<capability-code> ≠ self.implemented-capability-code {
            die "Can only create a {self.implemented-capability-name} capability";
        }
        %params<capability-code>.delete;
    }

    if %params<capability-name>:exists {
        if %params<capability-name> ne self.implemented-capability-name {
            die "Can only create a {self.implemented-capability-name} capability";
        }
        %params<capability-name>.delete;
    }

    if @REQUIRED.sort.list !~~ %params.keys.sort.list {
        die("Did not provide proper options");
    }

    my buf8 $capability = buf8.new();
    $capability.append( self.implemented-capability-code );  # Code
    $capability.append( 0 );                                 # Length

    return self.bless(:raw( $capability ));
};

method Str(-->Str:D) { return self.implemented-capability-name }

# Register capability
INIT { Net::BGP::Capability.register(Net::BGP::Capability::Deprecated-Dynamic-Capability) }

=begin pod

=head1 NAME

Net::BGP::Message::Capability::Deprecated-Dynamic-Capability - BGP Deprecated-Dynamic-Capability Capability Object

=head1 SYNOPSIS

  use Net::BGP::Capability::Deprecated-Dynamic-Capability;

  my $cap = Net::BGP::Capability::Deprecated-Dynamic-Capability.from-raw( $raw );
  # or …
  my $cap = Net::BGP::Capability::Deprecated-Dynamic-Capability.from-hash( %{ } );

=head1 DESCRIPTION

BGP Capability Object

=head1 Constructors

=head2 from-raw

Constructs a new object for a given raw binary buffer.

=head2 from-hash

Constructs a new object for a given hash.  This parent class looks only for
the key of C<capability-code> and C<cvalue>.  Capability code should represent
the desired capability code.  Value should be a C<buf8> containing the payload
data (C<value> in RFC standards).

=head1 Methods

=head2 capability-code

Capability code of the object.

=head2 capability-name

The capability name of the object.

=head2 raw

Returns the raw (wire format) data for this capability.

=head2 payload

The raw byte buffer (C<buf8>) corresponding to the RFC definition of C<value>.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018-2019 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
