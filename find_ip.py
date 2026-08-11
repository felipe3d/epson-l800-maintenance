#!/usr/bin/env python3
"""Discover Epson printer IP via zeroconf and print it."""
import asyncio
import socket
from zeroconf import Zeroconf, ServiceBrowser, ServiceInfo, ServiceStateChange

found = {}

def on_change(zeroconf, service_type, name, state_change):
    if state_change == ServiceStateChange.Added:
        info = zeroconf.get_service_info(service_type, name)
        if info and 'EPSON' in name.upper():
            ip = socket.inet_ntoa(info.addresses[0]) if info.addresses else None
            port = info.port
            found[name] = {'ip': ip, 'port': port, 'server': info.server}

async def discover(timeout=8):
    zc = Zeroconf()
    try:
        browser = ServiceBrowser(zc, "_ipp._tcp.local.", handlers=[on_change])
        await asyncio.sleep(timeout)
    finally:
        zc.close()
    
    for name, data in found.items():
        print(f"Printer: {name}")
        print(f"  IP: {data['ip']}")
        print(f"  Port: {data['port']}")
        print(f"  Server: {data['server']}")
    
    return found

if __name__ == '__main__':
    devices = asyncio.run(discover())
    if not devices:
        print("NO_PRINTERS_FOUND")
