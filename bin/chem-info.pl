#!/usr/bin/env perl -CS

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
use utf8;

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

has output_fh => sub {
  my ($self) = @_;
  return \*STDERR unless $self->output;
  open my $fh, '>:encoding(UTF-8)', $self->output;
  return $fh;
};

has resolver => sub {
  my $self = shift;
  my $module = {
    cactus => sub { Resolver->new() },
    hash => sub { Resolver::Hash->new(lookup => $_[0]->lookup) },
    toxnet => sub { Resolver::Toxnet->new() }
  }->{lc $self->rtype};
  $module or die "no resolver found";
  $module->($self);
};

option file => compounds => 'file of compounds - one per line';
option file => synonyms => 'synonyms file';
option file => output => 'output tab separated file' => 'output.tsv';
option str => rtype => 'type of resolver to use' => 'toxnet'; ## only one
option flag => fisheryates => 'fisher yates' => 0;
option flag => excel => 'flag to write a file Excel can read without converting to dates' => 0;

has _prune_regex => sub {
  ## From man perlre
  qr/(\((?:[^()A-Za-z0-9]++|(?-1))*+\))[^A-Za-z0-9]*/;
};

app {
  my ($self, @args) = @_;
  my $cmp_names = $self->compound_list;
  my $count = 0;
  my $prune = $self->_prune_regex;
  $self->write_header();
  foreach my $name( @$cmp_names ) {
    my $canonical = $self->canonicalise($prune, $name);
    my $cmp = Compound->new(name => $canonical);
    my $resolved = $self->resolver->resolve($cmp);
    $resolved->query($name);
    $self->write_resolution($resolved);
  }

};

sub canonicalise {
  my ($self, $prune, $name) = @_;
  ## This causes an awesome error in the interface also...
  (my $canonical = $name) =~ s{CAPS \(3-\[Cyclohexylamino\]-1-propanesulfonic acid}{CAPS 3-(Cyclohexylamino)-1-propanesulfonic acid};
  ## greek to letter name
  $canonical =~ s/(\p{Greek})/_translate($1)/eg;
  ## bracketed prefices (-)-, (+)-, etc...
  $canonical =~ s{^$prune}{};

  return lc $canonical;
}

sub write_header {
  my ($self) = @_;
  my $fh = $self->output_fh;
  print $fh join("\t", qw{resolved name cas edit match original_name}), "\n";
}

sub write_resolution {
  my ($self, $r) = @_;
  my $cmp = $r->compound;
  my $fh = $self->output_fh;
  my $excel = ($self->excel ? chr(39) : ''); # chr(39) = '

  print $fh join("\t",
    $r->found, $cmp->name,
    ($cmp->cas ? $excel . $cmp->cas : ''),
    $r->distance,
    $r->match || '',
    $r->query), "\n";
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
