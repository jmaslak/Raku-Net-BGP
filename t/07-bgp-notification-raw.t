use v6.c;
use Test;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP;
use Net::BGP::Message;

subtest 'Open Notification Bad Version', {
    my $bgp = Net::BGP::Message.from-raw( read-message('notify-open-bad-version') );
    ok defined($bgp), "BGP message is defined";
    is $bgp.message-type, 4, 'Message type is correct';
    is $bgp.message-code, 'NOTIFY', 'Message code is correct';
    is $bgp.error-code, 2, 'Error code is correct';
    is $bgp.error-subcode, 1, 'Error subtype is correct';
    ok $bgp ~~ Net::BGP::Message::Notify::Open::Generic, 'Class is correct';
    ok check-list($bgp.payload, buf8.new(0,4)), 'Version is correct';
    ok check-list($bgp.raw, read-message('notify-open-bad-version')), 'Message value correct';

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

