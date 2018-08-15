use v6.c;
use Test;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Command;
use Net::BGP::Notify;

subtest 'Command' => {
    subtest 'Parent Class' => {
        my $msg = Net::BGP::Command.new();
        ok $msg, "Created BGP Class";
        is $msg.message-type, 'NOOP', 'Message type has proper default';

        done-testing;
    };

    subtest 'Stop' => {
        my $msg = Net::BGP::Command::Stop.new();
        ok $msg, "Created BGP Class";
        is $msg.message-type, 'Stop', 'Proper Stop message';

        done-testing;
    };

    done-testing;
};

subtest 'Notify' => {
    subtest 'Parent Class' => {
        my $msg = Net::BGP::Notify.new();
        ok $msg, "Created BGP Class";
        is $msg.message-type, 'NOOP', 'Message type has proper default';

        done-testing;
    };

    subtest 'Closed-Connection' => {
        my $msg = Net::BGP::Notify::Closed-Connection.new(
            :client-ip('192.0.2.1'),
            :client-port(1500),
        );
        ok $msg, "Created BGP Class";
        is $msg.message-type, 'Closed-Connection', 'Proper Closed-Connection message';
        is $msg.client-ip, '192.0.2.1', 'Client IP address';
        is $msg.client-port, 1500, 'Client IP port';

        done-testing;
    };

    subtest 'New-Connection' => {
        my $msg = Net::BGP::Notify::New-Connection.new(
            :client-ip('192.0.2.1'),
            :client-port(1500),
        );
        ok $msg, "Created BGP Class";
        is $msg.message-type, 'New-Connection', 'Proper New-Connection message';
        is $msg.client-ip, '192.0.2.1', 'Client IP address';
        is $msg.client-port, 1500, 'Client IP port';

        done-testing;
    };

    done-testing;
}

done-testing;

