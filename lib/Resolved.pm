package Resolved;

use Mojo::Base -base;

has 'compound'; ## input compound, canonicalised name
has 'distance' => 0;
has 'found' => 0;
has 'match';
has 'query'; ## from input file

1;
