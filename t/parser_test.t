#!perl -w
use Test::More tests => 6;
use Data::Dumper;

use Querylet::Parser;

my @sections = Querylet::Parser->parse(<<'Querylet');

$some->perl;
ignored section:
    qweqwe
$some->perl;

database: dbi:SQLite:dbname=temp.sqlite

database:
    dbi:SQLite:dbname=temp.sqlite

munge query:
    foo => 'Foo',
    bar => 'Bar',

query:
    select [% foo %] from [% bar %]

query:
    another query

Querylet

is 0+@sections, 6, "Six sections were found";

is $sections[0]->{type}, 'perl', "The first section is Perl code";
is $sections[1]->{type}, 'querylet', "The second section is Querylet code";
is $sections[2]->{type}, 'perl', "The third section is Perl code  (a malformed database: section)";
is $sections[3]->{type}, 'querylet', "The fourth section is Querylet code";
is $sections[4]->{type}, 'querylet', "The fifth section is Querylet code";

diag Dumper \@sections;