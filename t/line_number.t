use Test::More;

eval 'use DBD::SQLite 1.0 ()';
plan skip_all => "DBD::SQLite required to run this test" if $@;

eval 'use Template 2.0 ()';
plan skip_all => "Template Toolkit required to run this test" if $@;

plan tests => 2;

use Querylet;
is(__LINE__,'12', "Filter expansion keeps line numbers intact"); 

database: dbi:SQLite:dbname=./t/wafers.db

query:
  SELECT wafer_id
  FROM   grown_wafers

output format: template
set option template_file: ./t/test_template.tt

no output

no Querylet;
is(__LINE__,'26', "Filter expansion keeps line numbers intact"); 
