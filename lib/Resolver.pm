package Resolver;

use Mojo::Base -base;
use Mojo::URL;
use Mojo::UserAgent;

has url_generator => sub {
  return sub {
    my ($cmp, $property) = @_;
    my $srv = q{https://cactus.nci.nih.gov/chemical/structure};
    return Mojo::URL->new(join '/', $srv, $cmp->name, $property);
  };
};
has user_agent => sub {
  return Mojo::UserAgent->new();
};

sub resolve {
  my ($self, $compound) = @_;
  my $url = $self->url_generator->($compound, 'cas');
  my $cas_list = $self->user_agent->get($url => {Accept => '*/*'})->res->body;
  $compound->cas_list([ split /\n/, $cas_list ]);

  $url = $self->url_generator->($compound, 'iupac_name');
  my $iupac = $self->user_agent->get($url => {Accept => '*/*'})->res->body;
  $compound->iupac_name( $iupac );

  $url = $self->url_generator->($compound, 'names');
  my $synonyms = $self->user_agent->get($url => {Accept => '*/*'})->res->body;
  $compound->synonyms([ split /\n/, $synonyms ]);
  return $self;
}

1;
