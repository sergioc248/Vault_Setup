#!/usr/bin/env python3
"""Generate the deterministic Vault 217 Mission 3 packet capture."""

from datetime import datetime, timezone
from pathlib import Path
import sys

from scapy.all import ARP, DNS, DNSQR, DNSRR, Ether, IP, Raw, TCP, UDP, wrpcap


SERVER_IP = "10.217.0.80"
SERVER_MAC = "02:00:00:02:17:80"
DNS_IP = "10.217.0.53"
DNS_MAC = "02:00:00:02:17:53"
BASE_TIME = datetime(2077, 10, 22, 23, 40, 50, tzinfo=timezone.utc).timestamp()

packets = []


def add(packet, offset):
    packet.time = BASE_TIME + offset
    packets.append(packet)


def http_exchange(client_ip, client_mac, sport, path, user_agent, token, status, body, offset, split=False):
    client_seq = 1000 + sport
    server_seq = 900000 + sport
    request_lines = [
        f"GET {path} HTTP/1.1",
        "Host: vault217.local",
        f"User-Agent: {user_agent}",
    ]
    if token is not None:
        request_lines.append(f"X-Vault-Archive-Token: {token}")
    request_lines.extend(["Connection: close", "", ""])
    request = "\r\n".join(request_lines).encode()
    status_text = "OK" if status == 200 else "Unauthorized"
    response_body = body.encode()
    response = (
        f"HTTP/1.1 {status} {status_text}\r\n"
        "Server: VaultArchive/2.17\r\n"
        "Content-Type: text/plain\r\n"
        f"Content-Length: {len(response_body)}\r\n"
        "Connection: close\r\n\r\n"
    ).encode() + response_body

    c2s = Ether(src=client_mac, dst=SERVER_MAC) / IP(src=client_ip, dst=SERVER_IP)
    s2c = Ether(src=SERVER_MAC, dst=client_mac) / IP(src=SERVER_IP, dst=client_ip)
    add(c2s / TCP(sport=sport, dport=80, flags="S", seq=client_seq), offset)
    add(s2c / TCP(sport=80, dport=sport, flags="SA", seq=server_seq, ack=client_seq + 1), offset + 0.03)
    add(c2s / TCP(sport=sport, dport=80, flags="A", seq=client_seq + 1, ack=server_seq + 1), offset + 0.06)

    if split:
        marker = request.find(b"X-Vault-Archive-Token")
        first, second = request[:marker], request[marker:]
        add(c2s / TCP(sport=sport, dport=80, flags="PA", seq=client_seq + 1, ack=server_seq + 1) / Raw(first), offset + 0.09)
        add(c2s / TCP(sport=sport, dport=80, flags="PA", seq=client_seq + 1 + len(first), ack=server_seq + 1) / Raw(second), offset + 0.12)
    else:
        add(c2s / TCP(sport=sport, dport=80, flags="PA", seq=client_seq + 1, ack=server_seq + 1) / Raw(request), offset + 0.09)

    request_end = client_seq + 1 + len(request)
    add(s2c / TCP(sport=80, dport=sport, flags="PA", seq=server_seq + 1, ack=request_end) / Raw(response), offset + 0.16)
    add(c2s / TCP(sport=sport, dport=80, flags="A", seq=request_end, ack=server_seq + 1 + len(response)), offset + 0.19)
    add(s2c / TCP(sport=80, dport=sport, flags="FA", seq=server_seq + 1 + len(response), ack=request_end), offset + 0.22)


def main():
    if len(sys.argv) != 2:
        raise SystemExit(f"Usage: {sys.argv[0]} OUTPUT.pcap")

    camera = {
        "01": ("10.217.0.101", "02:00:00:02:17:01"),
        "02": ("10.217.0.102", "02:00:00:02:17:02"),
        "03": ("10.217.0.103", "02:00:00:02:17:03"),
        "04": ("10.217.0.104", "02:00:00:02:17:04"),
    }

    add(Ether(src=camera["01"][1], dst="ff:ff:ff:ff:ff:ff") / ARP(op=1, psrc=camera["01"][0], pdst=SERVER_IP, hwsrc=camera["01"][1]), 0.00)
    add(Ether(src=SERVER_MAC, dst=camera["01"][1]) / ARP(op=2, psrc=SERVER_IP, pdst=camera["01"][0], hwsrc=SERVER_MAC, hwdst=camera["01"][1]), 0.08)
    add(Ether(src="02:00:00:02:17:10", dst=DNS_MAC) / IP(src="10.217.0.10", dst=DNS_IP) / UDP(sport=53017, dport=53) / DNS(id=217, rd=1, qd=DNSQR(qname="vault217.local")), 1.00)
    add(Ether(src=DNS_MAC, dst="02:00:00:02:17:10") / IP(src=DNS_IP, dst="10.217.0.10") / UDP(sport=53, dport=53017) / DNS(id=217, qr=1, aa=1, qd=DNSQR(qname="vault217.local"), an=DNSRR(rrname="vault217.local", rdata=SERVER_IP)), 1.08)

    http_exchange(*camera["01"], 41001, "/internal/cameras/archive.php?camera=01", "VaultCam/3.7", "VT217-CAM01-EXPIRED", 401, "CAMERA 01: ARCHIVE TOKEN EXPIRED\n", 4.00)
    http_exchange("10.217.0.5", "02:00:00:02:17:05", 42005, "/internal/janus/status", "JANUS-Core/9.1", None, 200, "JANUS STATUS: LOCKDOWN PENDING\n", 7.00)
    http_exchange(*camera["02"], 41002, "/internal/cameras/archive.php?camera=02", "VaultCam/3.7", None, 401, "CAMERA 02: ARCHIVE TOKEN REQUIRED\n", 12.00)
    http_exchange(*camera["03"], 41003, "/internal/cameras/archive.php?camera=03", "VaultCam/3.7", "VT217-CAM03-REVOKED", 401, "CAMERA 03: ARCHIVE TOKEN REVOKED\n", 18.00)
    http_exchange("10.217.0.10", "02:00:00:02:17:10", 42117, "/internal/security/terminal", "VaultSec-Terminal/4.2", None, 200, "SECURITY TERMINAL: CAPTURE ACTIVE\n", 22.00)
    http_exchange(*camera["04"], 41004, "/internal/cameras/archive.php?camera=04", "VaultCam/3.7", "VT217-AURORA-CAM04", 200, "VAULT-TEC SECURITY CAMERA ARCHIVE\nCAMERA: 04\nSTATUS: ARCHIVE SUCCESSFULLY STORED\nACCESS TOKEN: VT217-AURORA-CAM04\n", 27.00, split=True)
    http_exchange(*camera["01"], 41101, "/internal/cameras/live.php?camera=01", "VaultCam/3.7", None, 200, "CAMERA 01: LIVE FEED ONLINE\n", 38.00)

    output = Path(sys.argv[1])
    output.parent.mkdir(parents=True, exist_ok=True)
    wrpcap(str(output), packets)
    print(f"Wrote {len(packets)} packets to {output}")


if __name__ == "__main__":
    main()
