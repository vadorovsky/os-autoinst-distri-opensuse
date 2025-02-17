# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Package: awesome
# Summary: Test for xterm started in awesome window manager
# Maintainer: Dominik Heidler <dheidler@suse.de>
# Tags: poo#9522

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    send_key "super-r";
    enter_cmd "xterm";
    assert_screen 'awesome_xterm_icon', 10;
    enter_cmd "clear";
    $self->enter_test_text('xterm');
    assert_screen 'test-xterm-1', 5;
    send_key "super-shift-c";
}

sub test_flags {
    return {fatal => 1};
}

1;
