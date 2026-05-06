#!/usr/bin/env python3
"""
SocialMesh TCP Attack Server

Accepts connections from the app (via mDNS discovery) and sends
malicious payloads to test resilience.

Attack suites:
  1. Framing abuse — bad magic, oversized, incomplete, repeated magic
  2. Protobuf fuzz — garbage in valid frames, deep nesting, overflow
  3. Data flood — 1MB of framed garbage as fast as possible
  4. Buffer exhaustion — partial frames, slowloris, byte-at-a-time
"""
import socket
import struct
import sys
import time
import threading
import subprocess
import signal
import os

PORT = 4403
HOST = '0.0.0.0'
MDNS_PID = None

# Colors
RED = '\033[1;31m'
GREEN = '\033[1;32m'
YELLOW = '\033[1;33m'
CYAN = '\033[1;36m'
MAGENTA = '\033[1;35m'
RESET = '\033[0m'
DIM = '\033[0;37m'

pass_count = 0
fail_count = 0


def log_header(msg):
    print(f'\n{CYAN}═══ {msg} ═══{RESET}')


def log_test(msg):
    print(f'  {YELLOW}▶ {msg}{RESET}')


def log_pass(msg):
    global pass_count
    print(f'  {GREEN}✓ PASS:{RESET} {msg}')
    pass_count += 1


def log_fail(msg):
    global fail_count
    print(f'  {RED}✗ FAIL:{RESET} {msg}')
    fail_count += 1


def log_info(msg):
    print(f'  {DIM}  {msg}{RESET}')


def log_warn(msg):
    print(f'  {MAGENTA}⚠ WARN:{RESET} {msg}')


def frame_payload(data: bytes) -> bytes:
    """Wrap data in 0x94 0xC3 frame with 16-bit BE length."""
    length = len(data)
    return bytes([0x94, 0xC3]) + struct.pack('>H', length) + data


def get_local_ip():
    try:
        result = subprocess.run(
            ['ipconfig', 'getifaddr', 'en0'],
            capture_output=True, text=True, timeout=3
        )
        ip = result.stdout.strip()
        if ip:
            return ip
    except Exception:
        pass
    try:
        result = subprocess.run(
            ['ipconfig', 'getifaddr', 'en1'],
            capture_output=True, text=True, timeout=3
        )
        return result.stdout.strip()
    except Exception:
        return '127.0.0.1'


