use strict;
use warnings;

use Test::More;

eval "use Test::Pod 1.22";
plan skip_all => "Test::Pod 1.22 required for testing POD" if $@;

my @dirs;
push @dirs, 'lib'         if -d 'lib';
push @dirs, 'modules/lib' if -d 'modules/lib';

plan skip_all => "No POD source directories found (expected lib/ or modules/lib/)" unless @dirs;

my @files = all_pod_files(@dirs);
all_pod_files_ok(@files);