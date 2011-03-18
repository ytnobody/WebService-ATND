use inc::Module::Install;
name 'WebService-ATND';
all_from 'lib/WebService/ATND.pm';

requires 'Class::Accessor::Fast';
requires 'LWP::UserAgent';
requires 'XML::Simple';
requires 'SUPER';
requires 'URI';
requires 'Data::Recursive::Encode';
requires 'Hash::AsObject';
requires 'DateTime::Format::ISO8601';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
