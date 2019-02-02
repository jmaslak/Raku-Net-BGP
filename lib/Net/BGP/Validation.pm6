use v6.d;

#
# Copyright © 2019 Joelle Maslak
# All Rights Reserved - See License
#

unit module Net::BGP::Validation:ver<0.1.0>:auth<cpan:JMASLAK>;

use Net::BGP::CIDR;
use Net::BGP::Message;
use Net::BGP::Message::Update;

my %ERRORS;
%ERRORS<AFMIX>                  = "Multiple Address Families in a single BGP Update";
%ERRORS<AGGR_ASN_DOC>           = "Aggregator ASN is a documentation ASN";
%ERRORS<AGGR_ASN_PRIVATE>       = "Aggregator ASN is a private ASN";
%ERRORS<AGGR_ASN_RESERVED>      = "Aggregator ASN is a reserved ASN";
%ERRORS<AGGR_ASN_TRANS>         = "Aggregator ASN is the AS_TRANS ASN";
%ERRORS<AGGR_ID_BOGON>          = "Aggregator ID is a bogon";
%ERRORS<AS4_PEER_SENT_AS4_PATH> = "AS4-capable peer sent an AS4-Path attribute";

my Net::BGP::CIDR:D @BOGONS =
    Net::BGP::CIDR.from-str('0.0.0.0/8'),
    Net::BGP::CIDR.from-str('10.0.0.0/8'),
    Net::BGP::CIDR.from-str('100.64.0.0/10'),
    Net::BGP::CIDR.from-str('127.0.0.0/8'),
    Net::BGP::CIDR.from-str('172.16.0.0/12'),
    Net::BGP::CIDR.from-str('192.0.0.0/24'),
    Net::BGP::CIDR.from-str('192.0.2.0/24'),
    Net::BGP::CIDR.from-str('192.168.0.0/16'),
    Net::BGP::CIDR.from-str('198.18.0.0/15'),
    Net::BGP::CIDR.from-str('198.51.100.0/24'),
    Net::BGP::CIDR.from-str('203.0.113.0/24'),
    Net::BGP::CIDR.from-str('224.0.0.0/3'),
;
my Net::BGP::CIDR:D $ZERO = Net::BGP::CIDR.from-str('0.0.0.0/32');

our sub errors(
    Net::BGP::Message:D :$message,
    UInt:D :$my-asn,
    UInt:D :$peer-asn,
    -->Array[Pair:D]
) {
    return error_dispatch(:$message, :$my-asn, :$peer-asn);
}

multi sub error_dispatch(
    Net::BGP::Message::Update:D :$message,
    UInt:D :$my-asn,
    UInt:D :$peer-asn,
    -->Array[Pair:D]
) {
    my Pair:D @errors;

    # Check address families
    if ($message.nlri.elems or $message.withdrawn.elems)
        && ($message.nlri6.elems or $message.withdrawn6.elems)
    {
        @errors.push: error('AFMIX');
    }

    # Check aggregator
    my $agg = update-check-aggregator(:$message, :$my-asn, :$peer-asn);
    if $agg.elems { @errors.append: @$agg }

    # check path
    my $pth = update-check-aspath(:$message, :$my-asn, :$peer-asn);
    if $pth.elems { @errors.append: @$pth }

    return @errors;
}

