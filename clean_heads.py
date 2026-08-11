#!/usr/bin/env python3
"""
Epson L800 — Limpeza de cabeça via USB + D4.
Usa o mesmo padrão que o reset: EpsonD4 + ctrl() / data channel.

Uso: sudo .../python clean_heads.py <opção>
  1=Normal  2=Preto  3=Cores  4=PowerClean  5=TesteBicos
"""
import sys, logging, datetime
logging.basicConfig(level=logging.INFO)

import usb.backend.libusb1 as _backend
b = _backend.get_backend()
import usb.core, usb.util
from reinkpy.usb import UsbIO
from reinkpy.d4 import D4Link
from reinkpy.epson import EpsonD4

def main():
    if len(sys.argv) < 2:
        print("Uso: sudo .../python clean_heads.py [1-5]"); sys.exit(1)
    choice = sys.argv[1]

    groups = {
        "1": (0x00, "Limpeza Normal (todos bicos)"),
        "2": (0x01, "Limpeza Preto"),
        "3": (0x02, "Limpeza Cores"),
        "4": (0x10, "Power Cleaning"),
        "5": (None, "Teste de Bicos"),
    }
    if choice not in groups:
        print("Inválido. Use 1-5"); sys.exit(1)

    group, label = groups[choice]

    # Conectar USB
    dev = usb.core.find(idVendor=0x04b8, backend=b)
    if not dev:
        print("❌ L800 não encontrada!"); sys.exit(1)
    print(f"✅ L800 (Bus={dev.bus} Addr={dev.address})")

    if dev.is_kernel_driver_active(0):
        dev.detach_kernel_driver(0)

    cfg = dev.get_active_configuration()
    intf = cfg[(0, 0)]
    ep_out = [ep for ep in intf if usb.util.endpoint_direction(ep.bEndpointAddress) == usb.util.ENDPOINT_OUT][0]
    ep_in  = [ep for ep in intf if usb.util.endpoint_direction(ep.bEndpointAddress) == usb.util.ENDPOINT_IN][0]

    io = UsbIO(ep_in, ep_out, intf, cfg, dev)
    link = D4Link(io)
    epson = EpsonD4(link)
    epson.configure("L800")

    # HTML-like remote command builder (same format as epson_escp2's remote_cmd)
    def rem(cmd, args=b''):
        cmd_bytes = cmd.encode()  # 2 bytes
        length = len(args)
        return cmd_bytes + struct.pack('<H', length) + args

    import struct

    if choice == "5":
        # Nozzle Check via ESC/P2 Remote Mode
        print(f"\n⚙️  Teste de Bicos...")
        # Build proper sequence with ESC/P2
        INIT = b'\x1b@'
        REMOTE = b'\x1b(R\x08\x00\x00\x00REMOTE1'
        ENTER_REMOTE = INIT + INIT + REMOTE
        EXIT_REMOTE = b'\x1b\x00\x00\x00'

        # Build the full sequence as bytes
        # First send exit packet mode to get out of any previous D4 state
        exit_packet = b'\x00\x00\x00\x1b\x01@EJL 1284.4\n@EJL     \n'
        payload = exit_packet + ENTER_REMOTE + rem("NC", b'\x00\x00') + EXIT_REMOTE + INIT + rem("JE", b'\x00') + EXIT_REMOTE

        print(f"   Payload: {len(payload)} bytes")
        # Try sending via EPSON-DATA channel through D4
        with link:
            print("   D4 link OK")
            # Send through data channel
            dc = link.get_channel('EPSON-DATA', (0x40, 0x40))
            if dc:
                with dc:
                    resp = dc(payload)
                    print(f"   Resposta DATA: {resp[:80] if resp else 'empty'}")
                print("✅ Teste de Bicos enviado via DATA channel!")
            else:
                print("⚠️  Sem DATA channel, tentando via CTRL...")
                resp = epson.ctrl(payload)
                print(f"   Resposta CTRL: {resp}")
        return

    # Head Cleaning via CTRL channel commands
    print(f"\n⚙️  {label}...")

    # Para CH (Clean Heads) o formato via CTRL não é Remote Mode padrão.
    # O comando CH no Epson é um comando proprietário.
    # Vamos tentar enviar o comando direto como bytes no canal CTRL.
    ch_cmd = rem("CH", bytes([0x00, group]))
    je_cmd = rem("JE", b'\x00')

    try:
        resp = epson.ctrl(ch_cmd)
        print(f"   CH resposta: {resp}")
        epson.ctrl(je_cmd)
        print(f"\n✅ {label} executado via CTRL!")
        print("   🕐 Aguarde ~2-3 min.")
    except Exception as ex:
        print(f"   ❌ Via CTRL: {ex}")
        print("   Tentando via data channel...")
        try:
            INIT = b'\x1b@'
            REMOTE = b'\x1b(R\x08\x00\x00\x00REMOTE1'
            ENTER_REMOTE = INIT + INIT + REMOTE
            EXIT_REMOTE = b'\x1b\x00\x00\x00'
            payload = ENTER_REMOTE + ch_cmd + EXIT_REMOTE + ENTER_REMOTE + je_cmd + EXIT_REMOTE
            with link:
                dc = link.get_channel('EPSON-DATA', (0x40, 0x40))
                if dc:
                    with dc:
                        dc(payload)
                    print(f"✅ {label} enviado via DATA!")
                    print("   🕐 Aguarde ~2-3 min.")
        except Exception as ex2:
            print(f"   ❌ Via DATA: {ex2}")

if __name__ == '__main__':
    main()
