#!/usr/bin/env perl6
use v6.d;

#
# Copyright © 2018-2020 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::IP;
use Net::BGP::Speaker;
use Net::BGP::Time;
use Net::BGP::Validation;
use Sys::HostAddr;

my %last-path;
my %last-path-match;

sub MAIN(
    Bool:D                    :$passive = False,
    Net::BGP::Speaker::Port:D :$port = 179,
    Str                       :$listen-host,
    Net::BGP::Speaker::Asn:D  :$my-asn,
    UInt                      :$max-log-messages,
    Net::BGP::IP::ipv4:D      :$my-bgp-id = Sys::HostAddr.new.guess-ip-for-host('0.0.0.0'),
    Str                       :$hostname,
    Str                       :$domain,
    Int:D                     :$batch-size = 32,
    Str                       :$cidr-filter,
    Str                       :$asn-filter,
    Str                       :$announce,
    Str                       :$check-command,
    UInt:D                    :$check-seconds = 1,
    Str:D                     :$origin where ($origin eq 'i'|'e'|'?') = '?',
    Bool:D                    :$short-format = False,
    Bool:D                    :$af-ipv6 = False,
    Bool:D                    :$allow-unknown-peers = False,
    Bool:D                    :$send-experimental-path-attribute = False,
    Str:D                     :$communities = '',
    Bool:D                    :$lint-mode = False,
    Bool:D                    :$suppress-updates = False,
    Bool:D                    :$color = False, # XXX Should test for terminal
    Bool:D                    :$track = False,
    UInt:D                    :$cores = $*KERNEL.cpu-cores,
    UInt:D                    :$hold-time where { $^h == 0 or $^h ~~ 3..65535 } = 60,
    *@args is copy
) {
    my $speaker = Net::BGP::Speaker.new(
        allow-unknown-peers => $allow-unknown-peers,
        asn-filter          => $asn-filter,
        cidr-filter         => $cidr-filter,
        colored             => $color,
        listen-host         => $listen-host,
        listen-port         => $port,
        my-asn              => $my-asn,
        my-bgp-id           => $my-bgp-id,
        my-domain           => $domain,
        my-hostname         => $hostname,
    );

    $*OUT.out-buffer = False;

    # Add peers
    while @args {
        my $peer-ip  = @args.shift;
        if ! @args.elems { die("Must specify peer ASN after the peer IP"); }
        my Net::BGP::Speaker::Asn:D $peer-asn = @args.shift;

        my Str $md5;
        if @args.elems {
            if @args[0] ~~ m/^ '--md5='/ {
                $md5 = S/^ '--md5='// given @args.shift;
            }
        }

        $speaker.peer-add(
            :$peer-asn,
            :$peer-ip,
            :peer-port(179),
            :$passive,
            :ipv4(True),
            :ipv6($af-ipv6),
            :my-hold-time($hold-time),
            :$md5,
        );
    }

    # Build community list
    $speaker.communities = $communities.split(',') if $communities ne '';

    # Start the TCP socket
    $speaker.bgp.listen();
    lognote($speaker, "Listening") unless $short-format;
    short-format-output(short-line-header, Array.new) if $short-format;

    my $channel = $speaker.bgp.user-channel;

    my $messages-logged = 0;
    my $start = monotonic-whole-seconds;

    # Do initial check
    my $last-check-successful = False;
    if $check-command.defined {
        $last-check-successful = check-command($check-command);
    }

    # Send check events
    start {
        react {
            whenever Supply.interval($check-seconds, $check-seconds) {
                $channel.send("TICK");
            }
        }
    }

    react {
        my %connections;
        my %conn-af-ipv4;
        my %conn-af-ipv6;

        whenever $channel -> $event is copy {
            my @stack;

            my uint32 $cnt = 0;
            repeat {
                if $event ~~ Net::BGP::Event::BGP-Message {
                    if $event.message ~~ Net::BGP::Message::Open {
                        if $last-check-successful {
                            announce(
                                $speaker,
                                $announce,
                                $origin,
                                $event.connection-id,
                                :$send-experimental-path-attribute,
                                :peer-ip($event.peer),
                                :supports-ipv4($event.message.ipv4-support),
                                :supports-ipv6($event.message.ipv6-support),
                            );
                        }

                        %connections{ $event.connection-id }  = { peer-ip => $event.peer };
                        %conn-af-ipv4{ $event.connection-id } = $event.message.ipv4-support;
                        %conn-af-ipv6{ $event.connection-id } = $event.message.ipv6-support;
                    }
                } elsif $event ~~ Net::BGP::Event::Closed-Connection {
                    # We no longer want to track this.
                    %connections{ $event.connection-id }:delete;
                    %conn-af-ipv4{ $event.connection-id }:delete;
                    %conn-af-ipv6{ $event.connection-id }:delete;
                } elsif $event ~~ Str and $event eq 'TICK' {
                    my $prev-state = $last-check-successful;
                    $last-check-successful = check-command($check-command);

                    if $last-check-successful and !$prev-state {
                        for %connections.kv -> $connection-id, $v {
                            announce(
                                $speaker,
                                $announce,
                                $origin,
                                Int($connection-id),
                                :$send-experimental-path-attribute,
                                :peer-ip( $v<peer-ip> ),
                                :supports-ipv4(%conn-af-ipv4{ $connection-id }),
                                :supports-ipv6(%conn-af-ipv4{ $connection-id }),
                            );
                            # catch {}; # We ignore for now.
                        }
                    } elsif $prev-state and !$last-check-successful {
                        for %connections.keys -> $connection-id {
                            withdrawal(
                                $speaker,
                                $announce,
                                Int($connection-id),
                                :supports-ipv4(%conn-af-ipv4{ $connection-id }),
                                :supports-ipv6(%conn-af-ipv4{ $connection-id }),
                            );
                            # catch {}; # We ignore for now.
                        }
                    }

                    # We just fetch the next event here.
                    $event = $channel.poll;
                    next;
                }

                @stack.push: $event;
                if $cnt++ ≤ $cores*2*$batch-size {
                    $event = $channel.poll;
                } else {
                    $event = Any;
                }
            } while $event.defined;

            if @stack.elems == 0 { next; }

            my $degree = (@stack.elems > $batch-size) ?? $cores !! 1;
            my $batch  = (@stack.elems ÷ $degree).ceiling;

            my @events = @stack.hyper(
                :$degree,
                :$batch
            ).map( { map-event(
                :$speaker,
                :event($^a),
                :$lint-mode,
            ) } );

            for @events -> $event {
                $event<match> = is-filter-match(
                    $speaker,
                    $event<event>,
                    $event<nlri>,
                    $event<nlri6>,
                    $event<withdrawn>,
                    $event<withdrawn6>,
                    $event<as-path>,
                    $event<as-path-match>,
                    :$lint-mode,
                    :$track
                );

                if $track {
                    if $event<event> ~~ Net::BGP::Event::BGP-Message and $event<event>.message ~~ Net::BGP::Message::Update {
                        for $event<nlri><> -> $prefix {
                            if %last-path{$event<event>.peer}{$prefix}:exists {
                                $event<last-path>{$prefix} = %last-path{$event<event>.peer}{$prefix};
                            }
                            %last-path{$event<event>.peer}{$prefix} = $event<as-path>;
                            %last-path-match{$event<event>.peer}{$prefix} = $event<as-path-match>;
                        }
                        for $event<nlri6><> -> $prefix {
                            if %last-path{$event<event>.peer}{$prefix}:exists {
                                $event<last-path>{$prefix} = %last-path{$event<event>.peer}{$prefix};
                            }
                            %last-path{$event<event>.peer}{$prefix} = $event<as-path>;
                            %last-path-match{$event<event>.peer}{$prefix} = $event<as-path-match>;
                        }

                        for $event<withdrawn><> -> $prefix {
                            if %last-path{$event<event>.peer}{$prefix}:exists {
                                $event<last-path>{$prefix} = %last-path{$event<event>.peer}{$prefix};
                            }
                            %last-path{$event<event>.peer}{$prefix}:delete;
                            %last-path-match{$event<event>.peer}:delete;
                        }
                        for $event<withdrawn6><> -> $prefix {
                            if %last-path{$event<event>.peer}{$prefix}:exists {
                                $event<last-path>{$prefix} = %last-path{$event<event>.peer}{$prefix};
                            }
                            %last-path{$event<event>.peer}{$prefix}:delete;
                            %last-path-match{$event<event>.peer}:delete;
                        }
                    } elsif $event ~~ Net::BGP::Event::Closed-Connection {
                        %last-path{$event.peer}:delete;
                        %last-path-match{$event.peer}:delete;
                    }

                }
            }
            
            race for @events.race(:$degree, :$batch) {
                $_<str> = $short-format ?? short-lines($_<event>, $_<last-path>) !! $_<event>.Str;
            }

            # Only apply filter if we're filtering based on ASN or CIDR
            if $speaker.wanted-asn.elems + $speaker.wanted-cidr.elems > 0 {
                @events = @events.hyper(:$degree, :$batch).grep(
                    {
                        $^a<match>
                        || $^a<event> !~~ Net::BGP::Event::BGP-Message
                        || $^a<event>.message !~~ Net::BGP::Message::Update 
                    }
                );
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
                    long-format-output($speaker, $event<str>, $event<errors>, $event<match>, $event<last-path>)
                }

                $messages-logged++;
                if $max-log-messages.defined && ($messages-logged ≥ $max-log-messages) {
                    if ! $short-format {
                        $speaker.display.log(
                            '*',
                            "RUN TIME: " ~ (monotonic-whole-seconds() - $start),
                        );
                    }
                    exit;
                }
            }
        }
    }
}

