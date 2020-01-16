#!/usr/bin/env perl6
use v6.d;

#
# Copyright © 2018-2020 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP;
use Net::BGP::IP;
use Net::BGP::Time;
use Net::BGP::Validation;
use Terminal::ANSIColor;

my subset Port of UInt where ^2¹⁶;
my subset Asn  of UInt where ^2¹⁶;

my %last-path;

my $COLORED;

sub MAIN(
    Bool:D               :$passive = False,
    UInt:D               :$port = 179,
    Str:D                :$listen-host = '0.0.0.0',
    UInt:D               :$my-asn,
    UInt                 :$max-log-messages,
    Net::BGP::IP::ipv4:D :$my-bgp-id,
    Str                  :$hostname,
    Str                  :$domain,
    Int:D                :$batch-size = 32,
    Str                  :$cidr-filter,
    Str                  :$asn-filter,
    Str                  :$announce,
    Str                  :$check-command,
    UInt:D               :$check-seconds = 1,
    Str:D                :$origin where ($origin eq 'i'|'e'|'?') = '?',
    Bool:D               :$short-format = False,
    Bool:D               :$af-ipv6 = False,
    Bool:D               :$allow-unknown-peers = False,
    Bool:D               :$send-experimental-path-attribute = False,
    Str:D                :$communities = '',
    Bool:D               :$lint-mode = False,
    Bool:D               :$suppress-updates = False,
    Bool:D               :$color = False, # XXX Should test for terminal
    Bool:D               :$track = False,
    *@args is copy
) {
    $COLORED = $color;

    $*OUT.out-buffer = False;

    my $bgp = Net::BGP.new(
        :$port,
        :$listen-host,
        :$my-asn,
        :$hostname,
        :$domain,
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

    # Build community list
    my @communities;
    @communities = $communities.split(',') if $communities ne '';

    # Start the TCP socket
    $bgp.listen();
    lognote("Listening") unless $short-format;
    short-format-output(short-line-header, Array.new) if $short-format;

    my $channel = $bgp.user-channel;

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
                                $bgp,
                                $announce,
                                $origin,
                                $event.connection-id,
                                :$send-experimental-path-attribute,
                                :@communities,
                                :supports-ipv4($event.message.ipv4-support),
                                :supports-ipv6($event.message.ipv6-support),
                            );
                        }

                        %connections{ $event.connection-id } = True;
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
                        for %connections.keys -> $connection-id {
                            announce(
                                $bgp,
                                $announce,
                                $origin,
                                Int($connection-id),
                                :$send-experimental-path-attribute,
                                :@communities,
                                :supports-ipv4(%conn-af-ipv4{ $connection-id }),
                                :supports-ipv6(%conn-af-ipv4{ $connection-id }),
                            );
                            # catch {}; # We ignore for now.
                        }
                    } elsif $prev-state and !$last-check-successful {
                        for %connections.keys -> $connection-id {
                            withdrawal(
                                $bgp,
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
                ).map( { map-event(
                    :event($^a),
                    :$my-asn,
                    :$short-format,
                    :$lint-mode,
                    :@cidr-filter,
                    :@asn-filter,
                    :$track,
                ) } ).grep( { $^a<match>.defined } );

            } else {
                @events = @stack.map( { map-event(
                    :event($^a),
                    :$my-asn,
                    :$short-format,
                    :$lint-mode,
                    :@cidr-filter,
                    :@asn-filter,
                    :$track,
                ) } ).grep( { $^a<match>.defined } );
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
                    long-format-output($event<str>, $event<errors>, $event<match>, $event<last-path>);
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
    Str        $origin,
    Int:D      $connection-id,
    Bool:D     :$send-experimental-path-attribute,
               :@communities?,
    Bool:D     :$supports-ipv4,
    Bool:D     :$supports-ipv6
    -->Nil
) {

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
        my @parts = $info.split('-');
        die "Announcement must be in format <ip>-<nexthop>" unless @parts.elems == 2;

        # Don't advertise unsupported address families
        if ( $info.contains(':')) and (!$supports-ipv6) { next; }
        if (!$info.contains(':')) and (!$supports-ipv4) { next; }

        $bgp.announce(
            $connection-id,
            [ @parts[0] ],
            @parts[1],
            "",     # AS path
            $origin,
            :@attrs,
            :@communities,
        );
    }
}

sub withdrawal(
    Net::BGP:D $bgp,
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

        $bgp.withdrawal($connection-id, [ @parts[0] ]);
    }
}

