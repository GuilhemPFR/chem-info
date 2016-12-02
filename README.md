## chem-info

### Installation and dependencies

There is no requirement to install the software other that cloning the repository from GitHub.

Once cloned `cpanm` can be used to install the dependencies into the local directory, or globally if so desired.

```bash
## chem-info.pl expects the cpan directory
## the dot is important
cpanm --installdeps -l cpan .
```

### Usage

Running the software from the root directory of the repository is recommended.

```bash
## obtain the help - explanation of command line switches
./bin/chem-info.pl --help
Usage:
   --compounds    file of compounds - one per line
   --synonyms     synonyms file
   --output       output tab separated file
   --rtype        type of resolver to use
   --fisheryates  fisher yates

   --help         Print this help text


## provide the location of files for compounds and output
./bin/chem-info.pl -c ./data/compounds.txt -o output.tsv
```
