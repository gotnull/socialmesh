/**
 * World Mesh Map - Interactive web map page
 * Matches Socialmesh app design and functionality
 */

export function generateMapPage(): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>World Mesh Map — Socialmesh</title>
  <meta name="description" content="Real-time interactive map of the global Meshtastic mesh network. Explore thousands of nodes worldwide.">
  
  <!-- Smart App Banner (iOS Safari) -->
  <meta name="apple-itunes-app" content="app-id=6742694642">
  
  <!-- Favicon -->
  <link rel="icon" type="image/png" href="https://socialmesh.app/favicon.png">
  
  <!-- Leaflet CSS -->
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" crossorigin="" />
  <link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.css" />
  <link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css" />
  
  <!-- Fonts -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  
  <style>
    :root {
      --bg-primary: #1F2633;
      --bg-secondary: #29303D;
      --bg-card: #29303D;
      --border-color: #414A5A;
      --accent-magenta: #E91E8C;
      --accent-purple: #8B5CF6;
      --accent-blue: #4F6AF6;
      --success: #4ADE80;
      --warning: #FBBF24;
      --error: #EF4444;
      --text-primary: #FFFFFF;
      --text-secondary: #D1D5DB;
      --text-muted: #9CA3AF;
      --gradient-brand: linear-gradient(135deg, #E91E8C 0%, #8B5CF6 50%, #4F6AF6 100%);
    }
    
    * { box-sizing: border-box; margin: 0; padding: 0; }
    
    html, body {
      touch-action: none;
      -webkit-touch-callout: none;
      -webkit-user-select: none;
      user-select: none;
    }
    
    body {
      font-family: 'JetBrains Mono', 'Inter', -apple-system, BlinkMacSystemFont, monospace;
      background: var(--bg-primary);
      color: var(--text-primary);
      height: 100vh;
      overflow: hidden;
    }
    
    #map {
      touch-action: manipulation;
    }
    
    /* Navigation */
    nav {
      position: fixed;
      top: 0; left: 0; right: 0;
      z-index: 1000;
      padding: 12px 0;
      background: rgba(31, 38, 51, 0.95);
      backdrop-filter: blur(20px);
      border-bottom: 1px solid var(--border-color);
    }
    
    nav .container {
      display: flex;
      justify-content: space-between;
      align-items: center;
      max-width: 100%;
      margin: 0 auto;
      padding: 0 16px;
    }
    
    .logo {
      display: flex;
      align-items: center;
      gap: 10px;
      text-decoration: none;
    }
    
    .logo-img {
      width: 36px; height: 36px;
      border-radius: 8px;
      box-shadow: 0 4px 20px rgba(233, 30, 140, 0.3);
    }
    
    .logo-text {
      font-size: 18px;
      font-weight: 700;
      color: var(--text-primary);
      letter-spacing: -0.5px;
    }
    
    .nav-stats {
      display: none;
      gap: 16px;
      align-items: center;
    }
    
    @media (min-width: 768px) {
      .nav-stats {
        display: flex;
      }
    }
    
    .stat-item {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 13px;
      color: var(--text-secondary);
    }
    
    .stat-value {
      font-family: 'JetBrains Mono', monospace;
      font-weight: 600;
      color: var(--accent-magenta);
      transition: transform 0.3s ease, color 0.3s ease;
    }
    
    .stat-value.updating {
      transform: scale(1.15);
      color: var(--success);
    }
    
    .stat-dot {
      width: 8px; height: 8px;
      border-radius: 50%;
      background: var(--success);
      animation: pulse 2s infinite;
    }
    
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }
    
    .nav-actions {
      display: flex;
      gap: 8px;
      align-items: center;
    }
    
    .btn {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 8px 16px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      text-decoration: none;
      cursor: pointer;
      border: none;
      transition: all 0.2s;
    }
    
    .btn-icon {
      width: 16px; height: 16px;
      fill: currentColor;
    }
    
    .btn-secondary {
      background: var(--bg-secondary);
      color: var(--text-secondary);
      border: 1px solid var(--border-color);
    }
    
    .btn-secondary:hover {
      background: var(--bg-card);
      color: var(--text-primary);
      border-color: var(--accent-purple);
    }
    
    .btn-primary {
      background: var(--gradient-brand);
      color: white;
    }
    
    .btn-primary:hover {
      transform: translateY(-1px);
      box-shadow: 0 4px 20px rgba(233, 30, 140, 0.3);
    }
    
    /* Map Container */
    #map {
      position: absolute;
      top: 60px;
      left: 0;
      right: 0;
      bottom: 0;
      background: var(--bg-primary);
    }
    
    /* Search Bar */
    .search-container {
      position: absolute;
      top: 76px;
      left: 16px;
      z-index: 1000;
      width: 320px;
    }
    
    .search-box {
      display: flex;
      align-items: center;
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 0 12px;
      transition: all 0.2s;
    }
    
    .search-box:focus-within {
      border-color: var(--accent-magenta);
      box-shadow: 0 0 0 3px rgba(233, 30, 140, 0.1);
    }
    
    .search-icon {
      width: 18px; height: 18px;
      fill: var(--text-muted);
      flex-shrink: 0;
    }
    
    .search-input {
      flex: 1;
      background: none;
      border: none;
      padding: 12px;
      color: var(--text-primary);
      font-family: 'JetBrains Mono', monospace;
      font-size: 14px;
      outline: none;
    }
    
    .search-input::placeholder {
      color: var(--text-muted);
    }
    
    .search-clear {
      background: none;
      border: none;
      padding: 4px;
      cursor: pointer;
      color: var(--text-muted);
      display: none;
    }
    
    .search-clear.visible {
      display: block;
    }
    
    .search-results {
      position: absolute;
      top: 100%;
      left: 0;
      right: 0;
      margin-top: 8px;
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      max-height: 400px;
      overflow-y: auto;
      display: none;
    }
    
    .search-results.visible {
      display: block;
    }
    
    .search-result-item {
      padding: 12px 16px;
      cursor: pointer;
      border-bottom: 1px solid var(--border-color);
      transition: background 0.15s;
    }
    
    .search-result-item:last-child {
      border-bottom: none;
    }
    
    .search-result-item:hover {
      background: var(--bg-secondary);
    }
    
    .search-result-name {
      font-weight: 600;
      color: var(--text-primary);
      margin-bottom: 2px;
    }
    
    .search-result-meta {
      font-size: 12px;
      color: var(--text-muted);
      display: flex;
      gap: 8px;
    }
    
    /* Filter Panel */
    .filter-panel {
      position: absolute;
      top: 76px;
      right: 16px;
      z-index: 1000;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    
    .filter-btn {
      width: 44px;
      height: 44px;
      border-radius: 12px;
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      color: var(--text-secondary);
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s;
    }
    
    .filter-btn:hover {
      background: var(--bg-secondary);
      border-color: var(--accent-purple);
      color: var(--text-primary);
    }
    
    .filter-btn.active {
      background: var(--accent-magenta);
      border-color: var(--accent-magenta);
      color: white;
    }
    
    .filter-btn svg {
      width: 20px;
      height: 20px;
      fill: currentColor;
    }
    
    /* Map Controls */
    .map-controls {
      position: absolute;
      bottom: 100px;
      right: 16px;
      z-index: 1000;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    
    .map-control-btn {
      width: 44px;
      height: 44px;
      border-radius: 12px;
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      color: var(--text-secondary);
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s;
      font-size: 20px;
      font-weight: 300;
    }
    
    .map-control-btn:hover {
      background: var(--bg-secondary);
      border-color: var(--accent-purple);
      color: var(--text-primary);
    }
    
    .map-control-btn:disabled {
      opacity: 0.5;
      cursor: not-allowed;
    }
    
    .map-control-btn svg {
      width: 20px;
      height: 20px;
      fill: currentColor;
    }
    
    .map-control-btn.center-all {
      background: linear-gradient(135deg, rgba(233, 30, 140, 0.15) 0%, rgba(139, 92, 246, 0.15) 100%);
      border-color: rgba(233, 30, 140, 0.3);
    }
    
    .map-control-btn.center-all:hover {
      background: linear-gradient(135deg, rgba(233, 30, 140, 0.25) 0%, rgba(139, 92, 246, 0.25) 100%);
      border-color: var(--accent-magenta);
    }
    
    .map-control-btn.center-all svg {
      fill: var(--accent-magenta);
    }
    
    .map-control-divider {
      width: 24px;
      height: 1px;
      background: var(--border-color);
      margin: 4px auto;
    }
    
    /* Node Info Panel */
    .node-panel {
      position: absolute;
      bottom: 16px;
      left: 16px;
      right: 16px;
      max-width: 420px;
      z-index: 1000;
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 20px;
      overflow: hidden;
      display: none;
      animation: slideUp 0.3s ease-out;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
    }
    
    .node-panel.visible {
      display: block;
    }
    
    @keyframes slideUp {
      from { transform: translateY(20px); opacity: 0; }
      to { transform: translateY(0); opacity: 1; }
    }
    
    .node-panel-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 16px 20px;
      background: linear-gradient(135deg, rgba(233, 30, 140, 0.1) 0%, rgba(139, 92, 246, 0.1) 100%);
      border-bottom: 1px solid var(--border-color);
    }
    
    .node-panel-title {
      display: flex;
      align-items: center;
      gap: 14px;
    }
    
    .node-avatar {
      width: 48px; height: 48px;
      border-radius: 14px;
      background: var(--gradient-brand);
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 700;
      font-size: 16px;
      color: white;
      box-shadow: 0 4px 12px rgba(233, 30, 140, 0.3);
    }
    
    .node-name {
      font-weight: 700;
      font-size: 17px;
      letter-spacing: -0.3px;
    }
    
    .node-id {
      font-family: 'JetBrains Mono', monospace;
      font-size: 12px;
      color: var(--text-muted);
      margin-top: 2px;
    }
    
    .node-header-actions {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    
    .node-status {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 12px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    
    .node-status::before {
      content: '';
      width: 6px;
      height: 6px;
      border-radius: 50%;
      animation: pulse 2s infinite;
    }
    
    .node-status.online {
      background: rgba(74, 222, 128, 0.15);
      color: var(--success);
    }
    .node-status.online::before {
      background: var(--success);
    }
    
    .node-status.idle {
      background: rgba(251, 191, 36, 0.15);
      color: var(--warning);
    }
    .node-status.idle::before {
      background: var(--warning);
    }
    
    .node-status.offline {
      background: rgba(156, 163, 175, 0.15);
      color: var(--text-muted);
    }
    .node-status.offline::before {
      background: var(--text-muted);
      animation: none;
    }
    
    .node-panel-close {
      background: none;
      border: none;
      color: var(--text-muted);
      cursor: pointer;
      padding: 8px;
      border-radius: 10px;
      transition: all 0.15s;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    
    .node-panel-close:hover {
      background: var(--bg-secondary);
      color: var(--text-primary);
    }
    
    .node-panel-close svg {
      width: 18px;
      height: 18px;
      fill: currentColor;
    }
    
    .node-panel-content {
      padding: 20px;
      max-height: 350px;
      overflow-y: auto;
    }
    
    .node-section {
      margin-bottom: 20px;
    }
    
    .node-section:last-child {
      margin-bottom: 0;
    }
    
    .node-section-title {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 12px;
      font-weight: 700;
      color: var(--accent-magenta);
      text-transform: uppercase;
      letter-spacing: 0.8px;
      margin-bottom: 14px;
    }
    
    .node-section-title svg {
      width: 16px; height: 16px;
      fill: var(--accent-magenta);
    }
    
    .node-info-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 10px;
    }
    
    .node-info-item {
      background: var(--bg-secondary);
      padding: 12px 14px;
      border-radius: 12px;
      border: 1px solid transparent;
      transition: border-color 0.15s;
    }
    
    .node-info-item:hover {
      border-color: var(--border-color);
    }
    
    .node-info-label {
      font-size: 10px;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 4px;
    }
    
    .node-info-value {
      font-size: 14px;
      font-weight: 600;
      color: var(--text-primary);
    }
    
    .node-metrics {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
    }
    
    .metric-chip {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 10px 14px;
      background: var(--bg-secondary);
      border-radius: 12px;
      font-size: 13px;
      font-weight: 500;
      border: 1px solid transparent;
      transition: all 0.15s;
    }
    
    .metric-chip:hover {
      border-color: var(--border-color);
    }
    
    .metric-chip svg {
      width: 16px; height: 16px;
    }
    
    .metric-chip.battery { color: var(--success); }
    .metric-chip.battery svg { fill: var(--success); }
    .metric-chip.battery.low { color: var(--warning); }
    .metric-chip.battery.low svg { fill: var(--warning); }
    .metric-chip.battery.critical { color: var(--error); }
    .metric-chip.battery.critical svg { fill: var(--error); }
    .metric-chip.voltage { color: #FBBF24; }
    .metric-chip.voltage svg { fill: #FBBF24; }
    .metric-chip.channel { color: #60A5FA; }
    .metric-chip.channel svg { fill: #60A5FA; }
    .metric-chip.airtx { color: #A78BFA; }
    .metric-chip.airtx svg { fill: #A78BFA; }
    .metric-chip.temp { color: #FB923C; }
    .metric-chip.temp svg { fill: #FB923C; }
    .metric-chip.humidity { color: #22D3EE; }
    .metric-chip.humidity svg { fill: #22D3EE; }
    .metric-chip.pressure { color: #2DD4BF; }
    .metric-chip.pressure svg { fill: #2DD4BF; }
    
    .node-panel-footer {
      display: flex;
      gap: 12px;
      padding: 16px 20px;
      border-top: 1px solid var(--border-color);
      background: var(--bg-secondary);
    }
    
    .node-action-btn {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      padding: 12px 16px;
      border-radius: 12px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
      border: none;
    }
    
    .node-action-btn svg {
      width: 16px;
      height: 16px;
      fill: currentColor;
    }
    
    .node-action-btn.secondary {
      background: var(--bg-card);
      color: var(--text-secondary);
      border: 1px solid var(--border-color);
    }
    
    .node-action-btn.secondary:hover {
      background: var(--bg-primary);
      color: var(--text-primary);
      border-color: var(--accent-purple);
    }
    
    .node-action-btn.primary {
      background: var(--gradient-brand);
      color: white;
    }
    
    .node-action-btn.primary:hover {
      transform: translateY(-1px);
      box-shadow: 0 4px 16px rgba(233, 30, 140, 0.3);
    }
    
    .node-last-seen {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 12px;
      color: var(--text-muted);
      margin-top: 16px;
      padding-top: 16px;
      border-top: 1px solid var(--border-color);
    }
    
    .node-last-seen svg {
      width: 14px;
      height: 14px;
      fill: var(--text-muted);
    }
    
    /* Loading Overlay */
    .loading-overlay {
      position: absolute;
      top: 60px;
      left: 0;
      right: 0;
      bottom: 0;
      background: var(--bg-primary);
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      z-index: 999;
    }
    
    .loading-overlay.hidden {
      display: none;
    }
    
    .loading-spinner {
      width: 60px;
      height: 60px;
      border: 3px solid var(--border-color);
      border-top-color: var(--accent-magenta);
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }
    
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
    
    .loading-text {
      margin-top: 16px;
      color: var(--text-secondary);
      font-size: 14px;
    }
    
    /* Leaflet Overrides */
    .leaflet-container {
      background: var(--bg-primary);
      font-family: 'Inter', sans-serif;
    }
    
    .leaflet-control-zoom {
      display: none;
    }
    
    .leaflet-control-attribution {
      background: rgba(31, 38, 51, 0.9) !important;
      color: var(--text-muted) !important;
      font-size: 10px !important;
      padding: 4px 8px !important;
    }
    
    .leaflet-control-attribution a {
      color: var(--accent-magenta) !important;
    }
    
    .marker-cluster-custom {
      background: rgba(233, 30, 140, 0.3);
      border-radius: 50%;
      display: flex !important;
      align-items: center !important;
      justify-content: center !important;
    }

    .node-marker {
      border-radius: 50%;
      border: 2px solid rgba(255, 255, 255, 0.8);
      box-shadow: 0 2px 6px rgba(0, 0, 0, 0.3);
      cursor: pointer;
      transition: transform 0.15s, box-shadow 0.15s;
    }
    
    .node-marker:hover {
      transform: scale(1.2);
    }
    
    .node-marker.selected {
      border-color: white;
      box-shadow: 0 0 0 4px rgba(233, 30, 140, 0.4), 0 2px 8px rgba(0, 0, 0, 0.4);
      z-index: 1000 !important;
    }
    
    .node-marker.online {
      background: var(--accent-magenta);
    }
    
    .node-marker.idle {
      background: rgba(233, 30, 140, 0.6);
    }
    
    .node-marker.offline {
      background: rgba(156, 163, 175, 0.5);
    }
    
    /* Filter Dropdown */
    .filter-dropdown {
      position: absolute;
      top: 0;
      right: 52px;
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 16px;
      min-width: 240px;
      display: none;
    }
    
    .filter-dropdown.visible {
      display: block;
    }
    
    .filter-dropdown h4 {
      font-size: 12px;
      font-weight: 600;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 12px;
    }
    
    .filter-option {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 0;
      cursor: pointer;
    }
    
    .filter-option input {
      accent-color: var(--accent-magenta);
      width: 16px;
      height: 16px;
    }
    
    .filter-option label {
      font-size: 14px;
      color: var(--text-secondary);
      cursor: pointer;
    }
    
    /* Mobile Responsive */
    @media (max-width: 768px) {
      .nav-stats {
        display: none;
      }
      
      .search-container {
        width: calc(100% - 80px);
        left: 8px;
      }
      
      .filter-panel {
        right: 8px;
      }
      
      .map-controls {
        right: 8px;
        bottom: 80px;
      }
      
      .node-panel {
        left: 8px;
        right: 8px;
        max-width: none;
      }
    }
    
    /* Map Style Toggle */
    .style-menu {
      position: absolute;
      bottom: 0;
      right: 52px;
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 8px;
      display: none;
    }
    
    .style-menu.visible {
      display: block;
    }
    
    .style-option {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 10px 12px;
      border-radius: 8px;
      cursor: pointer;
      transition: background 0.15s;
      white-space: nowrap;
    }
    
    .style-option:hover {
      background: var(--bg-secondary);
    }
    
    .style-option.active {
      background: rgba(233, 30, 140, 0.15);
      color: var(--accent-magenta);
    }
    
    .style-option svg {
      width: 16px; height: 16px;
      fill: currentColor;
    }
    
    /* Bottom Stats Bar (Mobile) */
    .bottom-stats {
      display: flex;
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      z-index: 999;
      background: rgba(31, 38, 51, 0.98);
      backdrop-filter: blur(20px);
      border-top: 1px solid var(--border-color);
      padding: 14px 16px 20px 16px;
      padding-bottom: max(20px, env(safe-area-inset-bottom));
      justify-content: space-around;
    }
    
    @media (min-width: 768px) {
      .bottom-stats {
        display: none;
      }
    }
    
    /* Hide Leaflet attribution on mobile to avoid overlap */
    @media (max-width: 767px) {
      .leaflet-control-attribution {
        display: none !important;
      }
    }
    
    .bottom-stat {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 2px;
    }
    
    .bottom-stat-value {
      font-family: 'JetBrains Mono', monospace;
      font-size: 18px;
      font-weight: 700;
      color: var(--accent-magenta);
      transition: transform 0.3s ease, color 0.3s ease;
    }
    
    .bottom-stat-value.updating {
      transform: scale(1.15);
      color: var(--success);
    }
    
    .bottom-stat-label {
      font-size: 10px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: var(--text-muted);
    }
    
    .bottom-stat .stat-dot {
      width: 6px;
      height: 6px;
      display: inline-block;
      margin-right: 4px;
    }
    
    /* Adjust node panel for bottom bar */
    @media (max-width: 767px) {
      .node-panel {
        bottom: 70px !important;
      }
      .map-controls {
        bottom: 80px !important;
      }
    }
  </style>
</head>
<body>
  <!-- Navigation -->
  <nav>
    <div class="container">
      <a href="https://socialmesh.app" target="_blank" rel="noopener" class="logo">
        <img src="https://socialmesh.app/images/app-icon.png" alt="Socialmesh" class="logo-img">
        <span class="logo-text">World Map</span>
      </a>
      
      <div class="nav-stats">
        <div class="stat-item">
          <span class="stat-dot"></span>
          <span id="nodeCount" class="stat-value">—</span>
          <span>nodes</span>
        </div>
        <div class="stat-item">
          <span id="onlineCount" class="stat-value">—</span>
          <span>online</span>
        </div>
      </div>
      
      <div class="nav-actions">
        <a href="/" class="btn btn-secondary">
          <svg class="btn-icon" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
          API
        </a>
        <a href="https://socialmesh.app#download" target="_blank" rel="noopener" class="btn btn-primary">
          <svg class="btn-icon" viewBox="0 0 24 24"><path d="M5 20h14v-2H5v2zM19 9h-4V3H9v6H5l7 7 7-7z"/></svg>
          Get App
        </a>
      </div>
    </div>
  </nav>
  
  <!-- Loading Overlay -->
  <div class="loading-overlay" id="loadingOverlay">
    <div class="loading-spinner"></div>
    <div class="loading-text">Loading mesh nodes...</div>
  </div>
  
  <!-- Map -->
  <div id="map"></div>
  
  <!-- Search -->
  <div class="search-container">
    <div class="search-box">
      <svg class="search-icon" viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>
      <input type="text" class="search-input" id="searchInput" placeholder="Find a node...">
      <button class="search-clear" id="searchClear" onclick="clearSearch()">✕</button>
    </div>
    <div class="search-results" id="searchResults"></div>
  </div>
  
  <!-- Filter Panel -->
  <div class="filter-panel">
    <button class="filter-btn" id="filterBtn" onclick="toggleFilter()" title="Filter nodes">
      <svg viewBox="0 0 24 24"><path d="M10 18h4v-2h-4v2zM3 6v2h18V6H3zm3 7h12v-2H6v2z"/></svg>
    </button>
    <div class="filter-dropdown" id="filterDropdown">
      <h4>Status</h4>
      <div class="filter-option">
        <input type="checkbox" id="filterOnline" checked onchange="applyFilters()">
        <label for="filterOnline">Online (< 1h)</label>
      </div>
      <div class="filter-option">
        <input type="checkbox" id="filterIdle" checked onchange="applyFilters()">
        <label for="filterIdle">Idle (1-24h)</label>
      </div>
      <div class="filter-option">
        <input type="checkbox" id="filterOffline" onchange="applyFilters()">
        <label for="filterOffline">Offline (> 24h)</label>
      </div>
      <h4 style="margin-top: 16px;">Device Type</h4>
      <div class="filter-option">
        <input type="checkbox" id="filterRouter" checked onchange="applyFilters()">
        <label for="filterRouter">Routers</label>
      </div>
      <div class="filter-option">
        <input type="checkbox" id="filterClient" checked onchange="applyFilters()">
        <label for="filterClient">Clients</label>
      </div>
      <div class="filter-option">
        <input type="checkbox" id="filterTracker" checked onchange="applyFilters()">
        <label for="filterTracker">Trackers</label>
      </div>
    </div>
  </div>
  
  <!-- Map Controls -->
  <div class="map-controls">
    <button class="map-control-btn" onclick="zoomIn()" title="Zoom in">
      <svg viewBox="0 0 24 24"><path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/></svg>
    </button>
    <button class="map-control-btn" onclick="zoomOut()" title="Zoom out">
      <svg viewBox="0 0 24 24"><path d="M19 13H5v-2h14v2z"/></svg>
    </button>
    <div class="map-control-divider"></div>
    <button class="map-control-btn center-all" onclick="fitAllNodes()" title="Center around all nodes">
      <svg viewBox="0 0 24 24"><path d="M15 3l2.3 2.3-2.89 2.87 1.42 1.42L18.7 6.7 21 9V3h-6zM3 9l2.3-2.3 2.87 2.89 1.42-1.42L6.7 5.3 9 3H3v6zm6 12l-2.3-2.3 2.89-2.87-1.42-1.42L5.3 17.3 3 15v6h6zm12-6l-2.3 2.3-2.87-2.89-1.42 1.42 2.89 2.87L15 21h6v-6z"/></svg>
    </button>
    <button class="map-control-btn" id="styleBtn" onclick="toggleStyleMenu()" title="Map style">
      <svg viewBox="0 0 24 24"><path d="M11.99 18.54l-7.37-5.73L3 14.07l9 7 9-7-1.63-1.27-7.38 5.74zM12 16l7.36-5.73L21 9l-9-7-9 7 1.63 1.27L12 16z"/></svg>
    </button>
    <div class="style-menu" id="styleMenu">
      <div class="style-option active" onclick="setMapStyle('dark')">
        <svg viewBox="0 0 24 24"><path d="M12 3a9 9 0 109 9c0-.46-.04-.92-.1-1.36a5.389 5.389 0 01-4.4 2.26 5.403 5.403 0 01-3.14-9.8c-.44-.06-.9-.1-1.36-.1z"/></svg>
        Dark
      </div>
      <div class="style-option" onclick="setMapStyle('satellite')">
        <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"/></svg>
        Satellite
      </div>
      <div class="style-option" onclick="setMapStyle('terrain')">
        <svg viewBox="0 0 24 24"><path d="M14 6l-3.75 5 2.85 3.8-1.6 1.2C9.81 13.75 7 10 7 10l-6 8h22L14 6z"/></svg>
        Terrain
      </div>
    </div>
  </div>
  
  <!-- Bottom Stats Bar (Mobile) -->
  <div class="bottom-stats">
    <div class="bottom-stat">
      <div class="bottom-stat-value" id="bottomNodeCount">—</div>
      <div class="bottom-stat-label">Total Nodes</div>
    </div>
    <div class="bottom-stat">
      <div class="bottom-stat-value" id="bottomOnlineCount">
        <span class="stat-dot" style="background: var(--success);"></span>—
      </div>
      <div class="bottom-stat-label">Online</div>
    </div>
    <div class="bottom-stat">
      <div class="bottom-stat-value" id="bottomIdleCount" style="color: var(--warning);">—</div>
      <div class="bottom-stat-label">Idle</div>
    </div>
  </div>
  
  <!-- Node Info Panel -->
  <div class="node-panel" id="nodePanel">
    <div class="node-panel-header">
      <div class="node-panel-title">
        <div class="node-avatar" id="nodeAvatar">??</div>
        <div>
          <div class="node-name" id="nodeName">Node Name</div>
          <div class="node-id" id="nodeId">!12345678</div>
        </div>
      </div>
      <div class="node-header-actions">
        <span class="node-status online" id="nodeStatus">
          <span>ONLINE</span>
        </span>
        <button class="node-panel-close" onclick="closeNodePanel()">
          <svg viewBox="0 0 24 24"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
        </button>
      </div>
    </div>
    <div class="node-panel-content" id="nodePanelContent">
      <!-- Dynamic content -->
    </div>
  </div>
  
  <!-- Leaflet JS -->
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" crossorigin=""></script>
  <script src="https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js"></script>
  
  <script>
    // State
    let map;
    let markers;
    let allNodes = {};
    let filteredNodes = {};
    let selectedNodeNum = null;
    let currentStyle = 'dark';
    
    // Map tile providers
    const tileLayers = {
      dark: L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OSM</a> &copy; <a href="https://carto.com/" target="_blank" rel="noopener">CARTO</a>',
        subdomains: 'abcd',
        maxZoom: 19
      }),
      satellite: L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
        attribution: '&copy; Esri',
        maxZoom: 19
      }),
      terrain: L.tileLayer('https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; <a href="https://opentopomap.org" target="_blank" rel="noopener">OpenTopoMap</a>',
        maxZoom: 17
      })
    };
    
    let currentTileLayer = tileLayers.dark;
    
    // Initialize map
    function initMap() {
      map = L.map('map', {
        center: [20, 0],
        zoom: 3,
        zoomControl: false,
        minZoom: 2,
        maxZoom: 18
      });
      
      currentTileLayer.addTo(map);
      
      // Marker cluster group
      markers = L.markerClusterGroup({
        maxClusterRadius: 80,
        spiderfyOnMaxZoom: true,
        showCoverageOnHover: false,
        iconCreateFunction: function(cluster) {
          const count = cluster.getChildCount();
          let outerSize = 36;
          let innerSize = 30;
          let fontSize = 12;
          if (count > 100) { outerSize = 52; innerSize = 44; fontSize = 14; }
          else if (count > 10) { outerSize = 44; innerSize = 36; fontSize = 13; }
          
          const displayCount = count > 999 ? (count / 1000).toFixed(1) + 'k' : count;
          
          // All styles inline to avoid CSS conflicts
          const html = '<div style="' +
            'width:' + innerSize + 'px;' +
            'height:' + innerSize + 'px;' +
            'background:#E91E8C;' +
            'color:white;' +
            'font-weight:700;' +
            'font-size:' + fontSize + 'px;' +
            'border-radius:50%;' +
            'display:flex;' +
            'align-items:center;' +
            'justify-content:center;' +
            'border:2px solid white;' +
            'box-shadow:0 2px 8px rgba(0,0,0,0.3);' +
            '">' + displayCount + '</div>';
          
          return L.divIcon({
            html: html,
            className: 'marker-cluster-custom',
            iconSize: L.point(outerSize, outerSize),
            iconAnchor: L.point(outerSize / 2, outerSize / 2)
          });
        }
      });
      
      map.addLayer(markers);
      
      // Load nodes
      loadNodes();
    }
    
    // Animate counter update
    function animateCounter(elementId, newValue, format = true) {
      const el = document.getElementById(elementId);
      if (!el) return;
      
      const displayValue = format ? newValue.toLocaleString() : newValue;
      const oldValue = el.textContent;
      
      // Only animate if value changed
      if (oldValue !== displayValue && oldValue !== '—') {
        el.classList.add('updating');
        setTimeout(() => el.classList.remove('updating'), 400);
      }
      
      el.textContent = displayValue;
    }
    
    // Load nodes from API
    async function loadNodes() {
      try {
        const response = await fetch('/internal/nodes');
        allNodes = await response.json();
        
        // Calculate stats
        const nodeCount = Object.keys(allNodes).length;
        const nodes = Object.values(allNodes);
        const onlineCount = nodes.filter(n => getNodeStatus(n) === 'online').length;
        const idleCount = nodes.filter(n => getNodeStatus(n) === 'idle').length;
        
        // Update nav stats (desktop)
        animateCounter('nodeCount', nodeCount);
        animateCounter('onlineCount', onlineCount);
        
        // Update bottom stats (mobile)
        animateCounter('bottomNodeCount', nodeCount);
        document.getElementById('bottomOnlineCount').innerHTML = '<span class="stat-dot" style="background: var(--success);"></span>' + onlineCount.toLocaleString();
        animateCounter('bottomIdleCount', idleCount);
        
        // Apply filters and render
        applyFilters();
        
        // Hide loading
        document.getElementById('loadingOverlay').classList.add('hidden');
      } catch (error) {
        console.error('Failed to load nodes:', error);
        document.querySelector('.loading-text').textContent = 'Failed to load nodes. Retrying...';
        setTimeout(loadNodes, 3000);
      }
    }
    
    // Get node status based on lastHeard
    function getNodeStatus(node) {
      if (!node.lastHeard) return 'offline';
      const now = Math.floor(Date.now() / 1000);
      const age = now - node.lastHeard;
      if (age < 3600) return 'online';
      if (age < 86400) return 'idle';
      return 'offline';
    }
    
    // Apply filters and re-render markers
    function applyFilters() {
      const showOnline = document.getElementById('filterOnline').checked;
      const showIdle = document.getElementById('filterIdle').checked;
      const showOffline = document.getElementById('filterOffline').checked;
      const showRouter = document.getElementById('filterRouter').checked;
      const showClient = document.getElementById('filterClient').checked;
      const showTracker = document.getElementById('filterTracker').checked;
      
      filteredNodes = {};
      
      for (const [nodeNum, node] of Object.entries(allNodes)) {
        const status = getNodeStatus(node);
        const role = (node.role || 'CLIENT').toUpperCase();
        
        // Status filter
        if (status === 'online' && !showOnline) continue;
        if (status === 'idle' && !showIdle) continue;
        if (status === 'offline' && !showOffline) continue;
        
        // Role filter
        const isRouter = role.includes('ROUTER') || role.includes('REPEATER');
        const isTracker = role.includes('TRACKER');
        const isClient = !isRouter && !isTracker;
        
        if (isRouter && !showRouter) continue;
        if (isTracker && !showTracker) continue;
        if (isClient && !showClient) continue;
        
        filteredNodes[nodeNum] = node;
      }
      
      renderMarkers();
    }
    
    // Render markers on map
    function renderMarkers() {
      markers.clearLayers();
      
      for (const [nodeNum, node] of Object.entries(filteredNodes)) {
        // Convert position
        const lat = node.latitude / 10000000;
        const lng = node.longitude / 10000000;
        
        if (lat === 0 && lng === 0) continue;
        
        const status = getNodeStatus(node);
        const isSelected = parseInt(nodeNum) === selectedNodeNum;
        
        const marker = L.marker([lat, lng], {
          icon: L.divIcon({
            className: 'node-marker ' + status + (isSelected ? ' selected' : ''),
            iconSize: [isSelected ? 18 : 12, isSelected ? 18 : 12]
          })
        });
        
        marker.nodeNum = parseInt(nodeNum);
        marker.on('click', () => selectNode(parseInt(nodeNum)));
        
        markers.addLayer(marker);
      }
    }
    
    // Select a node
    function selectNode(nodeNum) {
      selectedNodeNum = nodeNum;
      const node = allNodes[nodeNum];
      if (!node) return;
      
      // Update panel
      const status = getNodeStatus(node);
      document.getElementById('nodeAvatar').textContent = node.shortName || '??';
      document.getElementById('nodeName').textContent = node.longName || 'Unknown';
      document.getElementById('nodeId').textContent = '!' + nodeNum.toString(16).padStart(8, '0');
      
      const statusEl = document.getElementById('nodeStatus');
      statusEl.className = 'node-status ' + status;
      statusEl.querySelector('span').textContent = status.toUpperCase();
      
      // Build content
      let content = '';
      
      // Device section
      content += '<div class="node-section">';
      content += '<div class="node-section-title"><svg viewBox="0 0 24 24"><path d="M15.5 1h-8C6.12 1 5 2.12 5 3.5v17C5 21.88 6.12 23 7.5 23h8c1.38 0 2.5-1.12 2.5-2.5v-17C18 2.12 16.88 1 15.5 1zm-4 21c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zm4.5-4H7V4h9v14z"/></svg>Device Info</div>';
      content += '<div class="node-info-grid">';
      content += '<div class="node-info-item"><div class="node-info-label">Hardware</div><div class="node-info-value">' + formatHardware(node.hwModel) + '</div></div>';
      content += '<div class="node-info-item"><div class="node-info-label">Role</div><div class="node-info-value">' + formatRole(node.role) + '</div></div>';
      if (node.fwVersion) content += '<div class="node-info-item"><div class="node-info-label">Firmware</div><div class="node-info-value">v' + node.fwVersion + '</div></div>';
      if (node.region) content += '<div class="node-info-item"><div class="node-info-label">Region</div><div class="node-info-value">' + node.region + '</div></div>';
      if (node.modemPreset) content += '<div class="node-info-item"><div class="node-info-label">Modem</div><div class="node-info-value">' + formatModem(node.modemPreset) + '</div></div>';
      content += '</div></div>';
      
      // Metrics section
      if (node.batteryLevel !== undefined || node.voltage || node.chUtil || node.airUtilTx || node.temperature || node.relativeHumidity) {
        content += '<div class="node-section">';
        content += '<div class="node-section-title"><svg viewBox="0 0 24 24"><path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z"/></svg>Telemetry</div>';
        content += '<div class="node-metrics">';
        if (node.batteryLevel !== undefined && node.batteryLevel !== null) {
          const battClass = node.batteryLevel < 20 ? 'critical' : node.batteryLevel < 40 ? 'low' : '';
          content += '<div class="metric-chip battery ' + battClass + '"><svg viewBox="0 0 24 24"><path d="M15.67 4H14V2h-4v2H8.33C7.6 4 7 4.6 7 5.33v15.33C7 21.4 7.6 22 8.33 22h7.33c.74 0 1.34-.6 1.34-1.33V5.33C17 4.6 16.4 4 15.67 4z"/></svg>' + node.batteryLevel + '%</div>';
        }
        if (node.voltage) content += '<div class="metric-chip voltage"><svg viewBox="0 0 24 24"><path d="M11 21h-1l1-7H7.5c-.88 0-.33-.75-.31-.78C8.48 10.94 10.42 7.54 13.01 3h1l-1 7h3.51c.4 0 .62.19.4.66C12.97 17.55 11 21 11 21z"/></svg>' + node.voltage.toFixed(2) + 'V</div>';
        if (node.chUtil) content += '<div class="metric-chip channel"><svg viewBox="0 0 24 24"><path d="M3.5 18.49l6-6.01 4 4L22 6.92l-1.41-1.41-7.09 7.97-4-4L2 16.99z"/></svg>' + node.chUtil.toFixed(1) + '% ch</div>';
        if (node.airUtilTx) content += '<div class="metric-chip airtx"><svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"/></svg>' + node.airUtilTx.toFixed(1) + '% tx</div>';
        if (node.temperature) content += '<div class="metric-chip temp"><svg viewBox="0 0 24 24"><path d="M15 13V5c0-1.66-1.34-3-3-3S9 3.34 9 5v8c-1.21.91-2 2.37-2 4 0 2.76 2.24 5 5 5s5-2.24 5-5c0-1.63-.79-3.09-2-4zm-4-8c0-.55.45-1 1-1s1 .45 1 1h-1v1h1v2h-1v1h1v2h-2V5z"/></svg>' + node.temperature.toFixed(1) + '°C</div>';
        if (node.relativeHumidity) content += '<div class="metric-chip humidity"><svg viewBox="0 0 24 24"><path d="M12 2c-5.33 4.55-8 8.48-8 11.8 0 4.98 3.8 8.2 8 8.2s8-3.22 8-8.2c0-3.32-2.67-7.25-8-11.8zm0 18c-3.35 0-6-2.57-6-6.2 0-2.34 1.95-5.44 6-9.14 4.05 3.7 6 6.79 6 9.14 0 3.63-2.65 6.2-6 6.2z"/></svg>' + node.relativeHumidity.toFixed(0) + '%</div>';
        if (node.barometricPressure) content += '<div class="metric-chip pressure"><svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v6h-2zm0 8h2v2h-2z"/></svg>' + node.barometricPressure.toFixed(0) + ' hPa</div>';
        content += '</div></div>';
      }
      
      // Position section
      const lat = node.latitude / 10000000;
      const lng = node.longitude / 10000000;
      content += '<div class="node-section">';
      content += '<div class="node-section-title"><svg viewBox="0 0 24 24"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/></svg>Location</div>';
      content += '<div class="node-info-grid">';
      content += '<div class="node-info-item"><div class="node-info-label">Latitude</div><div class="node-info-value">' + lat.toFixed(6) + '°</div></div>';
      content += '<div class="node-info-item"><div class="node-info-label">Longitude</div><div class="node-info-value">' + lng.toFixed(6) + '°</div></div>';
      if (node.altitude) content += '<div class="node-info-item"><div class="node-info-label">Altitude</div><div class="node-info-value">' + node.altitude + ' m</div></div>';
      content += '</div></div>';
      
      // Seen by section
      if (node.seenBy && Object.keys(node.seenBy).length > 0) {
        const regions = [...new Set(Object.keys(node.seenBy).map(topic => {
          const parts = topic.split('/');
          return parts[1] || 'unknown';
        }))];
        content += '<div class="node-section">';
        content += '<div class="node-section-title"><svg viewBox="0 0 24 24"><path d="M1 9l2 2c4.97-4.97 13.03-4.97 18 0l2-2C16.93 2.93 7.08 2.93 1 9zm8 8l3 3 3-3c-1.65-1.66-4.34-1.66-6 0zm-4-4l2 2c2.76-2.76 7.24-2.76 10 0l2-2C15.14 9.14 8.87 9.14 5 13z"/></svg>Seen In Regions</div>';
        content += '<div class="node-metrics">' + regions.map(r => '<div class="metric-chip channel">' + r + '</div>').join('') + '</div>';
        content += '</div>';
      }
      
      // Last seen footer
      if (node.lastSeen) {
        const lastSeen = new Date(node.lastSeen);
        const now = new Date();
        const diff = Math.floor((now - lastSeen) / 1000);
        let timeAgo;
        if (diff < 60) timeAgo = diff + 's ago';
        else if (diff < 3600) timeAgo = Math.floor(diff / 60) + 'm ago';
        else if (diff < 86400) timeAgo = Math.floor(diff / 3600) + 'h ago';
        else timeAgo = Math.floor(diff / 86400) + 'd ago';
        
        content += '<div class="node-last-seen"><svg viewBox="0 0 24 24"><path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z"/></svg>Last seen ' + timeAgo + '</div>';
      }
      
      document.getElementById('nodePanelContent').innerHTML = content;
      document.getElementById('nodePanel').classList.add('visible');
      
      // Re-render to show selection
      renderMarkers();
      
      // Center map on node
      const lat2 = node.latitude / 10000000;
      const lng2 = node.longitude / 10000000;
      map.setView([lat2, lng2], Math.max(map.getZoom(), 10));
    }
    
    // Format hardware model
    function formatHardware(model) {
      if (!model || model === 'UNKNOWN') return 'Unknown';
      return model.replace(/_/g, ' ').replace(/TBEAM/g, 'T-Beam').replace(/TLORA/g, 'T-LoRa').replace(/HELTEC/g, 'Heltec').replace(/RAK/g, 'RAK');
    }
    
    // Format role
    function formatRole(role) {
      if (!role || role === 'UNKNOWN') return 'Unknown';
      return role.charAt(0) + role.slice(1).toLowerCase().replace(/_/g, ' ');
    }
    
    // Format modem preset
    function formatModem(preset) {
      if (!preset) return 'Unknown';
      return preset.replace(/LONG_/g, 'Long ').replace(/SHORT_/g, 'Short ').replace(/MEDIUM_/g, 'Med ').replace(/_/g, ' ');
    }
    
    // Close node panel
    function closeNodePanel() {
      document.getElementById('nodePanel').classList.remove('visible');
      selectedNodeNum = null;
      renderMarkers();
    }
    
    // Search functionality
    const searchInput = document.getElementById('searchInput');
    const searchResults = document.getElementById('searchResults');
    const searchClear = document.getElementById('searchClear');
    
    searchInput.addEventListener('input', (e) => {
      const query = e.target.value.toLowerCase().trim();
      searchClear.classList.toggle('visible', query.length > 0);
      
      if (query.length < 2) {
        searchResults.classList.remove('visible');
        return;
      }
      
      const results = Object.entries(allNodes)
        .filter(([nodeNum, node]) => {
          const name = (node.longName || '').toLowerCase();
          const shortName = (node.shortName || '').toLowerCase();
          const hexId = nodeNum.toString(16).toLowerCase();
          return name.includes(query) || shortName.includes(query) || hexId.includes(query);
        })
        .slice(0, 20);
      
      if (results.length === 0) {
        searchResults.innerHTML = '<div class="search-result-item"><div class="search-result-name">No nodes found</div></div>';
      } else {
        searchResults.innerHTML = results.map(([nodeNum, node]) => {
          const status = getNodeStatus(node);
          return '<div class="search-result-item" onclick="selectNode(' + nodeNum + '); clearSearch();">' +
            '<div class="search-result-name">' + (node.longName || 'Unknown') + ' (' + (node.shortName || '??') + ')</div>' +
            '<div class="search-result-meta"><span>!' + parseInt(nodeNum).toString(16).padStart(8, '0') + '</span><span>' + formatHardware(node.hwModel) + '</span><span>' + status + '</span></div>' +
            '</div>';
        }).join('');
      }
      
      searchResults.classList.add('visible');
    });
    
    function clearSearch() {
      searchInput.value = '';
      searchResults.classList.remove('visible');
      searchClear.classList.remove('visible');
    }
    
    // Close search results when clicking outside
    document.addEventListener('click', (e) => {
      if (!e.target.closest('.search-container')) {
        searchResults.classList.remove('visible');
      }
      if (!e.target.closest('.filter-panel')) {
        document.getElementById('filterDropdown').classList.remove('visible');
      }
      if (!e.target.closest('.map-controls')) {
        document.getElementById('styleMenu').classList.remove('visible');
      }
    });
    
    // Toggle filter dropdown
    function toggleFilter() {
      document.getElementById('filterDropdown').classList.toggle('visible');
    }
    
    // Toggle style menu
    function toggleStyleMenu() {
      document.getElementById('styleMenu').classList.toggle('visible');
    }
    
    // Set map style
    function setMapStyle(style) {
      if (currentStyle === style) return;
      
      map.removeLayer(currentTileLayer);
      currentTileLayer = tileLayers[style];
      currentTileLayer.addTo(map);
      currentStyle = style;
      
      // Update active state
      document.querySelectorAll('.style-option').forEach(el => el.classList.remove('active'));
      document.querySelector('.style-option[onclick="setMapStyle(\\'' + style + '\\')"]').classList.add('active');
      
      document.getElementById('styleMenu').classList.remove('visible');
    }
    
    // Map controls
    function zoomIn() {
      map.zoomIn();
    }
    
    function zoomOut() {
      map.zoomOut();
    }
    
    function fitAllNodes() {
      if (Object.keys(filteredNodes).length === 0) return;
      
      const lats = [];
      const lngs = [];
      
      for (const node of Object.values(filteredNodes)) {
        const lat = node.latitude / 10000000;
        const lng = node.longitude / 10000000;
        if (lat !== 0 || lng !== 0) {
          lats.push(lat);
          lngs.push(lng);
        }
      }
      
      if (lats.length > 0) {
        map.fitBounds([
          [Math.min(...lats), Math.min(...lngs)],
          [Math.max(...lats), Math.max(...lngs)]
        ], { padding: [50, 50] });
      }
    }
    
    // Auto-refresh every 60 seconds
    setInterval(loadNodes, 60 * 1000);
    
    // Initialize
    initMap();
  </script>
</body>
</html>`;
}
