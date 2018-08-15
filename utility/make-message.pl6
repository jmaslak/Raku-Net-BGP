#!/usr/bin/env perl6
use v6;

#
# Copyright (C) 2018 Joelle Maslak
# All Rights Reserved - See License
#

# Takes, on STDIN, an list of hex characters (in 00 - ff format),
# sepearted by spaces or new lines.
#
# Ex:
# ff ff ff ff   ff ff ff ff   ff ff ff ff   ff ff ff ff
# 00 13 00
#
# That will produce a 19 byte long file

sub MAIN() {
    my buf8 $buf = buf8.new;

    for $*IN.words -> $hex {
        $buf.append( :16($hex) );
    }

    $*OUT.write($buf);
}


