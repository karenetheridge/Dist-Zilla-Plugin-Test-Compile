package Foo;
use strict;
use warnings;

warn "this is a warning from Foo";

use This::Module::Does::Not::Exist;

1;
