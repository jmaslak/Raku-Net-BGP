use v6;

#
# Copyright © 2018 Joelle Maslak
# All Rights Reserved - See License
#

role Net::BGP::Message::Creation-Role:ver<0.0.0>:auth<cpan:JMASLAK> {
    method from-raw(buf8:D $raw)      { … }
    method from-hash(%params is copy) { … }
}