sub announce(
               $speaker,
    Str        $announce,
    Str        $origin,
    Int:D      $connection-id,
    Str:D      :$peer-ip,
    Bool:D     :$send-experimental-path-attribute,
    Bool:D     :$supports-ipv4,
    Bool:D     :$supports-ipv6
    -->Nil
) {
    state %cached-next-hop;

    # Handle the experimental path attribute
    my @attrs;
    if $send-experimental-path-attribute {
        my %attr;
        %attr<path-attribute-code> = 255;
        %attr<optional>            = 1;
        %attr<transitive>          = 1;
        %attr<value>               = buf8.new(0..31);
        @attrs.push(%attr);
    }

    # Build the announcements
    my @announce-str = $announce.split(',') if $announce.defined;
    for @announce-str -> $info {
        # Don't advertise unsupported address families
        if ( $info.contains(':')) and (!$supports-ipv6) { next; }
        if (!$info.contains(':')) and (!$supports-ipv4) { next; }

        my @parts = $info.split('-');
        if (@parts.elems == 1) {
            if @parts[0].contains(':') and !$peer-ip.contains(':') {
                die "Announcement must be in format <ip>-<nexthop>";
            } elsif (!@parts[0].contains(':')) and $peer-ip.contains(':') {
                die "Announcement must be in format <ip>-<nexthop>";
            }

            @parts[1] = guess-peer-next-hop($peer-ip);
            die "Announcement must be in format <ip>-<nexthop>" unless @parts[1].defined;
        } else {
            die "Announcement must be in format <ip>-<nexthop>" unless @parts.elems == 2;
        }

        $speaker.bgp.announce(
            $connection-id,
            [ @parts[0] ],
            @parts[1],
            "",     # AS path
            $origin,
            :@attrs,
            :communities($speaker.communities),
        );
    }
}

