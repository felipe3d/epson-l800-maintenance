#!/usr/bin/env python3
"""RESET Epson L800 waste ink counter via USB."""
import sys, logging
logging.basicConfig(level=logging.INFO)

import usb.backend.libusb1 as _backend
b = _backend.get_backend()
import usb.core, usb.util
from reinkpy.usb import UsbIO
from reinkpy.d4 import D4Link
from reinkpy.epson import EpsonD4

dev = usb.core.find(idVendor=0x04b8, backend=b)
assert dev, "L800 não encontrada!"
if dev.is_kernel_driver_active(0):
    dev.detach_kernel_driver(0)
cfg = dev.get_active_configuration()
intf = cfg[(0, 0)]
ep_out = ep_in = None
for ep in intf:
    if usb.util.endpoint_direction(ep.bEndpointAddress) == usb.util.ENDPOINT_OUT:
        ep_out = ep
    if usb.util.endpoint_direction(ep.bEndpointAddress) == usb.util.ENDPOINT_IN:
        ep_in = ep

io = UsbIO(ep_in, ep_out, intf, cfg, dev)
link = D4Link(io)
epson = EpsonD4(link)
epson.configure("L800")

print(f"✅ L800 conectada - {epson.info}")
print(f"\n📊 Lendo valores ATUAIS dos contadores de waste...")
addrs = [28, 29, 30, 31, 32, 33, 46, 47, 48, 49]
antes = epson.read_eeprom(*addrs)
for addr, val in antes:
    print(f"   EEPROM[{addr:3d}] = {val}")

print(f"\n🔄 Resetando contadores de waste para ZERO...")
# Escrever 0 em todos os endereços de waste
pares = [(addr, 0) for addr, _ in antes]
sucesso = epson.write_eeprom(*pares, atomic=True)

if sucesso:
    print(f"\n✅ RESET CONCLUÍDO COM SUCESSO!")
else:
    print(f"\n⚠️  Reset pode não ter sido aplicado em todos os endereços.")

print(f"\n📊 Verificando valores PÓS-reset...")
depois = epson.read_eeprom(*addrs)
tudo_zero = True
for (addr, antes_val), (_, depois_val) in zip(antes, depois):
    status = "✅" if depois_val == 0 else "❌"
    if depois_val != 0:
        tudo_zero = False
    print(f"   EEPROM[{addr:3d}] = {antes_val} → {depois_val}  {status}")

if tudo_zero:
    print(f"\n🎉 TODOS OS CONTADORES ZERADOS!")
    print(f"   Desligue e ligue a impressora para aplicar.")
else:
    print(f"\n⚠️  Alguns endereços não zeraram. Pode precisar de uma segunda tentativa.")
