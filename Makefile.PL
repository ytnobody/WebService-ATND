use inc::Module::Install;
name 'WebService-ATND';
all_from 'lib/WebService/ATND.pm';

requires 'LWP::UserAgent';
requires 'XML::Simple';
requires 'SUPER';
requires 'URI';
requires 'Data::Recursive::Encode';
requires 'Hash::AsObject';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
