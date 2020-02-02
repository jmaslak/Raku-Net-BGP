#!/usr/bin/env perl6
use v6.d;

#
# Copyright © 2018-2020 Joelle Maslak
# All Rights Reserved - See License
#

unit class Net::BGP::Speaker:ver<0.0.1>:auth<cpan:JMASLAK>;

use Net::BGP::Speaker::Display;

our subset Asn  of Int:D where ^2³²;
our subset Port of Int:D where ^2¹⁶;

has Net::BGP::Speaker::Display:D $.display = Net::BGP::Speaker::Display.new();

submethod TWEAK(
    Bool:D :$colored = False,
) {
    $!display.colored = $colored;
}

# We simulate an attribute here.
multi method colored(                -->Bool:D) { $!display.colored }
multi method colored(Bool:D $colored -->Bool:D) { $!display.colored($colored) }

=begin pod

=head1 NAME

=head1 SYNOPSIS

    use Net::BGP::Speaker;
    
    $speaker = Net::BGP::Speaker.new(
        colored => True,
    )

=head1 TYPES

=head2 our subset Asn of Int:D where ^2³²

Defines a subset covering legal ASN numbers.

=head2 our subset Port of Int:D where ^2¹⁶

Defines a subset covering legal TCP/IP port numbers.

=head1 ATTRIBUTES

=head1 colored

Note that this attribute can't be set directly except at construction time,
however it can be changed via a helper method:

  say "Colored!" if $speaker.colored;
  $speaker.colored(True);  # Make colored

If this is set to true, log messages will be displayed using ANSI-compatible
colored text.

=head1 display

This is a L<Net::BGP::Speaker::Display> object.  It's intended to be
created during object construction, but it can be overriden by a subclass
of this object during construction.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018-2019 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artisitic License 2.0.

=end pod
