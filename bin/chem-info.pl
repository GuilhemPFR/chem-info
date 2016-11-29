#!/usr/bin/env perl

use FindBin;
use File::Spec::Functions qw{catdir};
use lib catdir $FindBin::Bin, qw{.. lib};
use lib catdir $FindBin::Bin, qw{.. cpan lib perl5};

use Applify;
use Data::Dumper;
use Mojo::Base -base;
use Mojo::Util qw{slurp};
use Compound;
use Resolver;

has app_result => 0;
has resolver => sub { Resolver->new };

option file => compounds => 'file of compounds - one per line';

app {
  my ($self, @args) = @_;
  my $cmp_names = [ grep { defined && length } split /\n/, slurp($self->compounds) ];
  foreach my $name( @$cmp_names ) {
    $name =~ s/_/ /g; ## names do not have underscores.
    my $cmp = Compound->new(name => $name);
    $self->resolver->resolve($cmp);
    warn Dumper $cmp;
  }
};
