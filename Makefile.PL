use inc::Module::Install;
name 'WebService-ATND';
all_from 'lib/WebService/ATND.pm';

requires 'Mouse';
requires 'MouseX::Foreign';
requires 'Furl';
requires 'URI';
requires 'Time::Piece';
requires 'DateTime::Format::ISO8601';
requires 'XML::Simple';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::Flatten';
test_requires 'Test::Name::FromLine';
test_requires 'Test::More';
test_requires 'Test::TCP';
test_requires 'Plack::Loader';
test_requires 'File::Slurp';

auto_set_repository;
auto_include;
WriteAll;
