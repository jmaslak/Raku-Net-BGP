use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Conversions;
use Net::BGP::IP;
use Net::BGP::CIDR;
use Net::BGP::Message;
use Net::BGP::Parameter;
use Net::BGP::Path-Attribute;
use Net::BGP::Path-Attribute::AS-Path;
use Net::BGP::Path-Attribute::Community;
use Net::BGP::Path-Attribute::Generic;
use Net::BGP::Path-Attribute::Local-Pref;
use Net::BGP::Path-Attribute::MED;
use Net::BGP::Path-Attribute::MP-NLRI;
use Net::BGP::Path-Attribute::Next-Hop;
use Net::BGP::Path-Attribute::Origin;
use Net::BGP::Path-Attribute::Originator-ID;
use Net::BGP::Path-Attribute::Cluster-List;

unit class Net::BGP::Message::Update:ver<0.0.0>:auth<cpan:JMASLAK>
is Net::BGP::Message;

has Bool:D $.asn32 is required;

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

method path-attributes(-->Array[Net::BGP::Path-Attribute:D]) {
    return Net::BGP::Path-Attribute.path-attributes(
        self.data.subbuf( self.path-start, self.path-length),
        :$!asn32
    );
}

method Str(-->Str) {
    my @lines;
    push @lines, "UPDATE";

    my $withdrawn = self.withdrawn;
    if $withdrawn.elems {
        push @lines, "WITHDRAWN: " ~ $withdrawn».Str ==> join(" ");
    }

    my $nlri = self.nlri;
    if $nlri.elems {
        push @lines, "NLRI: " ~ $nlri.join(" ");
    }

    my $path-attributes = self.path-attributes;
    for $path-attributes.sort( { $^a.path-attribute-code <=> $^b.path-attribute-code } ) -> $attr {
        push @lines, "  ATTRIBUTE: " ~ $attr.Str;
    }

    return join("\n      ", @lines);
}

method from-raw(buf8:D $raw where $raw.bytes ≥ 2, Bool:D :$asn32) {
    my $obj = self.bless(:data( buf8.new($raw) ), :$asn32);

    $obj.nlri-length();  # Just make sure we can read everything.
    # XXX Need to validate components

    return $obj;
};

method from-hash(%params is copy, Bool:D :$asn32) {
    my @REQUIRED = «
        withdrawn origin as-path next-hop med local-pref originator-id
        cluster-list community nlri address-family
    »;

    %params<withdrawn>      //= [];
    %params<origin>         //= '?';
    %params<as-path>        //= '';
    %params<next-hop>       //= '';
    %params<local-pref>     //= '';
    %params<med>            //= '';
    %params<community>      //= [];
    %params<originator-id>  //= '';
    %params<cluster-list>   //= '';
    %params<nlri>           //= [];
    %params<address-family> //= 'ipv4';

    # Delete unnecessary option
    if %params<message-code>:exists {
        if (%params<message-code> ≠ 2) { die("Invalid message type for UPDATE"); }
        %params<message-code>:delete
    }
    if %params<message-name>:exists {
        if (%params<message-name> ≠ 'UPDATE') {
            die("Invalid message type for UPDATE");
        }
        %params<message-name>:delete
    }

    if @REQUIRED.sort.list !~~ %params.keys.sort.list {
        die("Did not provide proper options");
    }

    if %params<address-family> ne 'ipv4' and %params<address-family> ne 'ipv6' {
        die("Cannot understand address family");
    }

    # Prefix parts
    my $withdrawn = buf8.new;
    for @(%params<withdrawn>) -> $w {
        $withdrawn.append: Net::BGP::CIDR.from-str($w).to-packed;
    };

    my $nlri = buf8.new;
    if %params<address-family> eq 'ipv4' {
        for @(%params<nlri>) -> $n {
            $nlri.append: Net::BGP::CIDR.from-str($n).to-packed;
        };
    }

    # Path Attributes
    my $path-attr = buf8.new;
    if %params<origin> ne '' {
        $path-attr.append: Net::BGP::Path-Attribute.from-hash(
            {
                path-attribute-name => 'Origin',
                origin              => %params<origin>,
            },
            :$asn32
        ).raw;
    }

    $path-attr.append: Net::BGP::Path-Attribute.from-hash(
        {
            path-attribute-name => 'AS-Path',
            as-path             => %params<as-path>,
        },
        :$asn32
    ).raw;

    if %params<address-family> eq 'ipv4' and %params<next-hop> ne '' {
        $path-attr.append: Net::BGP::Path-Attribute.from-hash(
            {
                path-attribute-name => 'Next-Hop',
                next-hop            => %params<next-hop>,
            },
            :$asn32
        ).raw;
    }

    if %params<med> ne '' {
        $path-attr.append: Net::BGP::Path-Attribute.from-hash(
            {
                path-attribute-name => 'MED',
                med                 => %params<med>,
            },
            :$asn32
        ).raw;
    }

    if %params<local-pref> ne '' {
        $path-attr.append: Net::BGP::Path-Attribute.from-hash(
            {
                path-attribute-name => 'Local-Pref',
                local-pref          => %params<local-pref>,
            },
            :$asn32
        ).raw;
    }

    if %params<community>.elems {
        $path-attr.append: Net::BGP::Path-Attribute.from-hash(
            {
                path-attribute-name => 'Community',
                community           => %params<community>,
            },
            :$asn32
        ).raw;
    }

    if %params<originator-id> ne '' {
        $path-attr.append: Net::BGP::Path-Attribute.from-hash(
            {
                path-attribute-name => 'Originator-ID',
                originator-id       => %params<originator-id>,
            },
            :$asn32
        ).raw;
    }

    if %params<cluster-list> ne '' {
        $path-attr.append: Net::BGP::Path-Attribute.from-hash(
            {
                path-attribute-name => 'Cluster-List',
                cluster-list        => %params<cluster-list>,
            },
            :$asn32
        ).raw;
    }
    
    if %params<address-family> eq 'ipv6' {
        if %params<nlri>.elems {
            $path-attr.append: Net::BGP::Path-Attribute.from-hash(
                {
                    path-attribute-name => 'MP-NLRI',
                    address-family      => %params<address-family>,
                    next-hop            => %params<next-hop>,
                    nlri                => %params<nlri>,
                },
                :$asn32
            ).raw;
        };
    }

    my $msg = buf8.new( 2 );                        # Message type
    $msg.append(nuint16-buf8( $withdrawn.bytes ) ); # Length of withdraw
    $msg.append($withdrawn);                        # Withdrawn
    $msg.append(nuint16-buf8( $path-attr.bytes ) ); # Length of path attributes
    $msg.append($path-attr);                        # Path attributes
    $msg.append($nlri);                             # NLRI

    return self.bless(:data( buf8.new($msg) ), :$asn32);
};

method nlri(-->Array[Net::BGP::CIDR:D]) {
    Net::BGP::CIDR.packed-to-array( $.data.subbuf( self.nlri-start(), self.nlri-length() ));
}

method withdrawn(-->Array[Net::BGP::CIDR:D]) {
    Net::BGP::CIDR.packed-to-array( $.data.subbuf( self.withdrawn-start(), self.withdrawn-length() ));
}

method raw() { return $.data; }


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

=head2 path-attributes

Returns an array of path attributes.

=head2 raw

Returns the raw (wire format) data for this message.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
