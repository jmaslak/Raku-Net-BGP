use v6.c;
use Test;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Message;

subtest 'Parent Class', {
    my $msg = Net::BGP::Message.new();
    ok $msg, "Created BGP Class";
    is $msg.message-type, 'NOOP', 'Message type has proper default';

    done-testing;
};

subtest 'New-Connection', {
    my $msg = Net::BGP::Message::New-Connection.new(
        :client-ip('192.0.2.1'),
        :client-port(1500),
    );
    ok $msg, "Created BGP Class";
    is $msg.message-type, 'New-Connection', 'Proper New-Connection message';
    is $msg.client-ip, '192.0.2.1', 'Client IP address';
    is $msg.client-port, 1500, 'Client IP port';

    done-testing;
};

subtest 'Stop', {
    my $msg = Net::BGP::Message::Stop.new();
    ok $msg, "Created BGP Class";
    is $msg.message-type, 'Stop', 'Proper Stop message';

    done-testing;
};

done-testing;

