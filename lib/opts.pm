package opts;
use strict;
use warnings;
our $VERSION = '0.021';
use Exporter 'import';
use PadWalker qw/var_name/;
use Getopt::Long;

our @EXPORT = qw/opts/;

our $TYPE_CONSTRAINT = {
    'Bool'     => '!',
    'Str'      => '=s',
    'Int'      => '=i',
    'Num'      => '=f',
    'ArrayRef' => '=s@',
    'HashRef'  => '=s%', 
};

my %is_invocant = map{ $_ => undef } qw($self $class);

my $coerce_type_map = {};
my $coerce_generater = {};

sub opts {
    {
        package DB;
        # call of caller in DB package sets @DB::args,
        # which requires list context, but does not use return values
        () = caller(1);
    }

    # method call
    if(exists $is_invocant{ var_name(1, \$_[0]) || '' }){
        $_[0] = shift @DB::args;
        shift;
        # XXX: should we provide ways to check the type of invocant?
    }

    my @options;
    my %requireds;
    my %generaters;
    for(my $i = 0; $i < @_; $i++){

        (my $name = var_name(1, \$_[$i]))
            or  Carp::croak('usage: opts my $var => TYPE, ...');

        $name =~ s/^\$//;

        my $rule = _compile_rule($_[$i+1]);

        if (exists $rule->{default}) {
            $_[$i] = $rule->{default};
        }
        if (exists $rule->{required}) {
            $requireds{$name} = $i;
        }
        if (my $gen = $coerce_generater->{$rule->{isa}}) {
            $generaters{$name} = { idx => $i, gen => $gen };
        }

        $name .= '|' . $rule->{alias} if $rule->{alias};
        push @options, $name . $rule->{type} => \$_[$i];

        $i++ if defined $_[$i+1]; # discard type info
    }
    {
        my $err;
        local $SIG{__WARN__} = sub { $err = shift };
        GetOptions(@options) or Carp::croak($err);

        while ( my ($name, $idx) = each %requireds ) {
            unless (defined($_[$idx])) {
                Carp::croak("missing mandatory parameter named '\$$name'");
            }
        }
        while ( my ($name, $val) = each %generaters ) {
            $_[$val->{idx}] = $val->{gen}->($_[$val->{idx}]);
        }
    }
}

sub coerce ($$&) { ## no critic
    my ($isa, $type, $generater) = @_;

    $coerce_type_map->{$isa}  = $type;
    $coerce_generater->{$isa} = $generater;
}

sub _compile_rule {
    my ($rule) = @_;
    if (!defined $rule) {
        return +{ type => "!", isa => 'Bool' };
    }
    elsif (!ref $rule) { # single, non-ref parameter is a type name
        my $tc = _get_type_constraint($rule) || 
                 _get_type_constraint($coerce_type_map->{$rule}) or 
                 Carp::croak("cannot find type constraint '$rule'");
        return +{ type => $tc, isa => $rule };
    }
    else {
        my %ret;
        if ($rule->{isa}) {
            $ret{isa} = $rule->{isa};
            my $tc = _get_type_constraint($rule->{isa}) ||
                     _get_type_constraint($coerce_type_map->{$rule->{isa}}) or 
                     Carp::croak("cannot find type constraint '@{[$rule->{isa}]}'");
            $ret{type} = $tc;
        } else {
            $ret{isa} = 'Bool';
            $ret{type} = "!";
        }
        for my $key (qw(alias default required)) {
            if (exists $rule->{$key}) {
                $ret{$key} = $rule->{$key};
            }
        }
        return \%ret;
    }
}

sub _get_type_constraint {
    my $isa = shift;

    $TYPE_CONSTRAINT->{$isa};
}

1;
__END__

=head1 NAME

opts - simple command line option parser

=head1 SYNOPSIS

  # in script.pl
  use opts;

  opts my $foo => 'Int';

  ./script.pl --foo=4 # $foo => 4
  ./script.pl --foo 4 # $foo => 4
  ./script.pl -f=4    # $foo => 4

  # in script.pl
  opts my $foo => { 'Int', required => 1 },
       my $bar => 'Int';
  
  ./script.pl --foo=3 --bar=4 # $foo => 3, $bar => 4
  ./script.pl --foo=4         # $foo => 4, $bar => undef
  ./script.pl --bar=4         # error!

  # in script.pl
  opts my $foo => {isa => 'Int', default => 3},

  ./script.pl --foo=4     # $foo => 4
  ./script.pl             # $foo => 3

  # in script.pl
  opts my $foo => { isa => 'Int', alias => 'x|bar' };

  ./script.pl --foo=4 # $foo => 4
  ./script.pl --bar=4 # $foo => 4
  ./script.pl -f=4    # $foo => 4
  ./script.pl -x=4    # $foo => 4


=head1 DESCRIPTION

opts is DSL for command line option.

=head1 Options

  isa
     define option value type. see $opts::TYPE_CONSTRAINT.
     if you need more type, see opts::coerce

  required
    define option value is required.

  default
    define options default value.

  alias
    define option param's alias.

=head1 opts::coerce

  opts::coerce NewType => SrcType => generater;

  ex) 
    opts::coerce DateTime => 'Str' => sub { DateTime->strptime("%Y-%m-%d", shift) };

    opts my $date => 'DateTime';

    $date->ymd; # => yyyy/mm/dd

=head1 AUTHOR

Kan Fushihara E<lt>kan.fushihara at gmail.comE<gt>

=head1 SEE ALSO

L<http://github.com/tokuhirom/p5-args>, L<Getopt::Long>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
