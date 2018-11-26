use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Connection;
use OO::Monitors;

monitor Net::BGP::Connection-List:ver<0.0.0>:auth<cpan:JMASLAK> {

    has Net::BGP::Connection:D %!connections;

    method get(Int:D $id) {
        if %!connections{$id}:exists {
            return %!connections{$id};
        } else {
            die("Invalid connection ID");
        }
    }

    method add(Net::BGP::Connection:D $connection) {
        %!connections{ $connection.id } = $connection;
    }

    method remove(Int:D $id) {
        %!connections{ $id }:delete;
    }

};