sub update-check-aggregator(
    Net::BGP::Message::Update:D :$message,
    UInt:D :$my-asn,
    UInt:D :$peer-asn,
    -->Array[Pair:D]
) {
    my Pair:D @errors;

    if $message.aggregator-asn.defined {
        if $message.aggregator-asn == $my-asn {
            # Not an error
        } elsif $message.aggregator-asn == $peer-asn {
            # Not an error
        } elsif $message.aggregator-asn == 0 {
            @errors.push: error('AGGR_ASN_RESERVED');
        } elsif $message.aggregator-asn == 23456 {
            @errors.push: error('AGGR_ASN_TRANS');
        } elsif 64496 ≤ $message.aggregator-asn ≤ 64511 {
            @errors.push: error('AGGR_ASN_DOC');
        } elsif 64512 ≤ $message.aggregator-asn ≤ 65534 {
            @errors.push: error('AGGR_ASN_PRIVATE');
        } elsif $message.aggregator-asn == 65535 {
            @errors.push: error('AGGR_ASN_RESERVED');
        } elsif 65536 ≤ $message.aggregator-asn ≤ 65551 {
            @errors.push: error('AGGR_ASN_DOC');
        } elsif 65552 ≤ $message.aggregator-asn ≤ 131071 {
            @errors.push: error('AGGR_ASN_RESERVED');
        } elsif 4_200_000_000 ≤ $message.aggregator-asn ≤ 4_294_967_294 {
            @errors.push: error('AGGR_ASN_PRIVATE');
        } elsif $message.aggregator-asn == 4_294_967_295 {
            @errors.push: error('AGGR_ASN_RESERVED');
        }

        my $id-cidr = Net::BGP::CIDR.from-str($message.aggregator-ip ~ '/32');
        if $id-cidr.contains($ZERO) {
            # Not an issue, this is legitimate.
        } elsif @BOGONS.first({ $^a.contains($id-cidr) }).defined {
            @errors.push: error('AGGR_ID_BOGON');
        }
    }

    return @errors;
}

sub update-check-aspath(
    Net::BGP::Message::Update:D :$message,
    UInt:D :$my-asn,
    UInt:D :$peer-asn,
    -->Array[Pair:D]
) {
    my Pair:D @errors;

    my $as4 = $message.path-attributes.first( * ~~ Net::BGP::Path-Attribute::AS4-Path );
    my $as  = $message.path-attributes.first( * ~~ Net::BGP::Path-Attribute::AS-Path );

    # XXX We should validate we don't see more than one of these.

    if $as4.defined and $message.asn32 {
        @errors.push: error('AS4_PEER_SENT_AS4_PATH');
    }

    return @errors;
}

multi sub error_dispatch(
    Net::BGP::Message:D :$message,
    UInt:D :$my-asn,
    UInt:D :$peer-asn,
    -->Array[Pair:D]
) {
    my Pair:D @errors;
    # Currently we don't do any checking.
    return @errors;
}

sub error(Str:D $short --> Pair:D) {
    if %ERRORS{$short}:!exists { die("Error type $short does not exist") }
    return $short => %ERRORS{$short};
}

=begin pod

=head1 NAME

Net::BGP::Validation - Validate BGP Messages (Lint Mode)

=head1 SYNOPSIS

  ues Net::BGP::Validation;

  my @errors = Net::BGP::Validation::errors($msg);

=head1 ROUTINES

=head2 errors

Takes a BGP message, returns an array of pairs representing the warnings/errors
found in the message.  The key of the pair is the short code, the value is
a long description.

=head3 AFMIX

  Multiple Address Families in a single BGP Update

This BGP update contains both IPv4 and IPv6 NLRIs and/or withdrawn prefixes.

=head3 AGGR_ASN_DOC

  Aggregator ASN is a documentation ASN

This message has an Aggregator path-attribute with an ASN using a range of
ASNs reserved for use in documentation.

=head3 AGGR_ASN_PRIVATE

  Aggregator ASN is a private ASN

This message has an Aggregator path-attribute with an ASN using a range of
ASNs reserved for private use.

=head3 AGGR_ASN_RESERVED

  Aggregator ASN is a reserved ASN

This message has an Aggregator path-attribute with an ASN using a range of
ASNs that IANA indicates is "reserved".

=head3 AGGR_ASN_TRANS

  Aggregator ASN is the AS_TRANS ASN

This message has an Aggregator path-attribute with an ASN of 23456, which is
the BGP4 transitional ASN (and should not be seen on the internet after
processing an UPDATE message looking for an AS4_Aggregator path-attribute).

=head3 AGGR_ID_BOGON

  Aggregator ID is a bogon

This message has an Aggregator path-attribute with an IP in the bogon range
(except 0.0.0.0, which is valid).

=head3 AS4_PEER_SENT_AS4_PATH

An update message sent from an AS4-capable peer contains an AS4-Path attribute.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artisitc License 2.0.

=end pod

