#!/usr/bin/env perl6
use v6.d;

#
# Copyright © 2018-2019 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP;
use Net::BGP::IP;
use Net::BGP::Time;
use Net::BGP::Validation;
use Terminal::ANSIColor;

my subset Port of UInt where ^2¹⁶;
my subset Asn  of UInt where ^2¹⁶;

my $COLORED;

sub MAIN(
    Bool:D               :$passive = False,
    UInt:D               :$port = 179,
    Str:D                :$listen-host = '0.0.0.0',
    UInt:D               :$my-asn,
    UInt                 :$max-log-messages,
    Net::BGP::IP::ipv4:D :$my-bgp-id,
    Int:D                :$batch-size = 32,
    Str                  :$cidr-filter,
    Str:D                :$asn-filter,
    Str                  :$announce,
    Bool:D               :$short-format = False,
    Bool:D               :$af-ipv6 = False,
    Bool:D               :$allow-unknown-peers = False,
    Bool:D               :$send-experimental-path-attribute = False,
    Str:D                :$communities = '',
    Bool:D               :$lint-mode = False,
    Bool:D               :$suppress-updates = False,
    Bool:D               :$color = False, # XXX Should test for terminal
    *@args is copy
) {
    $COLORED = $color;

    $*OUT.out-buffer = False;

    my $bgp = Net::BGP.new(
        :$port,
        :$listen-host,
        :$my-asn,
        :identifier(ipv4-to-int($my-bgp-id)),
        :add-unknown-peers($allow-unknown-peers),
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

        $bgp.peer-add( :$peer-asn, :$peer-ip, :$passive, :ipv6($af-ipv6) );
    }

    # Build CIDR filter
    my @cidr-filter = gather {
        for splitter($cidr-filter, ',') -> $cidr {
            take Net::BGP::CIDR.from-str($cidr);
        }
    }

    # Build ASN filter
    my @asn-filter = gather {
        for splitter($asn-filter, ',') -> $asn {
            take $asn.UInt;
        }
    }

    # Start the TCP socket
    $bgp.listen();
    lognote("Listening") unless $short-format;
    short-format-output(short-line-header, Array.new) if $short-format;

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
                    if $event.message ~~ Net::BGP::Message::Open {
                        if %sent-connections{ $event.connection-id }:!exists {

                            my @communities;
                            @communities = $communities.split(',') if $communities ne '';

                            if $send-experimental-path-attribute {
                                my %attr;
                                %attr<path-attribute-code> = 255;
                                %attr<optional>            = 1;
                                %attr<transitive>          = 1;
                                %attr<value>               = buf8.new(0..31);
                                my @attrs;
                                @attrs.push(%attr);
                                announce(
                                    $bgp,
                                    $announce,
                                    $event.connection-id,
                                    :@attrs,
                                    :@communities,
                                    :supports-ipv4($event.message.ipv4-support),
                                    :supports-ipv6($event.message.ipv6-support),
                                );
                            } else {
                                announce(
                                    $bgp,
                                    $announce,
                                    $event.connection-id,
                                    :@communities,
                                    :supports-ipv4($event.message.ipv4-support),
                                    :supports-ipv6($event.message.ipv6-support),
                                );
                            }
                            %sent-connections{ $event.connection-id } = True;
                        }
                    }
                }

                @stack.push: $event;
                if $cnt++ ≤ $*KERNEL.cpu-cores*2*$batch-size {
                    $event = $channel.poll;
                } else {
                    $event = Nil;
                }
            } while $event.defined;

            if @stack.elems == 0 { next; }

            my @events;
            my @errlist;
            if (@stack.elems > $batch-size) {
                @events = @stack.hyper(
                    :degree($*KERNEL.cpu-cores),
                    :batch((@stack.elems / $*KERNEL.cpu-cores).ceiling)
                ).grep(
                    { is-filter-match($^a, :@cidr-filter, :@asn-filter, :$lint-mode) }
                ).map( { map-event($^a, $my-asn, $lint-mode, $short-format) } );

            } else {
                @events = @stack.grep(
                    { is-filter-match($^a, :@cidr-filter, :@asn-filter, :$lint-mode) }
                ).map( { map-event($^a, $my-asn, $lint-mode, $short-format) } );
            }

            for @events -> $event {
                if $event<event> ~~ Net::BGP::Event::BGP-Message {
                    if $lint-mode {
                        next unless $event<errors>.elems;  # In lint mode, we only show errors
                    }

                    # Skip updates if we suppress-updates
                    if $suppress-updates and ($event<event>.message ~~ Net::BGP::Message::Update) {
                        next;
                    }
                }

                if $short-format {
                    for @($event<str>) -> $entry {
                        short-format-output($entry, $event<errors>);
                    }
                } else {
                    long-format-output($event<str>, $event<errors>);
                }

                $messages-logged++;
                if $max-log-messages.defined && ($messages-logged ≥ $max-log-messages) {
                    if ! $short-format {
                        log('*', "RUN TIME: " ~ (monotonic-whole-seconds() - $start) );
                    }
                    exit;
                }
            }
            @events.list.sink;
        }
    }
}

