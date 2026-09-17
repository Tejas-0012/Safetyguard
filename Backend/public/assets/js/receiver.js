// ============================================
// SafeGuard - Receiver Web Page (FIXED)
// ============================================

const token = window.location.pathname.split('/').pop();

let emergency = null;
let map = null;
let marker = null;
let updateInterval = null;
let isFetching = false;  // ✅ Prevent overlapping requests

// DOM Elements
const loading = document.getElementById('loading');
const content = document.getElementById('content');

// ============================================
// Fetch Emergency Data (Safe)
// ============================================

async function fetchEmergencyData() {
    // ✅ Prevent overlapping fetches
    if (isFetching) return;
    isFetching = true;

    try {
        const response = await fetch(`/api/emergency/web/${token}`);
        const data = await response.json();

        if (!data.success) {
            showError(data.message || 'Failed to load emergency data');
            return;
        }

        emergency = data.emergency;
        renderUI();

    } catch (error) {
        console.error('Error fetching:', error);
        // Don't spam — wait for next interval
    } finally {
        isFetching = false;
    }
}

// ============================================
// Render UI (Safe — No Duplicate Map)
// ============================================

function renderUI() {
    if (!emergency) return;

    loading.style.display = 'none';
    content.style.display = 'block';

    // Sender info
    document.getElementById('senderName').textContent = emergency.userName || 'Unknown';
    document.getElementById('senderPhone').textContent = '📱 ' + (emergency.userPhone || 'No phone');
    document.getElementById('avatar').textContent = (emergency.userName || 'U')[0].toUpperCase();

    // Stats
    document.getElementById('updateCount').textContent = emergency.locationPoints?.length || 0;
    document.getElementById('imageCount').textContent = emergency.cameraImages?.length || 0;

    // ✅ Map — Only initialize ONCE
    updateMap();

    // Images
    updateImages();

    // Replies
    updateReplies();

    // Status
    const statusValue = document.getElementById('statusValue');
    const statusBadge = document.getElementById('statusBadge');
    if (emergency.status === 'active') {
        statusValue.textContent = '🔴 Active';
        statusValue.style.color = '#ff1744';
        statusBadge.textContent = '● ACTIVE';
    } else {
        statusValue.textContent = '✅ Resolved';
        statusValue.style.color = '#00c853';
        statusBadge.textContent = '● RESOLVED';
    }
}

// ============================================
// Map (Initialize Once)
// ============================================

function updateMap() {
    if (!emergency.currentLocation) return;

    const loc = emergency.currentLocation;
    const pos = { lat: loc.latitude, lng: loc.longitude };

    // ✅ Initialize map only once
    if (!map) {
        map = new google.maps.Map(document.getElementById('map'), {
            zoom: 15,
            center: pos,
            mapTypeId: google.maps.MapTypeId.roadmap,
            styles: [
                { featureType: 'poi', elementType: 'labels', stylers: [{ visibility: 'off' }] }
            ]
        });

        marker = new google.maps.Marker({
            position: pos,
            map: map,
            title: 'Sender Location',
            icon: {
                path: google.maps.SymbolPath.CIRCLE,
                fillColor: '#ff1744',
                fillOpacity: 1,
                strokeColor: '#ffffff',
                strokeWeight: 3,
                scale: 10,
            }
        });

        // Draw path once
        if (emergency.locationPoints && emergency.locationPoints.length > 1) {
            const path = emergency.locationPoints.map(p => ({
                lat: p.latitude,
                lng: p.longitude
            }));
            new google.maps.Polyline({
                path: path,
                strokeColor: '#ff1744',
                strokeOpacity: 0.8,
                strokeWeight: 3,
                map: map,
            });
        }
    } else {
        // ✅ Just update marker position
        marker.setPosition(pos);
        map.panTo(pos);
    }
}

// ============================================
// Images (Only Update If Changed)
// ============================================

let lastImageCount = 0;

function updateImages() {
    const imgs = emergency.cameraImages || [];
    const imageCount = imgs.length;

    if (imageCount === lastImageCount) return;
    lastImageCount = imageCount;

    const container = document.getElementById('imagesContainer');
    const grid = document.getElementById('imageGrid');

    if (imageCount > 0) {
        container.style.display = 'block';
        grid.innerHTML = imgs.map(img => `<img src="${img.url}" />`).join('');
    } else {
        container.style.display = 'none';
    }
}

// ============================================
// Replies (Only Update If Changed)
// ============================================

let lastReplyCount = 0;

function updateReplies() {
    const replies = emergency.receiverReplies || [];
    const replyCount = replies.length;

    if (replyCount === lastReplyCount) return;
    lastReplyCount = replyCount;

    const list = document.getElementById('repliesList');
    list.innerHTML = replies.map(r => `
        <div class="reply-item">
            <span><b>${r.contactName || 'Viewer'}:</b> ${r.message}</span>
            <span class="time">${formatTime(new Date(r.repliedAt))}</span>
        </div>
    `).join('');
}

// ============================================
// Send Reply
// ============================================

document.getElementById('sendReplyBtn').addEventListener('click', sendReply);

document.getElementById('replyInput').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') sendReply();
});

async function sendReply() {
    const input = document.getElementById('replyInput');
    const message = input.value.trim();
    if (!message) return;

    try {
        const response = await fetch(`/api/emergency/web/${token}/reply`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ message, viewerName: 'Web Viewer' })
        });

        const data = await response.json();

        if (data.success) {
            input.value = '';
            // ✅ Immediately refresh to show new reply
            await fetchEmergencyData();
        } else {
            alert('Failed: ' + (data.message || 'Unknown error'));
        }
    } catch (e) {
        console.error('Reply error:', e);
        alert('Failed to send reply');
    }
}

// ============================================
// Helpers
// ============================================

function formatTime(date) {
    return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

function showError(message) {
    loading.innerHTML = `
        <div style="text-align:center;padding:20px;">
            <div style="font-size:48px;">❌</div>
            <p>${message}</p>
            <button onclick="location.reload()" style="margin-top:16px;padding:10px 24px;background:#1a237e;color:white;border:none;border-radius:8px;cursor:pointer;">
                Try Again
            </button>
        </div>
    `;
}

// ============================================
// Start
// ============================================

if (!token || token === 'receiver.html') {
    showError('Invalid link. Please use the link from the SMS.');
} else {
    fetchEmergencyData();
    // ✅ Poll every 8 seconds (slower = less browser load)
    updateInterval = setInterval(fetchEmergencyData, 8000);
}

// ✅ Stop polling when page closes
window.addEventListener('beforeunload', () => {
    if (updateInterval) clearInterval(updateInterval);
});