sub withdrawal(
               $speaker,
    Str        $prefixes,
    Int:D      $connection-id,
    Bool:D     :$supports-ipv4,
    Bool:D     :$supports-ipv6
    -->Nil
) {

    # Build the withdrawal
    my @prefix-str = $prefixes.split(',') if $prefixes.defined;
    for @prefix-str -> $info {
        my @parts = $info.split('-');
        die "Announcement must be in format <ip>-<nexthop>" unless @parts.elems == 2;

        # Don't advertise unsupported address families
        if ( $info.contains(':')) and (!$supports-ipv6) { next; }
        if (!$info.contains(':')) and (!$supports-ipv4) { next; }

        $speaker.bgp.withdrawal($connection-id, [ @parts[0] ]);
    }
}

multi is-filter-match(
    $speaker,
    Net::BGP::Event::BGP-Message:D $event,
    @nlri,
    @nlri6,
    @withdrawn,
    @withdrawn6,
    @as-path,
    $as-path-match,
    :$lint-mode,
    :$track,
    -->Str
) {
    return '' unless $event.message ~~ Net::BGP::Message::Update; # We only care about UPDATEs
    return '' unless $speaker.wanted-asn.elems + $speaker.wanted-cidr.elems > 0;

    my $nlri      = 'NLRI';
    my $withdrawn = 'WITHDRAWN';

    my @m;

    if $speaker.wanted-cidr.elems {
        my $agg       = $event.message.aggregator-ip;
        $agg          = Net::BGP::CIDR.from-str("$agg/32") if $agg.defined;

        for $speaker.wanted-cidr.grep( { $^a.ip-version == 4 } ) -> $cidr {
            if @nlri.first\    ( { $cidr.contains($^a) } ).defined { @m.push($nlri) }
            if @withdrawn.first( { $cidr.contains($^a) } ).defined { @m.push($withdrawn) }

            if $agg.defined {
                if $cidr.contains($agg) { @m.push('AGGREGATOR-IP') }
            }
        }

        for $speaker.wanted-cidr.grep( { $^a.ip-version == 6 } ) -> $cidr {
            if @nlri6.first\    ( { $cidr.contains($^a) } ).defined { @m.push($nlri) }
            if @withdrawn6.first( { $cidr.contains($^a) } ).defined { @m.push($withdrawn) }
        }
    }

    if $speaker.wanted-asn.elems {
        if $as-path-match {
            @m.push('AS-PATH');
        }

        if $track {
            my @all-nlri = @nlri;
            @all-nlri.append: @nlri6;
            for @all-nlri -> $prefix {
                if %last-path-match{$event.peer}{$prefix} {
                    @m.push('PREFIX-PREVIOUS-MATCH');
                }
            }

            my @all-withdrawn = @withdrawn;
            @all-withdrawn.append: @all-withdrawn;
            for @all-withdrawn -> $prefix {
                if %last-path-match{$event.peer}{$prefix} {
                    @m.push('PREFIX-PREVIOUS-MATCH');
                }
            }
        }

        my $agg = $event.message.aggregator-asn;
        if $agg.defined && $speaker.wanted-asn.first( { $^a == $agg } ).defined {
            @m.push('AGGREGATOR-ASN');
        }
    }

    if @m.elems > 0 {
        return @m.sort.unique.join(" ");
    } else {
        return Str;
    }
}
multi is-filter-match(
    $speaker,
    $event,
    @nlri,
    @nlri6,
    @withdrawn,
    @withdrawn6,
    @as-path,
    $as-path-match,
    :$lint-mode,
    :$track
    -->Str
) {
    return $lint-mode ?? Str !! '';
}

