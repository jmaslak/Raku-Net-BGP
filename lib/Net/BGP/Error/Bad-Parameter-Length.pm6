use v6;

#
# Copyright © 2018-2019 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::Error;

use StrictClass;
unit class Net::BGP::Error::Bad-Parameter-Length:ver<0.9.0>:auth<zef:jmaslak>
    is Net::BGP::Error
    does StrictClass;

has $.length;  # Set to the length in the OPEN message

method message-name(-->Str) { 'Bad-Parameter-Length' };
method message(-->Str)      { 'Parameter Length in OPEN is invalid' };

=begin pod

=head1 NAME

Net::BGP::Error::Bad-Parameter-Length - BGP Parameter Length in OPEN is invalid

=head1 SYNOPSIS

  use Net::BGP::Error::Bad-Parameter-Length;

  my $msg = Net::BGP::Error::Bad-Parameter-Length.new(:length(1));

=head1 DESCRIPTION

A BGP parameter length in OPEN is unsupported.

The Bad-Parameter-Length error is sent from the BGP server to the user code.
This error is triggered when an OPEN message is received that has a parameter
length that does not fit within the message (it's too long or is implausable).

=head1 METHODS

=head2 message-name

Contains the string C<Bad-Parameter-Length>.

=head2 is-error

Returns True (that this is an error).

=head2 message

Returns a human-readable error message.

=head1 ATTRIBUTES

=head2 length

The parameter length from the message

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018-2019 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
