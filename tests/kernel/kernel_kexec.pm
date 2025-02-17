# Copyright (C) 2017-2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Package: kexec-tools systemd
# Summary:  [qa_automation] kexec testsuite
# Maintainer: QE Kernel <kernel-qa@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    # clear console to prevent linux-login to match before reboot
    clear_console;
    # Copy kernel image and rename it
    my $kernel_orig = script_output('find /boot -maxdepth 1 -name "*$(uname -r)" | grep -iP "image|vmlinu"', 120);
    (my $kernel_new = $kernel_orig) =~ s/-default$/-kexec/;
    assert_script_run("cp $kernel_orig $kernel_new");

    # Copy initrd image and rename it
    my $initrd_orig = script_output('find /boot -maxdepth 1 -name "initrd-$(uname -r)"', 120);
    (my $initrd_new = $initrd_orig) =~ s/-default$/-kexec/;
    assert_script_run("cp $initrd_orig $initrd_new");

    # kernel cmdline parameter
    $_ = script_output("cat /proc/cmdline", 120);
    s/-default /-kexec /;
    s/ splash=silent//;
    my $cmdline = "$_ debug";

    # kexec -l
    assert_script_run("kexec -l $kernel_new --initrd=$initrd_new --command-line='$cmdline'");
    # kexec -e
    # don't use built-in systemctl api, see poo#31180
    script_run("systemctl kexec", 0);
    reset_consoles;
    $self->wait_boot_past_bootloader;
    $self->select_serial_terminal;
    # Check kernel cmdline parameter
    my $result = script_output("cat /proc/cmdline", 120);
    print "Checking kernel boot parameter...\nCurrent:  $result\nExpected: $cmdline\n";
    if ($cmdline ne $result) {
        die "kexec failed";
    }
}

1;
