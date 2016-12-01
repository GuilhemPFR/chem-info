package Resolver::Toxnet::Result;
use Mojo::Base -base;

has 'code' => -1; ## -1, 0, 1
has 'count' => 0;
has 'dbname';
has 'tmpfile';

package Resolver::Toxnet;

use Data::Dumper;
use Mojo::Base qw{Resolver};
use Mojo::DOM;
use Text::Levenshtein::XS qw{distance};
use List::Util qw{min};
use Resolved;

has stemming => 0;

sub _process_results {
  my ($self, $cmp, $result) = @_;
  my $url = Mojo::URL->new(q{https://toxgate.nlm.nih.gov/cgi-bin/sis/search2/g});
  my $compound_names = {};
  my $max_distance = int(min(length($cmp->name) * 0.5, 10));
  my $base = Mojo::URL->new(q{https://toxgate.nlm.nih.gov/cgi-bin/sis/search2/r});
  my $query = join '+', 'dbs', $result->dbname;
  my $max_count = ($result->count <= 25 ? $result->count : 25);
  for (my $i = 0; $i <= $max_count; $i += 10) {
    $url->query(join ':', $result->tmpfile, $i);
    my $res = $self->user_agent->get($url => {Accept => '*/*'})->res;
    my $doc = $base->clone;

    $res->dom->find('docsum')->each(sub {
      my ($dom, $item) = @_;
      my $docnum = $dom->at('docno')->text;
      my $docno = join '+', '@term', '@DOCNO', $docnum;
      $doc->query(join ':', $query, $docno);

      my $name = $dom->at('na') ? lc $dom->at('na')->text : '____unknown____';
      my $regno = $dom->at('rn') ? $dom->at('rn')->text : undef;
      my $edit_distance = distance($cmp->name, $name);
      if ($max_distance > $edit_distance) {
        $compound_names->{$name} = { distance => $edit_distance, cas => $regno };
      }
    });
  }
  return $compound_names;
}

sub _search2_call {
  my ($self, $cmp, $db) = @_;
  my $result;
  my ($tempfile, $count);
  my $url = q{https://toxgate.nlm.nih.gov/cgi-bin/sis/search2};
  my $tx = $self->user_agent->post($url => form => {
    queryxxx => $cmp->name,
    database => lc($db),
    Stemming => $self->stemming,
    and => 1,
    second_search => 1,
    gateway => 1,
    chemsyn => 1
  });
  if ((my $res = $tx->success) && length($tx->res->body)) {
    my $translation = $res->dom->at('translation')
      ? $res->dom->at('translation')->all_text
      : die $res->body;
    if ($translation =~ m/CAS Registry Number: ([0-9\-]+)/) {
      # warn "CAS: $1, Name: $cmp->{name}, DB: $db\n";
      $result = Resolver::Toxnet::Result->new(
        code => 1,
        dbname => $db
      );
      $cmp->cas_list([$1]);
    } else {
      $tempfile = $res->dom->at('temporaryfile')->text;
      $count = $res->dom->at('count')->text;
      # warn "tmpfile: $tempfile, count: $count, Name: $cmp->{name}\n";
      $result = Resolver::Toxnet::Result->new(
        code => 0,
        count => $count,
        dbname => $db,
        tmpfile => $tempfile,
        );
    }
  } else {
    # warn Dumper $tx->error, $cmp->name;
    $result = Resolver::Toxnet::Result->new(
      code => -1,
      dbname => $db
    );
  }
  return $result;
}

sub resolve {
  my ($self, $cmp) = @_;
  my $resolved = Resolved->new(query => $cmp);
  my @resultset = $self->_search2_call($cmp, 'hsdb');

  if ($resultset[0]->code > 0) {
    $resolved->found(1);
  } elsif (0 == $resultset[0]->code) {
    push @resultset, $self->_search2_call($cmp, 'chemid');

    if ($resultset[-1]->code > 0) {
      $resolved->found(1);
    } else {
      @resultset = (
        sort { $a->count <=> $b->count }
        grep { 0 == $_->code && 0 != $_->count } @resultset
      );

      if(my ($first) = @resultset) {
        my $hits = $self->_process_results($cmp, $first);
        if (my $close = scalar(keys %$hits)) {
          my ($first) = sort {
            $hits->{$a}->{'distance'} <=> $hits->{$b}->{'distance'}
          } keys %$hits;
          my ($cas, $dist) = @{$hits->{$first}}{qw{cas distance}};
          $cmp->cas_list([$cas]);
          $resolved->found(1);
          $resolved->match($first);
          $resolved->distance($dist);
        }
      }
    }
  }
  $self->update_stats($resolved);
  return $resolved;
}

1;
