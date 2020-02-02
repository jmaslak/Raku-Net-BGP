#!/usr/bin/env perl6
use v6.d;

#
# Copyright © 2018-2020 Joelle Maslak
# All Rights Reserved - See License
#

use StrictClass;

unit class Net::BGP::Speaker::Display:ver<0.0.1>:auth<cpan:JMASLAK>
    does StrictClass;

use Terminal::ANSIColor;

has Bool:D $.colored is rw = False;

method log(Str:D $type, Str:D $msg -->Nil) {
    my @lines = $msg.split("\n");
    my $first = @lines.shift;

    if $!colored {
        if ! @lines.elems {
            print color('cyan');
        } elsif (@lines[*-1] ~~ m/\s+ MATCH:.*WITHDRAWN/ ) {
            print color('red');
        } elsif (@lines[*-1] ~~ m/\s+ MATCH:.*NLRI/ ) {
            print color('green');
        } else {
            print color('cyan');
        }
    }

    say "{DateTime.now.Str} [$type] $first";
    say @lines.join("\n") if @lines.elems;

    print RESET if $!colored;
}


=begin pod

=head1 NAME

=head1 SYNOPSIS

    use Net::BGP::Speaker::Display;
    
    $display = Net::BGP::Speaker::Display.new(
        colored => True,
    )

    $display.log("N", $msg);

=head1 ATTRIBUTES

=head1 colored

If this is set to true, log messages will be displayed using ANSI-compatible
colored text.

=head1 METHODS

=head1 log(Str:D $type, Str:D $message -->Nil)

  $display->log("N", "Hello, World!")

Displays a log message.  C<$msg> may be a multi-line specially formatted
string from L<Net::BGP::Speaker>, which may trigger colorization if
C<colored> is set to C<True>.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018-2019 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artisitic License 2.0.

=end pod

