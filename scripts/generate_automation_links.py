#!/usr/bin/env python3
import base64
import json

automations = [
    {
        "name": "Low Battery Alert",
        "description": "Notify when Meshtastic b0f4 battery drops below 20%",
        "trigger": {
            "type": "batteryLow",
            "nodeNum": 1130139892,
            "threshold": 20,
            "hysteresis": 5
        },
        "actions": [
            {"type": "notification", "title": "Battery Low", "message": "Node b0f4 battery at {battery}%"},
            {"type": "sound", "rtttl": "BatteryLow:d=4,o=5,b=100:16e6,16e6,16e6"}
        ]
    },
    {
        "name": "Node Offline Alert",
        "description": "Alert when b0f4 goes offline for 10 minutes",
        "trigger": {
            "type": "nodeOffline",
            "nodeNum": 1130139892,
            "duration": 600
        },
        "actions": [
            {"type": "notification", "title": "Node Offline", "message": "Meshtastic b0f4 has been offline for 10 minutes"}
        ]
    },
    {
        "name": "Emergency Keyword",
        "description": "Alert on emergency messages from any node",
        "trigger": {
            "type": "messageContains",
            "keywords": ["help", "emergency", "sos"]
        },
        "actions": [
            {"type": "notification", "title": "Emergency Message", "message": "Emergency keyword detected from {nodeShortName}", "priority": "high"},
            {"type": "sound", "rtttl": "Alert:d=4,o=5,b=180:16e6,16p,16e6,16p,16e6"},
            {"type": "vibrate", "pattern": [0, 500, 200, 500]}
        ]
    }
]

for i, automation in enumerate(automations, 1):
    json_str = json.dumps(automation, separators=(",", ":"))
    base64_data = base64.b64encode(json_str.encode()).decode().replace("+", "-").replace("/", "_").rstrip("=")
    print(f"\nAutomation {i}: {automation['name']}")
    print(f"Base64: {base64_data}")
