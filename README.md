[![Build Status](https://travis-ci.org/jmaslak/Perl6-Net-BGP.svg?branch=master)](https://travis-ci.org/jmaslak/Perl6-Net-BGP)

NAME
====

Net::BGP - BGP Server Support

SYNOPSIS
========

    use Net::BGP

    my $bgp = Net::BGP.new( port => 179 );  # Create a server object

DESCRIPTION
===========

This provides framework to support the BGP protocol within a Perl6 application.

ATTRIBUTES
==========

port
----

The port attribute defaults to 179 (the IETF assigned port default), but can be set to any value between 0 and 65535. It can also be set to Nil, meaning that it will be an ephimeral port that will be set once the listener is started.

FUNCTIONS
=========

...
---

...

AUTHOR
======

Joelle Maslak <jmaslak@antelope.net>

COPYRIGHT AND LICENSE
=====================

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

