package Resolver;

use Mojo::Base -base;
use Mojo::URL;
use Mojo::UserAgent;

has url_generator => sub {
  return sub {
    my $srv = q{https://cactus.nci.nih.gov/chemical/structure};
    return Mojo::URL->new(join '/', $srv, $_[0]->name, 'cas');
  };
};
has user_agent => sub {
  return Mojo::UserAgent->new();
};

sub resolve {
  my ($self, $compound) = @_;
  my $url = $self->url_generator->($compound);
  my $cas_list = $self->user_agent->get($url => {Accept => '*/*'})->res->body;
  $compound->cas_list([ split /\n/, $cas_list ]);
  return $self;
}

1;
