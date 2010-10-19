use strict;
use warnings;
use opts;
use Test::More;
use Text::Diff;

eval {
        @ARGV = qw(--help);
        foo();
};

is $@, <<EOS, 'help message';
usage: t/010_simple/10_help.t [options]

options:
   -p, --pi, -q   PI               
   -r, --radius   Radius of circle 
   -h, --help     This help message

EOS

done_testing;


sub foo {
    opts my $pi => { isa => 'Num', alias => 'q', comment => 'PI' },
         my $radius => { isa => 'Num', comment => 'radius of circle' };
    is $pi, 3.14;
}
