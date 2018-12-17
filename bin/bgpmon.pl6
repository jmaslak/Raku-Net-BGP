#!/usr/bin/env perl6
use v6.d;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP;
use Net::BGP::IP;
use Net::BGP::Time;

my subset Port of UInt where ^2¹⁶;
my subset Asn  of UInt where ^2¹⁶;

sub MAIN(
    Bool:D               :$passive? = False,
    Int:D                :$port = 179,
    Int:D                :$my-asn,
    Int:D                :$peer-asn,       # XXX should allow per-per spec
    Int                  :$max-log-messages,
    Net::BGP::IP::ipv4:D :$my-bgp-id,
    Int:D                :$batch-size = 32,
    *@peers
) {
    my $bgp = Net::BGP.new(
        :$port,
        :$my-asn,
        :identifier(ipv4-to-int($my-bgp-id))
    );

    # Add peers
    for @peers -> $peer-ip {
        $bgp.peer-add( :$peer-asn, :$peer-ip :$passive );  # XXX Should allow peer port spec
    }

    # Start the TCP socket
    $bgp.listen();
    lognote("Listening");

    my $channel = $bgp.user-channel;

    my $messages-logged = 0;
    my $start = monotonic-whole-seconds;

    react {
        whenever $channel -> $event is copy {
            my @stack;

            my uint32 $cnt = 0;
            repeat {
                @stack.push: $event;
                if $cnt++ ≤ 8*2*$batch-size {
                    $event = $channel.poll;
                } else {
                    $event = Nil;
                }
            } while $event.defined;

            if @stack.elems == 0 { next; }

            my @str;
            if (@stack.elems > $batch-size) {
                @str = @stack.hyper(
                    :degree(8), :batch((@stack.elems / 8).ceiling)
                ).map: { $^a.Str }
            } else {
                @str = @stack.map: { $^a.Str }
            }

            for @str -> $event {
                logevent($event);

                $messages-logged++;
                if $max-log-messages.defined && ($messages-logged ≥ $max-log-messages) {
                    log('*', "RUN TIME: " ~ (monotonic-whole-seconds() - $start) );
                    exit;
                }
            }
            @str.list.sink;
        }
    }
}

sub logevent(Str:D $event) {
    state $counter = 0;
    lognote("«" ~ $counter++ ~ "» " ~ $event);
}

sub lognote(Str:D $msg) {
    log('N', $msg);
}

sub log(Str:D $type, Str:D $msg) {
    say "[$type] $msg";
}


