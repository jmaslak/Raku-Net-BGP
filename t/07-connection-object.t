use v6.c;
use Test;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Connection;

my $conn = Net::BGP::Connection.new();
ok $conn, "Created BGP Connection Class";

is $conn.id, 0, "Connection ID is proper";
is $conn.command.WHAT, Channel, "Connection command is proper type";
is $conn.command.defined, True, "Connection command is defined";
is $conn.socket.WHAT, IO::Socket::Async, "Connection socket is proper type";
is $conn.socket.defined, False, "Connection socket is not defined";

$conn = Net::BGP::Connection.new();
is $conn.id, 1, "Connection ID for second connection is proper";

done-testing;

