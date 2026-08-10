// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Route tags for the non-conversation screens a notification tap can open.
//
// Same contract as the conversation tags: the tag identifies the target, not
// just the screen class, so a second notification about the same node, event
// or flight lands on the screen already open instead of stacking a copy.
// Conversation threads have their own tags in `conversation_routes.dart`.
//
// These are opaque stack tags, never passed to `pushNamed`, so they carry no
// leading slash and cannot collide with an `onGenerateRoute` path.

const String _screenRoutePrefix = 'screen';

/// Stack tag for the detail screen of one mesh node.
String nodeDetailRouteName(int nodeNum) => '$_screenRoutePrefix:node:$nodeNum';

/// Stack tag for the detection-sensor log of one node.
String detectionLogRouteName(int nodeNum) =>
    '$_screenRoutePrefix:detection:$nodeNum';

/// Stack tag for the map centred on one shared waypoint.
String waypointMapRouteName(int waypointId) =>
    '$_screenRoutePrefix:waypoint:$waypointId';

/// Stack tag for one TAK event's detail screen.
String takEventRouteName(String uid) => '$_screenRoutePrefix:tak:$uid';

/// Stack tag for one Aether flight's detail screen. Flight numbers are
/// uppercased so a tag from a notification matches one from the flight store.
String aetherFlightRouteName(String flightNumber) =>
    '$_screenRoutePrefix:aether:${flightNumber.toUpperCase()}';

/// Stack tag for one SIP DM session.
String sipDmRouteName(int sessionTag) =>
    '$_screenRoutePrefix:sip-dm:$sessionTag';

/// Stack tags for screens that exist only once, so the target is the screen.
const String petHomeRouteName = '$_screenRoutePrefix:pet-home';
const String firmwareUpdateRouteName = '$_screenRoutePrefix:firmware-update';
const String meshCoreNodesRouteName = '$_screenRoutePrefix:meshcore-nodes';