multi is-filter-match(
    Net::BGP::Event::BGP-Message:D $event,
    :@cidr-filter,
    :@asn-filter,
    :$lint-mode,
    :$colored = $COLORED,
    :$track,
    -->Str
) {
    return '' unless $event.message ~~ Net::BGP::Message::Update; # We only care about UPDATEs
    return '' unless @asn-filter.elems + @cidr-filter.elems > 0;

    my $nlri      = 'NLRI';
    my $withdrawn = 'WITHDRAWN';

    my @m;

    if @cidr-filter.elems {
        my @nlri      = @( $event.message.nlri );
        my @withdrawn = @( $event.message.withdrawn );
        my $agg       = $event.message.aggregator-ip;
        $agg          = Net::BGP::CIDR.from-str("$agg/32") if $agg.defined;

        for @cidr-filter.grep( { $^a.ip-version == 4 } ) -> $cidr {
            if @nlri.first\    ( { $cidr.contains($^a) } ).defined { @m.push($nlri) }
            if @withdrawn.first( { $cidr.contains($^a) } ).defined { @m.push($withdrawn) }

            if $agg.defined {
                if $cidr.contains($agg) { @m.push('AGGREGATOR-IP') }
            }
        }

        my @nlri6      = @( $event.message.nlri6 );
        my @withdrawn6 = @( $event.message.withdrawn6 );
        for @cidr-filter.grep( { $^a.ip-version == 6 } ) -> $cidr {
            if @nlri6.first\    ( { $cidr.contains($^a) } ).defined { @m.push($nlri) }
            if @withdrawn6.first( { $cidr.contains($^a) } ).defined { @m.push($withdrawn) }
        }
    }

    if @asn-filter.elems {
        for @asn-filter -> $as {
            if $event.message.as-array.first( { $^a == $as } ).defined {
                @m.push('AS-PATH');
            }
        }

        if $track {
            my @nlri = @( $event.message.nlri );
            @nlri.append: @($event.message.nlri6);
            for @nlri -> $prefix {
                if %last-path{$event.peer}{$prefix}:exists {
                    if @asn-filter.elems {
                        for @asn-filter -> $as {
                            if $as ∈ %last-path{$event.peer}{$prefix} {
                                @m.push('PREFIX-PREVIOUS-MATCH');
                            }
                        }
                    }
               }
            }

            my @withdrawn = @( $event.message.withdrawn );
            @withdrawn.append: @($event.message.withdrawn6);
            for @withdrawn -> $prefix {
                if %last-path{$event.peer}{$prefix}:exists {
                    if @asn-filter.elems {
                        for @asn-filter -> $as {
                            if $as ∈ %last-path{$event.peer}{$prefix} {
                                @m.push('PREFIX-PREVIOUS-MATCH');
                            }
                        }
                    }
               }
           }
        }

        my $agg = $event.message.aggregator-asn;
        if $agg.defined && @asn-filter.first( { $^a == $agg } ).defined {
            @m.push('AGGREGATOR-ASN');
        }
    }

    if @m.elems > 0 {
        return @m.sort.unique.join(" ");
    } else {
        return Str;
    }
}
multi is-filter-match($event, :@cidr-filter, :@asn-filter, :$lint-mode, :$track -->Str) {
    return $lint-mode ?? Str !! '';
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

    if $colored {
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
    print "{DateTime.now.Str} [$type] $first";

    say "";
    say @lines.join("\n") if @lines.elems;

    print RESET if $colored;
}

sub long-format-output(Str:D $event is copy, @errors, Str $match, %last-paths -->Nil) {
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

    logevent($event);
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
    :$event,
    :$my-asn,
    :$short-format,
    :$lint-mode,
    :@cidr-filter,
    :@asn-filter,
    :$track,
) {
    my $ret = Hash.new;
    $ret<event> = $event;
    $ret<match> = is-filter-match($event, :@cidr-filter, :@asn-filter, :$lint-mode, :$track);
    $ret<last-path> = {};

    return $ret unless $ret<match>.defined; # Short circuit here.

    if $track {
        if $event ~~ Net::BGP::Event::BGP-Message and $event.message ~~ Net::BGP::Message::Update {
            my @nlri = @( $event.message.nlri );
            @nlri.append: @( $event.message.nlri6 );
            for @nlri -> $prefix {
                if %last-path{$event.peer}{$prefix}:exists {
                    $ret<last-path>{$prefix} = %last-path{$event.peer}{$prefix};
                }

                my @old-path = @( $event.message.as-array );
                @old-path.push( $event.message.origin );
                %last-path{$event.peer}{$prefix} = @old-path;
            }

            my @withdrawn = @( $event.message.withdrawn );
            @withdrawn.append: @( $event.message.withdrawn6 );
            for @withdrawn -> $prefix {
                if %last-path{$event.peer}{$prefix}:exists {
                    $ret<last-path>{$prefix} = %last-path{$event.peer}{$prefix};
                }

                %last-path{$event.peer}{$prefix}:delete;
            }
        }
    }

    $ret<str>   = $short-format ?? short-lines($event, $ret<last-path>) !! $event.Str;

    if $lint-mode and $event ~~ Net::BGP::Event::BGP-Message {
        $ret<errors> = Net::BGP::Validation::errors(
            :message($event.message),
            :my-asn($my-asn),
            :peer-asn($event.peer-asn),
        );
    } else {
        $ret<errors> = Array.new;
    }

    if $event ~~ Net::BGP::Event::Closed-Connection {
        %last-path{$event.peer}:delete;
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

multi sub splitter(Str:U $str, $pattern --> Iterable) { @() }
multi sub splitter(Str:D $str, $pattern --> Iterable) { $str.split($pattern) }

