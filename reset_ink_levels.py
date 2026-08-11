#!/usr/bin/env python3
"""
Epson L800 — Reset de nível de tinta via USB D4.
Tenta os comandos IC (Ink Charge) e o comando raw de ink charge.
"""
import sys, logging
logging.basicConfig(level=logging.INFO)

import usb.backend.libusb1 as _backend
b = _backend.get_backend()
import usb.core, usb.util
from reinkpy.usb import UsbIO
from reinkpy.d4 import D4Link
from reinkpy.epson import EpsonD4

def rem(cmd, args=b''):
    import struct
    return cmd.encode() + struct.pack('<H', len(args)) + args

def main():
    dev = usb.core.find(idVendor=0x04b8, backend=b)
    if not dev:
        print("❌ L800 não encontrada!"); sys.exit(1)
    print(f"✅ L800 (Bus={dev.bus} Addr={dev.address})")
    if dev.is_kernel_driver_active(0): dev.detach_kernel_driver(0)
    cfg = dev.get_active_configuration()
    intf = cfg[(0, 0)]
    ep_out = [ep for ep in intf if usb.util.endpoint_direction(ep.bEndpointAddress) == usb.util.ENDPOINT_OUT][0]
    ep_in  = [ep for ep in intf if usb.util.endpoint_direction(ep.bEndpointAddress) == usb.util.ENDPOINT_IN][0]
    io = UsbIO(ep_in, ep_out, intf, cfg, dev)
    link = D4Link(io)
    epson = EpsonD4(link)
    epson.configure("L800")

    print("\n⚙️  Tentando Reset de Nível de Tinta...\n")

    # Abordagem 1: IC (Ink Charge) via CTRL
    print("1) Comando IC (Ink Charge) via CTRL...")
    try:
        resp = epson.ctrl(rem("IC", b'\x01'))
        print(f"   Resposta: {resp}")
    except Exception as ex:
        print(f"   ❌ Erro: {ex}")

    # Abordagem 2: Comando raw de ink charge (do epson_escp2)
    print("\n2) Comando raw Ink Charge via DATA channel...")
    try:
        ink_charge_raw = bytes.fromhex("1B 7C 00 06 00 19 07 84 7B 42 0A")
        with link:
            dc = link.get_channel('EPSON-DATA', (0x40, 0x40))
            if dc:
                with dc:
                    resp = dc(ink_charge_raw)
                    print(f"   Resposta: {resp}")
            else:
                # Tentar via CTRL como bytes crus
                resp = epson.ctrl(ink_charge_raw)
                print(f"   Resposta CTRL raw: {resp}")
    except Exception as ex:
        print(f"   ❌ Erro: {ex}")

    # Abordagem 3: IJ (Ink Jet?) ou II (Ink Information)
    print("\n3) Lendo informação de tinta atual...")
    try:
        info = epson.ctrl(rem("II", b'\x01'))
        print(f"   Ink info: {info}")
    except Exception as ex:
        print(f"   ❌ Erro: {ex}")

    # Abordagem 4: Tentar comandos de fábrica / reset
    print("\n4) Tentando comando 'rs' (reset summary?)...")
    try:
        resp = epson.ctrl(rem("rs", b'\x01'))
        print(f"   rs resposta: {resp}")
    except Exception as ex:
        print(f"   ❌ Erro: {ex}")

    print("\n✅ Comandos enviados. Verifique o painel da L800.")
    print("   Se o alerta de tinta baixa sumir, deu certo!")

if __name__ == '__main__':
    main()
