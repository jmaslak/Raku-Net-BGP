use v6.d;
use Test;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use experimental :pack;
use Net::BGP::Socket;
use Net::BGP::Socket-Connection;

subtest 'Basic', {
    my $inet = Net::BGP::Socket.new(:my-host('127.0.0.1'), :my-port(0));
    my $sock = $inet.socket;

    ok $sock ~~ Int, "sock is proper type";
    is $sock.defined, True, "sock is defined";

    lives-ok { $inet.bind }, "bind does not die";

    lives-ok { $inet.listen }, "listen does not die";
    
    ok $inet.bound-port ~~ Int, "bound port does not die";
    ok $inet.bound-port ~~ 1024..65535, "bound port in proper range";
    note "# Listening on port {$inet.bound-port}";

    my $connections = $inet.acceptor;
    ok $connections ~~ Supply, "connections is a Supply";

    my $client = IO::Socket::INET.new(:host<127.0.0.1>, :port($inet.bound-port));

    my $conn;
    my $promise = Promise.new;
    $connections.tap: { $conn = $_; $promise.keep };
    await $promise;

    ok $conn ~~ Socket-Connection, "conn is Socket-Connection";
    is $conn.defined, True, "conn is defined";
    is $conn.my-host, $inet.my-host, "my-host matches";
    is $conn.my-port, $inet.bound-port, "my-port matches bound-port";
    is $conn.peer-family, 2, "Peer family is AF_INET";
    is $conn.peer-host, $inet.my-host, "Connected to localhost";
    ok $conn.socket-fd ~~ UInt, "Socket is UInt";
    ok $conn.socket-fd > 0, "Socket is defined";

    my $str = "Hello, World!\n";
    $conn.write( buf8.new( $str.encode(:encoding('ascii')) ) );
    is $client.recv, $str, "Read line 1";
   
    $conn.print($str);
    is $client.recv, $str, "Read line 2";
  
    $str = "Hello, World!"; 
    $conn.say($str);
    is $client.recv, "$str\n", "Read line 3";

    $str = "Hello, World!\n";
    $client.print($str);
    is $conn.recv.unpack('a*'), $str, "Read line 4";

    $promise = Promise.new;
    my $buf;
    $client.print($str);
    $conn.Supply.tap: { $buf = $_; $promise.keep }
    await $promise;
    is $buf.unpack('a*'), $str, "Read line 5";

    $conn.buffered-send( buf8.new( $str.encode(:encoding('ascii')) ) );
    is $client.recv, $str, "Read line 6";
    $conn.buffered-send( buf8.new( $str.encode(:encoding('ascii')) ) );
    is $client.recv, $str, "Read line 7";
   
    done-testing;
};

done-testing;

