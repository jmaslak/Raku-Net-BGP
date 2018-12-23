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
    Bool:D               :$passive = False,
    Int:D                :$port = 179,
    Int:D                :$my-asn,
    Int                  :$max-log-messages,
    Net::BGP::IP::ipv4:D :$my-bgp-id,
    Int:D                :$batch-size = 32,
    Str                  :$cidr-filter,
    Str                  :$announce,
    *@args is copy
) {
    my $bgp = Net::BGP.new(
        :$port,
        :$my-asn,
        :identifier(ipv4-to-int($my-bgp-id)),
    );

    # Add peers
    while @args {
        my $peer-ip  = @args.shift;
        if ! @args.elems { die("Must specify peer ASN after the peer IP"); }
        my $peer-asn = @args.shift;
       
        my $md5; 
        if @args.elems {
            if @args[0] ~~ m/^ '--md5='/ {
                $md5 = S/^ '--md5='// given @args.shift;
                $bgp.add-md5($peer-ip, $md5);
            }
        }

        $bgp.peer-add( :$peer-asn, :$peer-ip :$passive );
    }

    # Build CIDR filter
    my @cidr-str = $cidr-filter.split(',') if $cidr-filter.defined;
    my @cidr-filter = gather {
        for @cidr-str -> $cidr {
            take Net::BGP::CIDR.from-str($cidr);
        }
    }

    # Build the announcements
    my @announce-str = $announce.split(',') if $announce.defined;
    my @announcements = @announce-str.map: -> $info {
        my @parts = $info.split('-');
        if @parts.elems ≠ 2 { die("Ammouncement must be in format <ip>-<nexthop>") }
        Net::BGP::Message.from-hash(
            {
                message-name => 'UPDATE',
                as-path      => '',             # XXX We do something different for eBGP
                local-pref   => 100,            # XXX Set localpref
                origin       => 'I',
                next-hop     => @parts[1],
                nlri         => @parts[0],
            },
            :asn32,     # Should change depending on host
        );
    }

    # Start the TCP socket
    $bgp.listen();
    lognote("Listening");

    my $channel = $bgp.user-channel;

    my $messages-logged = 0;
    my $start = monotonic-whole-seconds;

    react {
        my %sent-connections;

        whenever $channel -> $event is copy {
            my @stack;

            my uint32 $cnt = 0;
            repeat {
                if $event ~~ Net::BGP::Event::BGP-Message {
                    if $event.message ~~ Net::BGP::Message::Keep-Alive {
                        if %sent-connections{ $event.connection-id }:!exists {
                            for @announcements -> $bgpmsg {
                                say "Sending announcement for {$bgpmsg.nlri[0]}";
                                $bgp.send-bgp( $event.connection-id, $bgpmsg );
                            }
                            %sent-connections{ $event.connection-id } = True;
                        }
                    }
                }

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
                ).grep(
                    { is-filter-match($^a, :@cidr-filter) }
                ).map: { $^a.Str };
            } else {
                @str = @stack.map: { $^a.Str }
                @str = @stack.grep(
                    { is-filter-match($^a, :@cidr-filter) }
                ).map: { $^a.Str };
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

multi is-filter-match(Net::BGP::Event::BGP-Message:D $event, :@cidr-filter -->Bool:D ) {
    if $event.message ~~ Net::BGP::Message::Update {
        if ! @cidr-filter.elems { return True }

        my @nlri = @( $event.message.nlri );
        for @cidr-filter.grep( { $^a.ip-version == 4 } ) -> $cidr {
            if @nlri.first( { $cidr.contains($^a) } ).defined { return True; }
        }

        my @withdrawn = @( $event.message.withdrawn );
        for @cidr-filter.grep( { $^a.ip-version == 4 } ) -> $cidr {
            if @withdrawn.first( { $cidr.contains($^a) } ).defined { return True; }
        }

        my @nlri6 = @( $event.message.nlri6 );
        for @cidr-filter.grep( { $^a.ip-version == 6 } ) -> $cidr {
            if @nlri6.first( { $cidr.contains($^a) } ).defined { return True; }
        }

        my @withdrawn6 = @( $event.message.withdrawn6 );
        for @cidr-filter.grep( { $^a.ip-version == 6 } ) -> $cidr {
            if @withdrawn6.first( { $cidr.contains($^a) } ).defined { return True; }
        }

        return False;
    } else {
        return True;
    }
}
multi is-filter-match($event, :@cidr-filter -->Bool:D) { True }

multi get-str($event, :@cidr-filter -->Str) { $event.Str }

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


