use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

role Net::BGP::Controller-Handle-BGP:ver<0.0.0>:auth<cpan:JMASLAK> {
    use Net::BGP::Message;
    use Net::BGP::Message::Open;

    # Receive Messages
    multi method receive-bgp(Int:D $connection-id, Net::BGP::Message::Open:D $msg) { … }
    multi method receive-bgp(Int:D $connection-id, Net::BGP::Message:D $msg)       { … }
}
