package Resolver::Hash;

use Mojo::Base qw{Resolver};

has lookup => sub { return {}; };

sub resolve {
  my ($self, $compound) = @_;
  my $l = $self->lookup;
  my $q = lc $compound->name;
  if (exists $l->{$q}) {
    $compound->cas_list([ $l->{$q} ]);
    $self->{'found'}++;
  } else {
    $self->{'missing'}++;
    warn $q;
  }
}

1;