def start_mdns(name='ATTACK', node_id='666deadbeef'):
    """Register mDNS service via dns-sd."""
    global MDNS_PID
    cmd = [
        'dns-sd', '-R', f'Mesh_{name}', '_meshtastic._tcp', 'local',
        str(PORT), f'shortname={name}', f'id={node_id}'
    ]
    proc = subprocess.Popen(
        cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    MDNS_PID = proc.pid
    time.sleep(2)
    return proc


def stop_mdns():
    global MDNS_PID
    if MDNS_PID:
        try:
            os.kill(MDNS_PID, signal.SIGTERM)
        except ProcessLookupError:
            pass
        MDNS_PID = None
    subprocess.run(
        ['pkill', '-f', 'dns-sd -R.*_meshtastic._tcp'],
        capture_output=True
    )
    time.sleep(0.5)


def wait_for_connection(server_sock, timeout=60):
    """Wait for the app to connect."""
    server_sock.settimeout(timeout)
    try:
        conn, addr = server_sock.accept()
        print(f'\n  {GREEN}✓ App connected from {addr}{RESET}')
        # Read any initial data the app sends (heartbeat, config req)
        conn.settimeout(2)
        try:
            initial = conn.recv(4096)
            log_info(f'Received {len(initial)} bytes from app: '
                     f'{initial[:32].hex()}...')
        except socket.timeout:
            log_info('No initial data from app (timeout)')
        return conn
    except socket.timeout:
        log_fail('No connection from app within timeout')
        return None


def run_attack_suite(conn: socket.socket, suite: str):
    """Send attack payloads through connected socket."""

    if suite == 'framing':
        run_framing_attacks(conn)
    elif suite == 'proto':
        run_proto_attacks(conn)
    elif suite == 'flood':
        run_flood_attacks(conn)
    elif suite == 'buffer':
        run_buffer_attacks(conn)
    elif suite == 'all':
        run_framing_attacks(conn)
        time.sleep(1)
        run_proto_attacks(conn)
        time.sleep(1)
        run_flood_attacks(conn)
        time.sleep(1)
        run_buffer_attacks(conn)


def send_payload(conn: socket.socket, data: bytes, name: str,
                 delay_after=0.3) -> bool:
    """Send payload and check if connection is still alive."""
    try:
        conn.sendall(data)
        time.sleep(delay_after)
        # Try to check if connection is still open by attempting a small read
        conn.settimeout(0.5)
        try:
            peek = conn.recv(4096, socket.MSG_PEEK)
            if len(peek) == 0:
                log_fail(f'{name} — connection closed by app')
                return False
        except socket.timeout:
            pass  # Timeout is fine — means connection is still open
        except ConnectionResetError:
            log_fail(f'{name} — connection RESET by app')
            return False
        except BrokenPipeError:
            log_fail(f'{name} — broken pipe (app crashed?)')
            return False
        log_pass(f'{name} — app survived ({len(data)} bytes sent)')
        return True
    except (BrokenPipeError, ConnectionResetError, OSError) as e:
        log_fail(f'{name} — send failed: {e}')
        return False


# ═══════════════════════════════════════════════
# ATTACK SUITE 1: FRAMING ABUSE
# ═══════════════════════════════════════════════

def run_framing_attacks(conn):
    log_header('ATTACK 1: Packet Framing Abuse')

    # 1a. Zero-length frame
    log_test('1a. Zero-length frame (94 C3 00 00)')
    send_payload(conn, bytes([0x94, 0xC3, 0x00, 0x00]), '1a_zero_length')

    # 1b. Max uint16 length header with no data
    log_test('1b. Max length header (94 C3 FF FF) — no payload follows')
    send_payload(conn, bytes([0x94, 0xC3, 0xFF, 0xFF]), '1b_max_length')

    # 1c. Length > 512 (exceeds _maxPacketSize) with garbage
    log_test('1c. Oversized frame (length=1024, 1024 bytes garbage)')
    send_payload(conn,
                 bytes([0x94, 0xC3, 0x04, 0x00]) + b'\x41' * 1024,
                 '1c_oversized')

    # 1d. Incomplete frame (length=10, only 3 bytes)
    log_test('1d. Incomplete frame (declares 10 bytes, sends 3)')
    send_payload(conn,
                 bytes([0x94, 0xC3, 0x00, 0x0A]) + b'\x41\x42\x43',
                 '1d_incomplete')

    # 1e. Raw data without any framing
    log_test('1e. Raw data — no 0x94/0xC3 framing')
    send_payload(conn, b'\xDE\xAD\xBE\xEF\xCA\xFE\xBA\xBE',
                 '1e_no_framing')

    # 1f. Repeated magic bytes
    log_test('1f. 200 repeated magic pairs (94 C3 94 C3...)')
    send_payload(conn, bytes([0x94, 0xC3] * 200), '1f_repeated_magic')

    # 1g. Valid frame + garbage trailer
    log_test('1g. Valid 4-byte frame followed by garbage')
    valid = frame_payload(b'\x08\x01\x10\x02')
    send_payload(conn, valid + b'\xFF' * 64, '1g_frame_plus_garbage')

    # 1h. Only the start byte, no second magic
    log_test('1h. Lone 0x94 byte (no 0xC3)')
    send_payload(conn, bytes([0x94, 0x00, 0x00, 0x04, 0x41, 0x42]),
                 '1h_lone_start_byte')

    # 1i. Alternating valid and invalid frames
    log_test('1i. Valid frame → garbage → valid frame → garbage (10x)')
    payload = b''
    for _ in range(10):
        payload += frame_payload(b'\x08\x01')  # valid
        payload += b'\xFF\xFE\xFD\xFC'  # garbage
    send_payload(conn, payload, '1i_interleaved')


# ═══════════════════════════════════════════════
# ATTACK SUITE 2: PROTOBUF FUZZING
# ═══════════════════════════════════════════════

def run_proto_attacks(conn):
    log_header('ATTACK 2: Protobuf Payload Fuzzing')

    # 2a. Empty protobuf in valid frame
    log_test('2a. Empty protobuf (0-byte payload)')
    send_payload(conn, frame_payload(b''), '2a_empty_proto')

    # 2b. Single zero byte
    log_test('2b. Single zero byte (invalid field 0)')
    send_payload(conn, frame_payload(b'\x00'), '2b_zero_byte')

    # 2c. Deep varint (10 continuation bytes)
    log_test('2c. Deep varint — 10 continuation bytes')
    send_payload(conn,
                 frame_payload(b'\x08' + b'\xff' * 9 + b'\x7f'),
                 '2c_deep_varint')

    # 2d. String field with length > remaining data
    log_test('2d. String field declares 128 bytes, only 3 present')
    send_payload(conn,
                 frame_payload(b'\x0a\x80\x01\x41\x42\x43'),
                 '2d_string_overflow')

    # 2e. 512 bytes of 0xFF
    log_test('2e. 512 bytes of 0xFF in valid frame')
    send_payload(conn, frame_payload(b'\xFF' * 512), '2e_all_ff')

    # 2f. Valid FromRadio-like structure with unknown field 999
    log_test('2f. Unknown protobuf field number 999')
    # Field 999, wire type 0: (999 << 3 | 0) = 7992
    # Varint encode 7992: 0xB8 0x3E
    send_payload(conn, frame_payload(b'\xb8\x3e\x01'), '2f_unknown_field')

    # 2g. Recursive nesting (50 levels deep)
    log_test('2g. Recursive length-delimited nesting (50 levels)')
    payload = b''
    for _ in range(50):
        inner = b'\x0a' + bytes([len(payload)]) + payload
        payload = inner
    send_payload(conn, frame_payload(payload), '2g_recursive_50')

    # 2h. Massive varint (claims enormous int)
    log_test('2h. Varint claiming 2^63 value')
    send_payload(conn,
                 frame_payload(
                     b'\x08\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01'
                 ),
                 '2h_massive_varint')

    # 2i. 500 valid-looking FromRadio packets (rapid fire)
    log_test('2i. 500 rapid-fire valid-looking FromRadio packets')
    # Minimal FromRadio: field 1 (id) = varint 42
    mini_from_radio = frame_payload(b'\x08\x2a')
    batch = mini_from_radio * 500
    send_payload(conn, batch, '2i_rapid_fire_500', delay_after=1.0)


# ═══════════════════════════════════════════════
# ATTACK SUITE 3: DATA FLOOD
# ═══════════════════════════════════════════════

def run_flood_attacks(conn):
    log_header('ATTACK 3: Data Flood')

    # 3a. 1MB of framed garbage as fast as possible
    log_test('3a. 1MB data flood (framed 500-byte garbage packets)')
    frame = frame_payload(b'\x41' * 500)
    total = 0
    start = time.time()
    try:
        while total < 1_000_000:
            conn.sendall(frame)
            total += len(frame)
        elapsed = time.time() - start
        log_pass(f'3a_flood — sent {total:,} bytes in {elapsed:.2f}s '
                 f'({total / elapsed / 1024:.0f} KB/s)')
    except (BrokenPipeError, ConnectionResetError) as e:
        elapsed = time.time() - start
        log_warn(f'3a_flood — connection died after {total:,} bytes '
                 f'in {elapsed:.2f}s: {e}')

    time.sleep(1)

    # 3b. 10MB of unframed raw bytes
    log_test('3b. 10MB raw byte flood (no framing)')
    total = 0
    chunk = b'\xAA' * 8192
    start = time.time()
    try:
        while total < 10_000_000:
            conn.sendall(chunk)
            total += len(chunk)
        elapsed = time.time() - start
        log_pass(f'3b_raw_flood — sent {total:,} bytes in {elapsed:.2f}s')
    except (BrokenPipeError, ConnectionResetError) as e:
        elapsed = time.time() - start
        log_warn(f'3b_raw_flood — connection died after {total:,} bytes '
                 f'in {elapsed:.2f}s: {e}')


# ═══════════════════════════════════════════════
# ATTACK SUITE 4: BUFFER EXHAUSTION
# ═══════════════════════════════════════════════

def run_buffer_attacks(conn):
    log_header('ATTACK 4: Buffer Exhaustion')

    # 4a. Send frame header claiming 500 bytes, drip data 1 byte/sec
    log_test('4a. Slow drip — frame header for 500 bytes, '
             'sending 1 byte/sec')
    try:
        conn.sendall(bytes([0x94, 0xC3, 0x01, 0xF4]))
        for i in range(20):
            conn.sendall(bytes([0x42]))
            time.sleep(1.0)
        log_pass('4a_slow_drip — sent 20/500 bytes over 20 seconds')
    except (BrokenPipeError, ConnectionResetError) as e:
        log_warn(f'4a_slow_drip — connection dropped after drip: {e}')

    # 4b. Many frame headers, never completing any
    log_test('4b. 100 frame headers with no payloads')
    try:
        for _ in range(100):
            conn.sendall(bytes([0x94, 0xC3, 0x00, 0x10]))
            time.sleep(0.05)
        log_pass('4b_header_storm — sent 100 incomplete frame headers')
    except (BrokenPipeError, ConnectionResetError) as e:
        log_warn(f'4b_header_storm — connection dropped: {e}')

    # 4c. Interleave partial frames with valid ones
    log_test('4c. 50 partial frames interleaved with valid frames')
    try:
        for i in range(50):
            # Partial (header + 2 of 16 bytes)
            conn.sendall(
                bytes([0x94, 0xC3, 0x00, 0x10, 0xAA, 0xBB])
            )
            # Immediately follow with valid frame
            conn.sendall(frame_payload(b'\x08\x01'))
            time.sleep(0.05)
        log_pass('4c_interleaved — 50 partial+valid pairs sent')
    except (BrokenPipeError, ConnectionResetError) as e:
        log_warn(f'4c_interleaved — connection dropped: {e}')


# ═══════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════

def main():
    suite = sys.argv[1] if len(sys.argv) > 1 else 'all'
    local_ip = get_local_ip()

    print()
    print('╔══════════════════════════════════════════════════════════════╗')
    print('║        ☠️  SocialMesh TCP Attack Server  ☠️                   ║')
    print('╠══════════════════════════════════════════════════════════════╣')
    print(f'║  WiFi IP:   {local_ip:<48}║')
    print(f'║  Port:      {PORT:<48}║')
    print(f'║  Suite:     {suite:<48}║')
    print('╠══════════════════════════════════════════════════════════════╣')
    print('║  1. This server advertises as a Meshtastic device          ║')
    print('║  2. When SocialMesh connects, attack payloads are sent     ║')
    print('║  3. Watch iOS console for SECURITY: prefixed log lines     ║')
    print('╚══════════════════════════════════════════════════════════════╝')
    print()

    # Register mDNS
    log_info('Registering mDNS service (ATTACK node)...')
    mdns_proc = start_mdns('HACK', 'deadc0de0666')
    log_pass(f'mDNS registered — look for HACK_deadc0de0666 on Connect screen')
    log_info(f'Advertising on {local_ip}:{PORT}')

    # Start TCP server
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(1)

    print(f'\n  {YELLOW}Waiting for SocialMesh to connect to HACK_deadc0de0666...{RESET}')
    print(f'  {DIM}(Open Connect screen, find the device, tap to connect){RESET}\n')

    conn = wait_for_connection(server, timeout=120)
    if not conn:
        stop_mdns()
        server.close()
        sys.exit(1)

    print(f'\n  {RED}☠️  ATTACKING...{RESET}\n')
    time.sleep(1)

    try:
        run_attack_suite(conn, suite)
    except Exception as e:
        log_fail(f'Attack suite error: {e}')
    finally:
        conn.close()
        server.close()
        stop_mdns()

    # Summary
    print()
    print('╔══════════════════════════════════════════════════════════════╗')
    print('║                     ATTACK RESULTS                         ║')
    print('╠══════════════════════════════════════════════════════════════╣')
    print(f'║  {GREEN}PASS: {pass_count:<3}{RESET}  '
          f'{RED}FAIL: {fail_count:<3}{RESET}'
          f'                                    ║')
    print('╠══════════════════════════════════════════════════════════════╣')
    print('║  Check iOS console for these log prefixes:                 ║')
    print('║    • mDNS SECURITY:   — TXT record sanitization           ║')
    print('║    • FRAMER SECURITY: — invalid frame handling             ║')
    print('║    • PROTO SECURITY:  — malformed protobuf handling        ║')
    print('║    • NET SECURITY:    — network chunk monitoring           ║')
    print('╚══════════════════════════════════════════════════════════════╝')

    if fail_count > 0:
        print(f'\n  {RED}⚠️  {fail_count} attack(s) crashed or killed the '
              f'connection!{RESET}')
        sys.exit(1)
    else:
        print(f'\n  {GREEN}App survived all attacks.{RESET}')


if __name__ == '__main__':
    signal.signal(signal.SIGINT, lambda *_: (stop_mdns(), sys.exit(0)))
    main()
