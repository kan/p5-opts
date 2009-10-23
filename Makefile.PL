use inc::Module::Install;
name 'opts';
all_from 'lib/opts.pm';

requires 'PadWalker'    => 1.9;
requires 'Getopt::Long' => 2.37;

tests ('t/*.t t/*/*.t');
author_tests 'xt';

auto_set_repository;
build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
