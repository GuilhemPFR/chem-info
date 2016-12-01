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

sub _call {
  my ($self, $url) = @_;
  my $resp = $self->user_agent->get($url => {Accept => '*/*'})->res;
  return ($resp->code == 200, $resp->body);
}
sub resolve {
  my ($self, $compound) = @_;
  my $url = $self->url_generator->($compound, 'cas');
  my ($ok, $cas_list) = $self->_call($url);
  if ($ok) {
    $compound->cas_list([ split /\n/, $cas_list ]);

    $url = $self->url_generator->($compound, 'iupac_name');
    my ($ok1, $iupac) = $self->_call($url);
    $compound->iupac_name( $iupac );

    $url = $self->url_generator->($compound, 'names');
    my ($ok2, $synonyms) = $self->_call($url);
    $compound->synonyms([ split /\n/, $synonyms ]);
    $self->{'found'}++;
  } else {
    $self->{'missing'}++;
  }
  return $self;
}

sub stats {
  my $self = shift;
  return { map { $_ => $self->{$_} } qw{found missing} };
}

1;
