pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Singleton {
    id: root

    // Docker/libvirt bridges and veth pairs can be reported as wired devices
    // and are always "connected"; they are not an uplink.
    readonly property var _virtual: /^(veth|br-|docker|virbr|tailscale|lo$)/

    readonly property var wiredDevice: {
        const devices = Networking.devices.values || [];
        for (let i = 0; i < devices.length; i++) {
            const d = devices[i];
            if (d && d.type === DeviceType.Wired && !root._virtual.test(d.name) && (d.connected || d.state === ConnectionState.Connected))
                return d;
        }
        return null;
    }

    readonly property bool connected: wiredDevice !== null
    readonly property string iface: wiredDevice ? wiredDevice.name : ""

    readonly property string driver: {
        const m = /^DRIVER=(.*)$/m.exec(ueventFile.text());
        return m ? m[1] : "";
    }
    readonly property bool usb: /^DEVTYPE=usb_interface$/m.test(ueventFile.text())

    // The kernel exposes no "is a phone" flag, so only the drivers that
    // phones use exclusively count. cdc_ether/cdc_ncm are shared with plain
    // USB ethernet dongles and stay in the generic "usb" kind.
    readonly property bool tethered: usb && /^(rndis_host|ipheth)$/.test(driver)

    readonly property string kind: !connected ? "" : tethered ? "phone" : usb ? "usb" : "wired"

    // The interface's sysfs `device` is the USB interface; its parent is the
    // USB device that carries the product string.
    readonly property string product: productFile.text().trim()

    readonly property string label: {
        const what = kind === "phone" ? "USB tethering" : kind === "usb" ? "USB ethernet" : "Wired";
        return product ? `${what}: ${product} (${iface})` : `${what}: ${iface}`;
    }

    FileView {
        id: ueventFile
        path: root.iface ? `/sys/class/net/${root.iface}/device/uevent` : ""
    }

    FileView {
        id: productFile
        path: root.usb ? `/sys/class/net/${root.iface}/device/../product` : ""
    }
}
