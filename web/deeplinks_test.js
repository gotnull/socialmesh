/**
 * Deep Link Test Console
 * Generates QR codes for testing deep links on real devices.
 * 
 * QR Code generation is implemented inline using a minimal alphanumeric-mode
 * encoder sufficient for URL patterns. No external dependencies required.
 */

// State
let testCases = [];
let activeFilter = 'all';
let searchQuery = '';

// DOM Elements
const grid = document.getElementById('testCasesGrid');
const loadingState = document.getElementById('loadingState');
const errorState = document.getElementById('errorState');
const searchInput = document.getElementById('searchInput');
const visibleCountEl = document.getElementById('visibleCount');
const totalCountEl = document.getElementById('totalCount');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  loadTestCases();
  setupEventListeners();
  setupRevealAnimations();
});

/**
 * Load test cases from JSON file
 */
async function loadTestCases() {
  loadingState.classList.remove('hidden');
  errorState.classList.add('hidden');
  grid.innerHTML = '';

  try {
    const response = await fetch('deeplink_cases.json');
    if (!response.ok) throw new Error('Failed to load');
    
    const data = await response.json();
    testCases = data.testCases || [];
    totalCountEl.textContent = testCases.length;
    
    renderTestCases();
    loadingState.classList.add('hidden');
  } catch (error) {
    console.error('Failed to load test cases:', error);
    loadingState.classList.add('hidden');
    errorState.classList.remove('hidden');
  }
}

/**
 * Setup event listeners
 */
function setupEventListeners() {
  // Search input
  searchInput.addEventListener('input', (e) => {
    searchQuery = e.target.value.toLowerCase();
    filterTestCases();
  });

  // Filter buttons
  document.querySelectorAll('.filter-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      activeFilter = btn.dataset.filter;
      filterTestCases();
    });
  });
}

/**
 * Render all test cases
 */
function renderTestCases() {
  grid.innerHTML = '';
  
  testCases.forEach((tc, index) => {
    const card = createTestCard(tc, index);
    grid.appendChild(card);
  });

  filterTestCases();
  
  // Generate QR codes after cards are in DOM
  setTimeout(() => {
    testCases.forEach((tc, index) => {
      if (tc.deepLink) {
        generateQRCode(`qr-${index}`, tc.deepLink);
      }
    });
  }, 100);
}

/**
 * Create a test case card element
 */
function createTestCard(tc, index) {
  const card = document.createElement('div');
  card.className = 'test-card reveal';
  card.dataset.category = tc.category;
  card.dataset.type = tc.type;
  card.dataset.searchable = `${tc.title} ${tc.deepLink} ${tc.expectedLocation?.route || ''} ${tc.notes || ''}`.toLowerCase();

  const isValid = validateDeepLink(tc.deepLink);
  
  // Format args - truncate long values for display
  const argsStr = tc.expectedLocation?.args 
    ? Object.entries(tc.expectedLocation.args)
        .filter(([_, v]) => v !== null)
        .map(([k, v]) => {
          const valStr = JSON.stringify(v);
          // Truncate values longer than 40 chars
          const displayVal = valStr.length > 40 ? valStr.substring(0, 37) + '...' : valStr;
          return `${k}: ${displayVal}`;
        })
        .join('\n')
    : '';

  card.innerHTML = `
    <div class="card-header">
      <h3 class="card-title">${escapeHtml(tc.title)}</h3>
      <div class="card-badges">
        <span class="badge badge-${tc.type}">${tc.type}</span>
        ${tc.requiresDevice ? '<span class="badge badge-device">Device</span>' : ''}
      </div>
    </div>

    <div class="qr-container">
      <div id="qr-${index}" class="qr-code-wrapper"></div>
    </div>

    <div class="deeplink-display">
      <div class="deeplink-label">Deep Link</div>
      <div class="deeplink-value">${escapeHtml(tc.deepLink || '(empty)')}</div>
      <button class="copy-btn" onclick="copyToClipboard('${escapeAttr(tc.deepLink)}', this)" title="Copy to clipboard">
        <span class="material-icons">content_copy</span>
      </button>
    </div>

    <div class="expected-location">
      <div class="expected-label">Expected Destination</div>
      <div class="expected-route">${escapeHtml(tc.expectedLocation?.route || '/main')}</div>
      ${argsStr ? `<div class="expected-args">${escapeHtml(argsStr)}</div>` : ''}
    </div>

    <div class="card-notes">${escapeHtml(tc.notes || '')}</div>

    <div class="card-actions">
      <div class="validation-status ${isValid ? 'valid' : 'invalid'}">
        <span class="material-icons">${isValid ? 'check_circle' : 'error'}</span>
        ${isValid ? 'Valid URI' : 'Invalid URI'}
      </div>
      ${tc.deepLink ? `
        <a href="${escapeAttr(tc.deepLink)}" class="btn btn-secondary" target="_blank">
          <span class="material-icons btn-icon">open_in_new</span>
          Open
        </a>
      ` : ''}
    </div>
  `;

  // Trigger reveal animation
  setTimeout(() => card.classList.add('active'), index * 50);

  return card;
}

