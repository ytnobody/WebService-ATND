use inc::Module::Install;
name 'WebService-ATND';
all_from 'lib/WebService/ATND.pm';

requires 'parent';
requires 'Class::Accessor::Fast';
requires 'LWP::UserAgent';
requires 'URI';
requires 'Data::Recursive::Encode';
requires 'Hash::AsObject';
requires 'DateTime::Format::ISO8601';
requires 'XML::Simple';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
test_requires 'Test::TCP';
test_requires 'Plack::Loader';
test_requires 'File::Slurp';

auto_set_repository;
auto_include;
WriteAll;