sub logevent($speaker, Str:D $event) {
    state $counter = 0;

    lognote($speaker, "«" ~ $counter++ ~ "» " ~ $event);
}

sub lognote($speaker, Str:D $msg) {
    $speaker.display.log('N', $msg)
}

sub long-format-output($speaker, Str:D $event is copy, @errors, Str $match, %last-paths -->Nil) {
    if @errors.elems {
        for @errors -> $err {
            $event ~= "\n      ERROR: {$err.key} ({$err.value})";
        }
    }

    for %last-paths.keys.sort -> $prefix {
        $event ~= "\n      LAST PATH ($prefix): {%last-paths{$prefix}}";
    }

    if $match.defined and $match ne '' {
        $event ~= "\n      MATCH: $match";
    }

    logevent($speaker, $event);
}

sub short-format-output(Str:D $line, @errors -->Nil) {
    if @errors.elems {
        say $line ~ @errors».key.join(' ');
    } else {
        say $line;
    }
}

multi short-lines(Net::BGP::Event::BGP-Message:D $event, %last-paths -->Array[Str:D]) {
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
                    $event.creation-date,
                    %last-paths{$prefix}:exists ?? %last-paths{$prefix}.join(" ") !! '',
                );
            }
        } elsif $bgp.nlri6.elems {
            for @($bgp.nlri6) -> $prefix {
                push @out, short-line-announce6(
                    $prefix,
                    $event.peer,
                    $bgp,
                    $event.creation-date,
                    %last-paths{$prefix}:exists ?? %last-paths{$prefix}.join(" ") !! '',
                );
            }
        } elsif $bgp.withdrawn.elems {
            for @($bgp.withdrawn) -> $prefix {
                push @out, short-line-withdrawn(
                    $prefix,
                    $event.peer,
                    $event.creation-date,
                    %last-paths{$prefix}:exists ?? %last-paths{$prefix}.join(" ") !! '',
                );
            }
        } elsif $bgp.withdrawn6.elems {
            for @($bgp.withdrawn6) -> $prefix {
                push @out, short-line-withdrawn(
                    $prefix,
                    $event.peer,
                    $event.creation-date,
                    %last-paths{$prefix}:exists ?? %last-paths{$prefix}.join(" ") !! '',
                );
            }
        }
    } else {
        # Do nothing for other types of messgaes
    }

    return @out;
}