sub announce(
    Net::BGP:D $bgp,
    Str        $announce,
    Int:D      $connection-id,
               :@attrs?,
               :@communities?,
    Bool:D     :$supports-ipv4,
    Bool:D     :$supports-ipv6
    -->Nil
) {
    # Build the announcements
    my @announce-str = $announce.split(',') if $announce.defined;
    for @announce-str -> $info {
        my @parts = $info.split('-');
        die "Announcement must be in format <ip>-<nexthop>" unless @parts.elems == 2;

        # Don't advertise unsupported address families
        if ( $info.contains(':')) and (!$supports-ipv6) { next; }
        if (!$info.contains(':')) and (!$supports-ipv4) { next; }

        $bgp.announce(
            $connection-id,
            [ @parts[0] ],
            @parts[1],
            :@attrs,
            :@communities,
        );
    }
}

multi is-filter-match(
    Net::BGP::Event::BGP-Message:D $event,
    :@cidr-filter,
    :@asn-filter,
    :$lint-mode
    -->Bool:D
) {
    if $event.message ~~ Net::BGP::Message::Update {
        if @asn-filter.elems + @cidr-filter.elems == 0 { return True }

        if @cidr-filter.elems {
            my @nlri = @( $event.message.nlri );
            for @cidr-filter.grep( { $^a.ip-version == 4 } ) -> $cidr {
                if @nlri.first( { $cidr.contains($^a) } ).defined { return True }
            }

            my @withdrawn = @( $event.message.withdrawn );
            for @cidr-filter.grep( { $^a.ip-version == 4 } ) -> $cidr {
                if @withdrawn.first( { $cidr.contains($^a) } ).defined { return True }
            }

            my @nlri6 = @( $event.message.nlri6 );
            for @cidr-filter.grep( { $^a.ip-version == 6 } ) -> $cidr {
                if @nlri6.first( { $cidr.contains($^a) } ).defined { return True }
            }

            my @withdrawn6 = @( $event.message.withdrawn6 );
            for @cidr-filter.grep( { $^a.ip-version == 6 } ) -> $cidr {
                if @withdrawn6.first( { $cidr.contains($^a) } ).defined { return True }
            }

            my $agg = $event.message.aggregator-ip;
            if $agg.defined {
                $agg = Net::BGP::CIDR.from-str("$agg/32");
                for @cidr-filter.grep( { $^a.ip-version == 4 } ) -> $cidr {
                    if $cidr.contains($agg) {
                        return True;
                    }
                }
            }
        }

        if @asn-filter.elems {
            my $agg = $event.message.aggregator-asn;
            if $agg.defined && @asn-filter.first( { $^a == $agg } ).defined { return True }

            for @asn-filter -> $cidr {
                if $event.message.as-array.first( { $^a == $cidr } ).defined {
                    return True
                }
            }
        }

        return False;
    } else {
        return !$lint-mode;
    }
}
multi is-filter-match($event, :@cidr-filter, :@asn-filter, :$lint-mode -->Bool:D) {
    return !$lint-mode;
}

multi get-str($event, :@cidr-filter -->Str) { $event.Str }

sub logevent(Str:D $event) {
    state $counter = 0;
    lognote("«" ~ $counter++ ~ "» " ~ $event);
}

sub lognote(Str:D $msg) {
    log('N', $msg);
}

