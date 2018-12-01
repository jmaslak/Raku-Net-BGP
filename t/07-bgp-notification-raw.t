use v6.c;
use Test;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP;
use Net::BGP::Message;

subtest 'Open Notification Unsupported Version', {
    my $bgp = Net::BGP::Message.from-raw( read-message('notify-open-bad-version') );
    ok defined($bgp), "BGP message is defined";
    is $bgp.message-type, 4, 'Message type is correct';
    is $bgp.message-code, 'NOTIFY', 'Message code is correct';
    is $bgp.error-code, 2, 'Error code is correct';
    is $bgp.error-name, 'Open', 'Error name is correct';
    is $bgp.error-subcode, 1, 'Error subtype is correct';
    is $bgp.error-subname, 'Unsupported-Version', 'Error subtype is correct';
    ok $bgp ~~ Net::BGP::Message::Notify::Open::Unsupported-Version, 'Class is correct';
    is $bgp.max-supported-version, 4, 'Version is correct';
    ok check-list($bgp.raw, read-message('notify-open-bad-version')), 'Message value correct';

    done-testing;
};

subtest 'Open Notification Bad Peer AS', {
    my $bgp = Net::BGP::Message.from-raw( read-message('notify-open-bad-peer-asn') );
    ok defined($bgp), "BGP message is defined";
    is $bgp.message-type, 4, 'Message type is correct';
    is $bgp.message-code, 'NOTIFY', 'Message code is correct';
    is $bgp.error-code, 2, 'Error code is correct';
    is $bgp.error-name, 'Open', 'Error name is correct';
    is $bgp.error-subcode, 2, 'Error subtype is correct';
    is $bgp.error-subname, 'Bad-Peer-AS', 'Error subtype is correct';
    ok $bgp ~~ Net::BGP::Message::Notify::Open::Bad-Peer-AS, 'Class is correct';
    ok check-list($bgp.raw, read-message('notify-open-bad-peer-asn')), 'Message value correct';

    done-testing;
};

done-testing;

sub read-message($filename) {
    buf8.new( slurp("t/bgp-messages/$filename.msg", :bin)[18..*] ); # Strip header
}

sub check-list($a, $b -->Bool) {
    warn $a.elems if $a.elems != $b.elems;
    warn $b.elems if $a.elems != $b.elems;
    if $a.elems != $b.elems { return False; }
    return [&&] $a.values Z== $b.values;
}

