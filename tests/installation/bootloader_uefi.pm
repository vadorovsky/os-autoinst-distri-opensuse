# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot on UEFI systems with configuration of boot parameters
# - If system is DUALBOOT, call tianocore_select_bootloader (tianocore boot
# menu) and choose dvd boot
# - If aarch64 tianocore, raise delay to 60s
# - If "UEFI_HTTP_BOOT" or "UEFI_HTTPS_BOOT" are defined, call
# tianocore_http_boot (tianocore boot menu, choose network boot via http or
# https
# - If "ZDUP" is defined, boot using harddisk. In case of aarch64, call
# handle_uefi_boot_disk_workaround (select hard disk from tianocore menu)
# - If "UPGRADE" is defined, go to upgrade option on bootloader
# - Or if "PROMO", "LIVETEST" or "LIVECD" are defined, boot desktop
# option.
# - Otherwise, if it is not "is_jeos" and not "VMX", boot installation option.
# - Call uefi_bootmenu_params (1024x768 graphics mode, "install=" if NETBOOT or
# "textmode=1" if VIDEOMODE="text")
# - Call bootmenu_default_params (Edit grub parameters, add "Y2DEBUG=1",
# graphics mode and resolution, serial output, console/log redirection)
# - Call specific_bootmenu_params (Autoyast options, network options, debug
# options, installer specific options, fips enablement, kexec parameters, addon
# products, DUD loading, external ISO) unless it is is_microos or is_jeos
# - Save bootloader parameters in a screenshot
# - if "USE_SUPPORT_SERVER" is defined, wait for mutex to unlock before sending
# "F10"
# Maintainer: QE LSG <qa-team@suse.de>

package bootloader_uefi;

use base "installbasetest";
use strict;
use warnings;

use Time::HiRes 'sleep';

use testapi;
use lockapi 'mutex_wait';
use bootloader_setup;
use registration;
use utils;
use version_utils qw(is_jeos is_microos is_sle);

# hint: press shift-f10 trice for highest debug level
sub run {
    my ($self) = @_;

    # Enable boot menu for x86_64 uefi workaround, see bsc#1180080 for details
    # Case setting also need BOOT_MENU=1 to support it
    if (is_sle && get_required_var('FLAVOR') =~ /Migration/ && check_var('ARCH', 'x86_64')) {
        # Skip workaround on specific scenaio which call this module after migration
        if (!check_screen('bootloader-grub2', 0, no_wait => 1)) {
            record_soft_failure 'bsc#1180080';
            tianocore_select_bootloader;
            send_key_until_needlematch("ovmf-boot-HDD", 'down', 5, 1);
            send_key "ret";
            return;
        }
    }

    if (get_var("IPXE")) {
        sleep 60;
        return;
    }

    if (get_var('DUALBOOT')) {
        tianocore_select_bootloader;
        send_key_until_needlematch('tianocore-bootmanager-dvd', 'down', 5, 5);
        send_key "ret";
    }

    # Skip to load bootloader in test of online migration on aarch64
    # Handle aarch64 image boot by wait_boot called in setup_online_migration
    if (get_var('ONLINE_MIGRATION') && check_var('ARCH', 'aarch64')) {
        return;
    }

    # aarch64 firmware 'tianocore' can take longer to load
    my $bootloader_timeout = check_var('ARCH', 'aarch64') ? 90 : 15;
    if (get_var('UEFI_HTTP_BOOT') || get_var('UEFI_HTTPS_BOOT')) {
        tianocore_http_boot;
    }
    assert_screen([qw(bootloader-shim-import-prompt bootloader-grub2)], $bootloader_timeout);
    if (match_has_tag("bootloader-shim-import-prompt")) {
        send_key "down";
        send_key "ret";
        assert_screen "bootloader-grub2", $bootloader_timeout;
    }
    if (get_var('DISABLE_SECUREBOOT') && (get_var('BACKEND') eq 'qemu')) {
        $self->tianocore_disable_secureboot;
    }
    if (get_var("QEMUVGA") && get_var("QEMUVGA") ne "cirrus") {
        sleep 5;
    }
    if ((get_var("ZDUP") && !is_jeos) || (get_var('ONLINE_MIGRATION') && check_var('BOOTFROM', 'd'))) {
        # 'eject_cd' is broken ATM (at least on aarch64), so select HDD from menu - poo#47303
        # Check we are booting the ISO
        assert_screen 'inst-bootmenu';
        # Select boot from HDD
        send_key_until_needlematch 'inst-bootmenu-boot-harddisk', 'up';
        send_key 'ret';
        # use firmware boot manager of aarch64 and uefi to boot HDD
        $self->handle_uefi_boot_disk_workaround if (check_var('ARCH', 'aarch64') || get_var('UEFI'));
        assert_screen("grub2");
        return;
    }

    if (get_var("UPGRADE")) {
        # random magic numbers
        send_key_until_needlematch('inst-onupgrade', 'down', 10, 3);
    }
    else {
        if (get_var("PROMO") || get_var('LIVETEST') || get_var('LIVECD')) {
            send_key_until_needlematch("boot-live-" . get_var("DESKTOP"), 'down', 10, 3);
        }
        elsif (!is_jeos && !is_microos('VMX')) {
            send_key_until_needlematch('inst-oninstallation', 'down', 10, 3);
        }
    }

    uefi_bootmenu_params;
    bootmenu_default_params;
    bootmenu_remote_target;
    specific_bootmenu_params unless is_microos || is_jeos;

    # JeOS is never deployed with Linuxrc involved,
    # so 'regurl' does not apply there.
    registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED) unless is_jeos;

    # boot
    mutex_wait 'support_server_ready' if get_var('USE_SUPPORT_SERVER');
    send_key "f10";
}

1;