sub log(Str:D $type, Str:D $msg, Bool:D $colored = $COLORED) {
    my @lines = $msg.split("\n");
    my $first = @lines.shift;

    print BOLD if $colored;
    print "{DateTime.now.Str} [$type] $first";
    print RESET if $colored;

    say "";
    say @lines.join("\n") if @lines.elems;
}

sub long-format-output(Str:D $event is copy, @errors -->Nil) {
    if @errors.elems {
        for @errors -> $err {
            $event ~= "\n      ERROR: {$err.key} ({$err.value})";
        }
    }
    logevent($event);
}

sub short-format-output(Str:D $line, @errors -->Nil) {
    if @errors.elems {
        say $line ~ @errors».key.join(' ');
    } else {
        say $line;
    }
}

multi short-lines(Net::BGP::Event::BGP-Message:D $event -->Array[Str:D]) {
    my Str:D @out;

    my $bgp = $event.message;
    if $bgp ~~ Net::BGP::Message::Open {
        push @out, short-line-open($event.peer, $event.creation-date);
    } elsif $bgp ~~ Net::BGP::Message::Update {
        if $bgp.nlri.elems {
            for @($bgp.nlri) -> $prefix {
                push @out, short-line-announce(
                    $prefix,
                    $event.peer,
                    $bgp,
                    $event.creation-date
                );
            }
        } elsif $bgp.nlri6.elems {
            for @($bgp.nlri6) -> $prefix {
                push @out, short-line-announce6(
                    $prefix,
                    $event.peer,
                    $bgp,
                    $event.creation-date
                );
            }
        } elsif $bgp.withdrawn.elems {
            for @($bgp.withdrawn6) -> $prefix {
                push @out, short-line-withdrawn(
                    $prefix,
                    $event.peer,
                    $event.creation-date
                );
            }
        } elsif $bgp.withdrawn6.elems {
            for @($bgp.withdrawn6) -> $prefix {
                push @out, short-line-withdrawn(
                    $prefix,
                    $event.peer,
                    $event.creation-date,
                );
            }
        }
    } else {
        # Do nothing for other types of messgaes
    }

    return @out;
}

multi short-lines($event -->Array[Str:D]) { return Array[Str:D].new; }

sub short-line-header(-->Str:D) {
    return join("|",
        "Type",
        "Date",
        "Peer",
        "Prefix",
        "Next-Hop",
        "Path",
        "Communities",
        "Errors",
    );
}

sub short-line-announce(
    Net::BGP::CIDR $prefix,
    Str:D $peer,
    Net::BGP::Message::Update $bgp,
    Int:D $message-date,
    -->Str:D
) {
    return join("|",
        "A",
        $message-date,
        $peer,
        $prefix,
        $bgp.next-hop,
        $bgp.path,
        $bgp.community-list.join(" "),
        '',
    );
}

sub short-line-announce6(
    Net::BGP::CIDR $prefix,
    Str:D $peer,
    Net::BGP::Message::Update $bgp,
    Int:D $message-date,
    -->Str:D
) {
    return join("|",
        "A",
        $message-date,
        $peer,
        $prefix,
        $bgp.next-hop6,
        $bgp.path,
        $bgp.community-list.join(" "),
        '',
    );
}

sub short-line-withdrawn(
    Net::BGP::CIDR $prefix,
    Str:D $peer,
    Int:D $message-date,
    -->Str:D
) {
    return join("|",
        "W",
        $message-date,
        $peer,
        $prefix,
        '',
    );
}

sub short-line-open(
    Str:D $peer,
    Int:D $message-date,
    -->Str:D
) {
    return join("|",
        "O",
        $message-date,
        $peer,
        '',
    );
}

sub map-event($event, $my-asn, $lint-mode, $short-format) {
    my $ret = Hash.new;
    $ret<event> = $event;
    $ret<str>   = $short-format ?? short-lines($event) !! $event.Str;

    if $lint-mode and $event ~~ Net::BGP::Event::BGP-Message {
        $ret<errors> = Net::BGP::Validation::errors(
            :message($event.message),
            :my-asn($my-asn),
            :peer-asn($event.peer-asn),
        );
    } else {
        $ret<errors> = Array.new;
    }

    return $ret;
}

multi sub splitter(Str:U $str, $pattern --> Iterable) { @() }
multi sub splitter(Str:D $str, $pattern --> Iterable) { $str.split($pattern) }

