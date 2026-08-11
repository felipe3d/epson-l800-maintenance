#!/usr/bin/env python3
"""Reset Epson L800 waste ink counter via USB usando reinkpy."""
import sys, os, logging
logging.basicConfig(level=logging.INFO)

# Garantir que libusb seja encontrado
import usb.backend.libusb1 as _backend
b = _backend.get_backend()
assert b is not None, "libusb backend not found!"

import usb.core
import usb.util
from reinkpy.usb import UsbIO
from reinkpy.d4 import D4Link
from reinkpy.epson import EpsonD4

# 1. Encontrar a L800 via USB
dev = usb.core.find(idVendor=0x04b8, backend=b)
if not dev:
    print("ERRO: Impressora Epson L800 não encontrada via USB!")
    print("Verifique o cabo USB e se a impressora está ligada.")
    sys.exit(1)

print(f"✅ Epson L800 encontrada!")
print(f"   VID:PID = {hex(dev.idVendor)}:{hex(dev.idProduct)}")
print(f"   Bus={dev.bus}, Address={dev.address}")

# 2. Liberar driver do kernel
if dev.is_kernel_driver_active(0):
    print("   Liberando kernel driver...")
    dev.detach_kernel_driver(0)

# 3. Configurar interfaces USB
cfg = dev.get_active_configuration()
intf = cfg[(0, 0)]

ep_out = None
ep_in = None
for ep in intf:
    if usb.util.endpoint_direction(ep.bEndpointAddress) == usb.util.ENDPOINT_OUT:
        ep_out = ep
    if usb.util.endpoint_direction(ep.bEndpointAddress) == usb.util.ENDPOINT_IN:
        ep_in = ep

assert ep_out and ep_in, "Endpoints USB não encontrados!"
print(f"   EP OUT: {ep_out.bEndpointAddress:#04x}")
print(f"   EP IN : {ep_in.bEndpointAddress:#04x}")

# 4. Criar link USB D4 + EpsonD4
io = UsbIO(ep_in, ep_out, intf, cfg, dev)
link = D4Link(io)
epson = EpsonD4(link)

# 5. Configurar modelo L800
print(f"\n🔧 Configurando como L800...")
epson.configure("L800")
print(f"   Modelo: {epson.spec.model}")
print(f"   rkey: {epson.spec.rkey} (0x{epson.spec.rkey:04x})")
print(f"   wkey: {epson.spec.wkey}")
print(f"   Endereços waste: {epson.spec.mem}")

# 6. Ler o ID da impressora
print(f"\n📋 Lendo ID da impressora...")
try:
    info = epson.info
    print(f"   Info: {info}")
except Exception as ex:
    print(f"   Aviso: {ex}")

# 7. Ler os contadores de waste
print(f"\n📊 Lendo contadores de waste...")
waste_addrs = [28, 29, 30, 31, 32, 33, 46, 47, 48, 49]
try:
    results = epson.read_eeprom(*waste_addrs)
    for addr, val in results:
        label = "MAIN" if addr <= 31 else "PLATEN"
        status = "⚠️ ALTO" if val and val > 0 else "✅ OK" if val == 0 else "?"
        print(f"   EEPROM[{addr:3d}] ({label:6s}) = {val!r:6s}  {status}")
except Exception as ex:
    print(f"   Erro ao ler EEPROM: {ex}")

# 8. Reset!
print(f"\n{'='*50}")
print(f"🔄 Para resetar os contadores de waste, execute:")
print(f"   epson.reset_waste()")
print(f"{'='*50}")
print(f"\n⚠️  LEMBRETE: Verifique fisicamente o waste ink pad da L800!")
print(f"   Se estiver saturado, troque-o antes de resetar o contador.")
print(f"   Senão a tinta pode vazar e danificar a impressora.")
