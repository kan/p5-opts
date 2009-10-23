use strict;
use warnings;
use opts;
use Test::More;
use Test::Exception;

is foo(), 99;
done_testing;
exit;

sub foo {
    opts my $p => { isa => 'Int', default => 99 };
    return $p;
}
