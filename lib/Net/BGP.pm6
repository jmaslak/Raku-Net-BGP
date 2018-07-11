use v6.c;

class Net::BGP:ver<0.0.0>:auth<cpan:JMASLAK> {
    use StrictNamedArguments;

    our subset PortNum of Int where ^65536;

    has PortNum $.port is default(179);

    submethod BUILD( *%args ) {
        for %args.keys -> $k {
            if $k eq 'port' {
                $!port := %args{$k} if defined %args{$k};
            } else {
                die("Invalid attribute set in call to constructor: $k");
            }
        }
    }
};

=begin pod

=head1 NAME

Net::BGP - BGP Server Support

=head1 SYNOPSIS

  use Net::BGP

  my $bgp = Net::BGP.new( port => 179 );  # Create a server object

=head1 DESCRIPTION

This provides framework to support the BGP protocol within a Perl6 application.

=head1 ATTRIBUTES

=head2 port

The port attribute defaults to 179 (the IETF assigned port default), but can
be set to any value between 0 and 65535.  It can also be set to Nil, meaning
that it will be an ephimeral port that will be set once the listener is
started.

=head1 METHODS

=head2 ...

...

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
