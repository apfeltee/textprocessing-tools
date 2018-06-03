#!/usr/bin/env perl

use URI::Encode;

my $uri = URI::Encode->new({ encode_reserved => 0 });
while (<>)
{
    print $uri->decode($_)
}
