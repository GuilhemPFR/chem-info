#!/usr/bin/env perl -C24

use charnames qw{greek};
use utf8;
use FindBin;
use File::Spec::Functions qw{catdir};
use lib catdir $FindBin::Bin, qw{.. lib};
use lib catdir $FindBin::Bin, qw{.. cpan lib perl5};

use Applify;
use Data::Dumper;
use Encode;
use Mojo::Base -base;
use Mojo::Util qw{slurp};
use Chemistry::File::SDF;
use Compound;
use Resolver;
use Resolver::Hash;
use Resolver::Toxnet;

has app_result => 0;
has compound_list => sub {
  my $self = shift;
  my $list = [
    map  { s/_/ /g; $_ }
    grep { defined && length }
    split /\n/, Encode::decode 'utf8', slurp($self->compounds)
  ];
  _fisher_yates_shuffle_in_place($list) if $self->fisheryates;
  return $list;
};

has lookup => sub {
  my ($self, %name_to_cas) = @_;
  my @lines = split /\n/, slurp $self->synonyms;
  foreach my $line(@lines) {
    my ($name, $cas) = split /\t/, $line;
    $name_to_cas{lc $name} = $cas;
  }
  return \%name_to_cas;
};
has resolver => sub {
  my $self = shift;
  my $module = {
    cactus => 'Resolver',
    hash => 'Resolver::Hash',
    toxnet => 'Resolver::Toxnet'
  }->{lc $self->rtype};
  $module or die "no resolver found";
  "$module"->new(lookup => $self->lookup);
};

option file => compounds => 'file of compounds - one per line';
option file => synonyms => 'synonyms file';
option str => rtype => 'type of resolver to use' => 'toxnet'; ## only one
option flag => fisheryates => 'fisher yates' => 0;

has _prune_regex => sub {
  ## From man perlre
  qr/(\((?:[^()A-Za-z0-9]++|(?-1))*+\))[^A-Za-z0-9]*/;
};

app {
  my ($self, @args) = @_;
  my $cmp_names = $self->compound_list;
  my $count = 0;
  my $prune = $self->_prune_regex;
  foreach my $name( @$cmp_names ) {
    ## This causes an awesome error in the interface also...
    $name =~ s{CAPS \(3-\[Cyclohexylamino\]-1-propanesulfonic acid}{CAPS 3-(Cyclohexylamino)-1-propanesulfonic acid};
    ## greek to letter name
    $name =~ s/(\p{Greek})/_translate($1)/eg;
    ## bracketed prefices (-)-, (+)-, etc...
    $name =~ s{^$prune}{};
    my $cmp = Compound->new(name => lc $name);
    my $resolved = $self->resolver->resolve($cmp);
    $self->write_resolution($resolved);
  }
  warn Dumper $self->resolver->stats;
};

sub write_resolution {
  my ($self, $r) = @_;
  my $cmp = $r->query;
  if ($r->found) {
    if (0 == $r->distance) {
      ## write to lookup file
      print STDERR join("\t", 1, $cmp->name, $cmp->cas, $r->distance, ''), "\n";
    } else {
      ## write to lookup.check file
      print STDERR join("\t", 1, $cmp->name, $cmp->cas, $r->distance, $r->match), "\n";
    }
  } else {
    ## write to missing file
    print STDERR join("\t", 0, $cmp->name, '', '', ''), "\n";
  }
}

sub _fisher_yates_shuffle_in_place {
    my $array = shift @_;

    for(my $upper=scalar(@$array);--$upper;) {
        my $lower=int(rand($upper+1));
        next if $lower == $upper;
        @$array[$lower,$upper] = @$array[$upper,$lower];
    }
}

sub _translate {
  my $greek = shift;
  my @name = map { lc } split /\s/, charnames::viacode(ord $greek);
  return pop @name;
}