multi short-lines($event, %last-paths -->Array[Str:D]) { return Array[Str:D].new; }

sub short-line-header(-->Str:D) {
    return join("|",
        "Type",
        "Date",
        "Peer",
        "Prefix",
        "Next-Hop",
        "Path",
        "Communities",
        "Last-Path",
        "Errors",
    );
}

sub short-line-announce(
    Net::BGP::CIDR $prefix,
    Str:D $peer,
    Net::BGP::Message::Update $bgp,
    Int:D $message-date,
    Str:D $last-path,
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
        $last-path,
        '',
    );
}

sub short-line-announce6(
    Net::BGP::CIDR $prefix,
    Str:D $peer,
    Net::BGP::Message::Update $bgp,
    Int:D $message-date,
    Str:D $last-path,
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
        $last-path,
        '',
    );
}

sub short-line-withdrawn(
    Net::BGP::CIDR $prefix,
    Str:D $peer,
    Int:D $message-date,
    Str:D $last-path,
    -->Str:D
) {
    return join("|",
        "W",
        $message-date,
        $peer,
        $prefix,
        '',
        '',
        '',
        $last-path,
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
        '',
        '',
        '',
        '',
    );
}

# We short circuit on matches, and don't execute this full sub.
# This is a performance optimization.
sub map-event(
    :$speaker,
    :$event,
    :$lint-mode,
) {
    my $ret = Hash.new;
    $ret<event> = $event;
    $ret<last-path> = {};
    $ret<nlri> = [];
    $ret<nlri6> = [];
    $ret<withdrawn> = [];
    $ret<withdrawn6> = [];
    $ret<as-path> = [];
    $ret<as-path-match> = False;

    if $event ~~ Net::BGP::Event::BGP-Message and $event.message ~~ Net::BGP::Message::Update {
        $ret<nlri>.append: @( $event.message.nlri );
        $ret<nlri6>.append: @( $event.message.nlri6 );
        $ret<withdrawn>.append: @( $event.message.withdrawn );
        $ret<withdrawn6>.append: @( $event.message.withdrawn6 );

        $ret<as-path> = [ $event.message.as-array ];

        if $speaker.wanted-asn.elems {
            for $speaker.wanted-asn -> $as {
                if $as ∈ $ret<as-path> {
                    $ret<as-path-match> = True;
                }
            }
        }

        $ret<as-path>.push( $event.message.origin );
    }

    if $lint-mode and $event ~~ Net::BGP::Event::BGP-Message {
        $ret<errors> = Net::BGP::Validation::errors(
            :message($event.message),
            :my-asn($speaker.my-asn),
            :peer-asn($event.peer-asn),
        );
    } else {
        $ret<errors> = Array.new;
    }

    return $ret;
}

sub check-command(Str $cmd is copy) {
    return True unless $cmd.defined;

    $cmd ~= " >/dev/null 2>/dev/null";
    my $result = shell $cmd;

    if $result.exitcode == 0 {
        return True;
    } else {
        return False;
    }
}

sub guess-peer-next-hop(Str:D $peer-ip -->Str) {
    state %peer-nexthop-cache;
    return %peer-nexthop-cache{$peer-ip} if %peer-nexthop-cache{$peer-ip}:exists;

    my $ipv = $peer-ip.contains(':') ?? 6 !! 4;
    my $ha = Sys::HostAddr.new( ipv => $ipv );

    %peer-nexthop-cache{$peer-ip} = $ha.guess-ip-for-host($peer-ip);
    return %peer-nexthop-cache{$peer-ip};
}

multi sub splitter(Str:U $str, $pattern --> Iterable) { @() }
multi sub splitter(Str:D $str, $pattern --> Iterable) { $str.split($pattern) }