/**
 * Filter test cases based on search and category
 */
function filterTestCases() {
  let visibleCount = 0;

  document.querySelectorAll('.test-card').forEach(card => {
    const matchesFilter = activeFilter === 'all' || card.dataset.category === activeFilter;
    const matchesSearch = !searchQuery || card.dataset.searchable.includes(searchQuery);
    const isVisible = matchesFilter && matchesSearch;

    card.classList.toggle('hidden', !isVisible);
    if (isVisible) visibleCount++;
  });

  visibleCountEl.textContent = visibleCount;
}

/**
 * Validate a deep link URI
 */
function validateDeepLink(uri) {
  if (!uri || uri.trim() === '') return false;
  
  try {
    // Check for malformed URI
    new URL(uri);
    return true;
  } catch {
    // For custom schemes, URL() fails but URI may still be valid
    // Check for basic structure: scheme://something
    return /^[a-z][a-z0-9+.-]*:\/\/.*/i.test(uri);
  }
}

/**
 * Copy text to clipboard
 */
async function copyToClipboard(text, button) {
  try {
    await navigator.clipboard.writeText(text);
    showToast('Copied to clipboard!');
    
    // Visual feedback
    const icon = button.querySelector('.material-icons');
    icon.textContent = 'check';
    setTimeout(() => { icon.textContent = 'content_copy'; }, 1500);
  } catch (err) {
    showToast('Failed to copy');
  }
}

/**
 * Show toast notification
 */
function showToast(message) {
  let toast = document.querySelector('.toast');
  if (!toast) {
    toast = document.createElement('div');
    toast.className = 'toast';
    document.body.appendChild(toast);
  }
  
  toast.textContent = message;
  toast.classList.add('show');
  
  setTimeout(() => {
    toast.classList.remove('show');
  }, 2000);
}

/**
 * Escape HTML special characters
 */
function escapeHtml(str) {
  if (!str) return '';
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/**
 * Escape for use in HTML attributes
 */
function escapeAttr(str) {
  if (!str) return '';
  return str
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/**
 * Setup reveal animations (reuse from landing page)
 */
function setupRevealAnimations() {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('active');
      }
    });
  }, { threshold: 0.1 });

  document.querySelectorAll('.reveal, .reveal-blur').forEach(el => {
    observer.observe(el);
  });
}

// =============================================================================
// QR Code Generator (using qrcode.js library)
// =============================================================================

/**
 * Generate a QR code in a container element using qrcode.js
 */
function generateQRCode(containerId, text) {
  const container = document.getElementById(containerId);
  if (!container || !text) return;

  // Clear any existing content
  container.innerHTML = '';

  try {
    // Create QR code using qrcode.js library (loaded from CDN)
    new QRCode(container, {
      text: text,
      width: 140,
      height: 140,
      colorDark: '#000000',
      colorLight: '#ffffff',
      correctLevel: QRCode.CorrectLevel.M
    });
  } catch (e) {
    console.error('QR generation error for:', text, e);
    container.innerHTML = '<div style="color: #EF4444; font-size: 12px; text-align: center; padding: 20px;">QR Error</div>';
  }
}

