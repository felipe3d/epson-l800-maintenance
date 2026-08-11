#!/usr/bin/env python3
"""Reset Epson L800 waste ink counter via USB using reinkpy."""
import sys
import reinkpy

print("=== Searching for Epson printer via USB ===")
# Find USB devices
devices = []
for p in reinkpy.Device.find():
    ip = getattr(p, 'ip', None)
    print(f"  Found: {p.name if hasattr(p, 'name') else p} @ {ip}")
    devices.append(p)

if not devices:
    print("No devices found!")
    sys.exit(1)

# Pick first or L800
target = None
for p in devices:
    try:
        epson = p.epson
        spec = epson.spec
        model = getattr(spec, 'model', '')
        if 'L800' in str(model) or 'l800' in str(model).lower():
            target = p
            print(f"  -> Selected: L800 @ {p.ip if hasattr(p, 'ip') else 'USB'}")
            break
    except Exception as ex:
        print(f"  Error checking device: {ex}")

if not target:
    target = devices[0]
    print(f"  -> Using first device: {target}")

e = target.epson

print(f"\n=== Model from specs: {e.spec.model} ===")

# Check if model is known
if not e.spec.model:
    print("Model unknown, configuring as L800...")
    e.configure("L800")

print(f"\n=== Current EEPROM (waste counters) ===")
try:
    # Read waste counter addresses for L800: 28,29,30,31 (main) and 32,33,46,47,48,49 (platen)
    waste_addrs = [28, 29, 30, 31, 32, 33, 46, 47, 48, 49]
    values = e.read_eeprom(*waste_addrs)
    for addr, val in zip(waste_addrs, values):
        print(f"  EEPROM[{addr}] = {val}")
except Exception as ex:
    print(f"  Error reading EEPROM: {ex}")
    print("  (Printer may be locked or not responding via USB)")

print(f"\n=== Resetting waste counters? ===")
# Uncomment to actually reset:
# e.reset_waste()
# print("Waste counters reset!")
