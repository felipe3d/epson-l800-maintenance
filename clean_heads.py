#!/usr/bin/env python3
"""
Epson L800 — Limpeza de cabeça via USB raw (modo escputil).
Envia bytes ESC/P2 Remote Mode diretamente ao endpoint USB,
sem usar D4. Igual ao que o escputil (GIMP-Print) faz.

Uso: sudo .../python clean_heads.py [1|5]
  1 = Limpeza Normal
  5 = Teste de Bicos
"""
import sys, logging
logging.basicConfig(level=logging.INFO)

import usb.backend.libusb1 as _backend
b = _backend.get_backend()
import usb.core, usb.util

def build_remote_cmd(cmd_ascii, *args):
    """
    Monta sequência Remote Mode no formato do escputil.c:
    
    ESC @ ESC @       → 2x initialize printer
    ESC (R 08 00 00 00 REMOTE1   → enter remote mode
    CC nn ll pp...    → comando (2B) + byte count (2B LE) + parametros
    ESC 00 00 00      → exit remote mode
    """
    cmd = cmd_ascii.encode()
    nargs = len(args)
    remote_hdr = b'\x1b@\x1b@\x1b(R\x08\x00\x00\x00REMOTE1'
    remote_tlr = b'\x1b\x00\x00\x00'
    return remote_hdr + cmd + nargs.to_bytes(2, 'little') + bytes(args) + remote_tlr

def build_full_sequence(cmd, *args):
    """
    Sequência completa que o escputil manda:
    
    00 00 00 1B 01 @EJL 1284.4 \n @EJL     \n   → exit packet mode
    1B @                                              → init printer
    <remote_cmd>
    0C                                                → form feed
    1B 00 1B 00                                       → resets
    """
    EXIT_PACKET = b'\x00\x00\x00\x1b\x01@EJL 1284.4\n@EJL     \n\x1b@'
    PRINT_TAIL  = b'\x0c\x1b\x00\x1b\x00'
    return EXIT_PACKET + build_remote_cmd(cmd, *args) + PRINT_TAIL

def main():
    if len(sys.argv) < 2:
        print("Uso: sudo .../python clean_heads.py [1|5]"); sys.exit(1)
    choice = sys.argv[1]
    
    actions = {
        "1": (build_full_sequence("CH", 0, 0), "Limpeza Normal (todos bicos)"),
        "5": (build_full_sequence("NC", 0, 0), "Teste de Bicos"),
    }
    if choice not in actions:
        print("Use 1 ou 5."); sys.exit(1)
    
    payload, label = actions[choice]
    
    # Conectar USB direto (sem reinkpy, sem D4)
    dev = usb.core.find(idVendor=0x04b8, backend=b)
    if not dev:
        print("❌ L800 não encontrada!"); sys.exit(1)
    
    print(f"✅ L800 (Bus={dev.bus} Addr={dev.address})")
    try:
        if dev.is_kernel_driver_active(0):
            dev.detach_kernel_driver(0)
    except:
        pass
    
    cfg = dev.get_active_configuration()
    intf = cfg[(0, 0)]
    
    ep_out = None
    for ep in intf:
        if usb.util.endpoint_direction(ep.bEndpointAddress) == usb.util.ENDPOINT_OUT:
            ep_out = ep
            break
    
    if not ep_out:
        print("❌ Endpoint OUT não encontrado!"); sys.exit(1)
    
    print(f"\n⚙️  {label}")
    print(f"   {len(payload)} bytes → endpoint OUT {ep_out.bEndpointAddress:#04x}")
    print(f"   Hex: {payload[:40].hex()}...")
    
    # Escrever direto no endpoint USB (sem D4)
    try:
        written = ep_out.write(payload, timeout=10000)
        print(f"   {written} bytes escritos ✅")
        print(f"\n✅ Comando ESC/P2 enviado com sucesso!")
        if choice == "5":
            print("   Coloque papel — a L800 vai imprimir o padrão de teste.")
        else:
            print("   🕐 Aguarde 2-3 min — a L800 vai fazer o ciclo de limpeza.")
    except usb.core.USBError as e:
        print(f"\n❌ Erro USB: {e}")
        # Tentativa alternativa: enviar via bulk
        print("   Tentando via bulk write...")
        try:
            dev.write(ep_out.bEndpointAddress, payload, timeout=10000)
            print("   ✅ OK via bulk write!")
        except Exception as e2:
            print(f"   ❌ Também falhou: {e2}")

if __name__ == '__main__':
    main()
