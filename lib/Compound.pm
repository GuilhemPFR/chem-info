package Compound;

use Mojo::Base -base;

has 'cas' => sub { $_[0]->cas_list->[0] };
has 'cas_list' => sub { return [] };
has 'iupac_name';
has 'name';
has 'synonyms';

1;
