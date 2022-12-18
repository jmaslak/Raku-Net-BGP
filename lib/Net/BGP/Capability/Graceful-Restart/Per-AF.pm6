use v6;

#
# Copyright © 2019 Joelle Maslak
# All Rights Reserved - See License
#

use Net::BGP::AFI  :ALL;
use Net::BGP::SAFI :ALL;

use StrictClass;
unit class Net::BGP::Capability::Graceful-Restart::Per-AF:ver<0.8.3>:auth<cpan:JMASLAK>
    does StrictClass;

has UInt:D $.afi   is required;
has UInt:D $.safi  is required;
has UInt:D $.flags is required;

method afi-name(-->Str:D) {
    return afi-name($.afi);
}

method safi-name(-->Str:D) {
    return safi-name($.safi);
}

method Str(-->Str:D) {
    return self.afi-name ~ "/" ~ self.safi-name ~ "/" ~ self.flags;
}

=begin pod

=head1 NAME

Net::BGP::Message::Capability::Graceful-Restart::Per-AF - BGP Graceful-Restart Per-Address-Family Object

=head1 SYNOPSIS

  use Net::BGP::Capability::Graceful-Restart::Per-AF;
  my $per-af = Net::BGP::Capability::Graceful-Restart::Per-AF.new(
    :afi(1),  # IP
    :safi(1), # Unicast
    :flags(0)
  );

  my $afi-name  = $per-af.afi-name;
  my $safi-name = $per-af.safi-name;

=head1 DESCRIPTION

BGP Graceful-Restart Per-Address-Family Object

=head1 ATTRIBUTES

=head2 afi

The value of the AFI.

=head2 safi

The value of the SAFI.

=head2 flags

The value of the graceful restart per-protocol flags.

=head1 METHODS

=head2 afi-name

Returns the name of the AFI (human-readible).

=head2 safi-name

Returns the name of the SAFI (human-readible).

=head2 Str

Returns a human-readable representation of the data.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
