#!/usr/bin/env python3
"""
Quick MQTT test to verify connectivity to Meshtastic public MQTT server
Supports viewing encrypted messages (binary protobuf) and JSON messages
"""

import paho.mqtt.client as mqtt
import json
import time
import base64
from datetime import datetime

# MQTT Configuration
MQTT_HOST = "mqtt.meshtastic.org"
MQTT_PORT = 1883
MQTT_USERNAME = "meshdev"
MQTT_PASSWORD = "large4cats"

# Subscribe to ANZ region (Australia/New Zealand)
# msh/<region>/2/e/<channel>/!<node_id> for encrypted protobuf
# msh/<region>/2/json/<channel>/!<node_id> for JSON
TOPIC = "msh/ANZ/2/json/Main/!9c3a29a9"

# Message counter
msg_count = 0


def on_connect(client, userdata, flags, rc, properties=None):
    if rc == 0:
        print(f"✅ Connected to {MQTT_HOST}")
        print(f"📡 Subscribing to: {TOPIC}")
        client.subscribe(TOPIC)
    else:
        print(f"❌ Connection failed with code: {rc}")
        codes = {
            1: "Incorrect protocol version",
            2: "Invalid client identifier", 
            3: "Server unavailable",
            4: "Bad username or password",
            5: "Not authorized"
        }
        print(f"   Reason: {codes.get(rc, 'Unknown')}")


def on_message(client, userdata, msg):
    global msg_count
    msg_count += 1
    
    topic = msg.topic
    payload_len = len(msg.payload)
    timestamp = datetime.now().strftime("%H:%M:%S")
    
    # Parse topic to understand message type
    # Format: msh/<region>/2/<type>/<channel>/!<node_id>
    parts = topic.split('/')
    msg_type = parts[3] if len(parts) > 3 else "unknown"
    channel = parts[4] if len(parts) > 4 else "?"
    node_id = parts[5] if len(parts) > 5 else "?"
    
    print(f"\n[{timestamp}] #{msg_count} {'🔐' if msg_type == 'e' else '📄'} {channel} from {node_id}")
    print(f"   Topic: {topic}")
    
    if msg_type == "json":
        # JSON message (unencrypted)
        try:
            data = json.loads(msg.payload.decode('utf-8'))
            print(f"   Type: JSON (unencrypted)")
            # Pretty print relevant fields
            if 'type' in data:
                print(f"   Msg Type: {data.get('type')}")
            if 'payload' in data:
                payload = data.get('payload', {})
                if isinstance(payload, dict):
                    print(f"   Payload: {json.dumps(payload)[:150]}")
            if 'sender' in data:
                print(f"   Sender: {data.get('sender')}")
        except Exception as e:
            print(f"   JSON parse error: {e}")
            
    elif msg_type == "e":
        # Encrypted protobuf (ServiceEnvelope)
        print(f"   Type: Encrypted protobuf ({payload_len} bytes)")
        print(f"   Raw hex: {msg.payload[:48].hex()}{'...' if payload_len > 48 else ''}")
        # Note: To decrypt, you'd need the channel PSK and meshtastic protobuf definitions
        # The payload is a ServiceEnvelope containing an encrypted MeshPacket
        
    else:
        # Unknown format
        print(f"   Type: Unknown ({msg_type})")
        print(f"   Size: {payload_len} bytes")


def on_disconnect(client, userdata, disconnect_flags, rc, properties=None):
    if rc != 0:
        print(f"⚠️  Unexpected disconnect (rc={rc})")
    else:
        print("👋 Disconnected")


def main():
    print("=" * 50)
    print("Meshtastic MQTT Connection Test")
    print("=" * 50)
    print(f"Host: {MQTT_HOST}:{MQTT_PORT}")
    print(f"User: {MQTT_USERNAME}")
    print("=" * 50)
    
    # Create client with MQTT v5
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    
    # Set credentials
    client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
    
    # Set callbacks
    client.on_connect = on_connect
    client.on_message = on_message
    client.on_disconnect = on_disconnect
    
    try:
        print("\n🔌 Connecting...")
        client.connect(MQTT_HOST, MQTT_PORT, keepalive=60)
        
        print("⏳ Listening... (Ctrl+C to stop)\n")
        client.loop_forever()
        
    except KeyboardInterrupt:
        print("\n\n🛑 Stopped by user")
        client.disconnect()
    except Exception as e:
        print(f"\n❌ Error: {e}")


if __name__ == "__main__":
    main()
