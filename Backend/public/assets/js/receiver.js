// ============================================
// SafeGuard - Receiver Web Page (PHASE 2)
// ============================================

const token = window.location.pathname.split('/').pop();

let emergency = null;
let receiver = null;
let map = null;
let marker = null;
let otherMarkers = {};
let updateInterval = null;
let isFetching = false;
let isSharingLocation = false;
let locationWatchId = null;

// DOM Elements
const loading = document.getElementById('loading');
const content = document.getElementById('content');

// ============================================
// Emergency Call Buttons
// ============================================

const EMERGENCY_NUMBERS = [
    { label: 'Police', number: '100', icon: '🚓', color: '#1E88E5' },
    { label: 'Ambulance', number: '108', icon: '🚑', color: '#43A047' },
    { label: 'Fire', number: '101', icon: '🔥', color: '#F57C00' },
    { label: 'All Emergency', number: '112', icon: '🆘', color: '#E53935' },
    { label: 'Women Helpline', number: '1091', icon: '👩', color: '#8E24AA' },
    { label: 'Domestic Abuse', number: '181', icon: '🛡️', color: '#D81B60' },
];

function renderEmergencyButtons() {
    const container = document.getElementById('emergencyButtons');
    if (!container) return;

    container.innerHTML = EMERGENCY_NUMBERS.map((e) => `
        <a href="tel:${e.number}" style="
            display:flex;
            flex-direction:column;
            align-items:center;
            justify-content:center;
            padding:12px 6px;
            background:${e.color}1a;
            border:1.5px solid ${e.color}4d;
            border-radius:12px;
            text-decoration:none;
            color:${e.color};
            font-weight:600;
            transition:transform 0.15s;
        " onmouseover="this.style.transform='scale(1.05)'" onmouseout="this.style.transform='scale(1)'">
            <span style="font-size:22px;margin-bottom:4px;">${e.icon}</span>
            <span style="font-size:10px;text-align:center;line-height:1.2;">${e.label}</span>
            <span style="font-size:13px;font-weight:800;margin-top:2px;">${e.number}</span>
        </a>
    `).join('');
}

// Call it when page loads
renderEmergencyButtons();

// ============================================
// Fetch Emergency Data (NEW ENDPOINT)
// ============================================

async function fetchEmergencyData() {
    if (isFetching) return;
    isFetching = true;

    try {
        // ✅ NEW ENDPOINT
        const response = await fetch(`/api/emergency/receiver/${token}`);
        const data = await response.json();

        if (!data.success) {
            showError(data.message || 'Failed to load emergency data');
            return;
        }

        emergency = data.emergency;
        receiver = data.receiver;
        renderUI();

    } catch (error) {
        console.error('Error fetching:', error);
    } finally {
        isFetching = false;
    }
}

// ============================================
// Render UI
// ============================================

function renderUI() {
    if (!emergency) return;

    loading.style.display = 'none';
    content.style.display = 'block';

    // ✅ Personalized greeting from receiver info
    const greeting = document.getElementById('greeting');
    if (greeting && receiver) {
        greeting.textContent = `Hi ${receiver.contactName}, ${emergency.userName} needs your help.`;
    }

    // Sender info
    const senderName = document.getElementById('senderName');
    if (senderName) senderName.textContent = emergency.userName || 'Unknown';

    const senderPhone = document.getElementById('senderPhone');
    if (senderPhone) senderPhone.textContent = '📱 ' + (emergency.userPhone || 'No phone');

    const avatar = document.getElementById('avatar');
    if (avatar) avatar.textContent = (emergency.userName || 'U')[0].toUpperCase();

    // Stats
    const updateCount = document.getElementById('updateCount');
    if (updateCount) updateCount.textContent = emergency.locationPoints?.length || 0;

    const imageCount = document.getElementById('imageCount');
    if (imageCount) imageCount.textContent = emergency.cameraImages?.length || 0;

    // Map
    updateMap();

    // Images
    updateImages();
        // Audio
updateAudio();

    // Replies
    updateReplies();


    // Status
    const statusValue = document.getElementById('statusValue');
    const statusBadge = document.getElementById('statusBadge');
    if (emergency.status === 'active') {
        if (statusValue) {
            statusValue.textContent = '🔴 Active';
            statusValue.style.color = '#ff1744';
        }
        if (statusBadge) statusBadge.textContent = '● ACTIVE';
    } else {
        if (statusValue) {
            statusValue.textContent = '✅ Resolved';
            statusValue.style.color = '#00c853';
        }
        if (statusBadge) statusBadge.textContent = '● RESOLVED';
    }
}

// ============================================
// Map
// ============================================

function updateMap() {
    if (!emergency.currentLocation) return;

    const loc = emergency.currentLocation;
    const pos = { lat: loc.latitude, lng: loc.longitude };

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
    } else {
        marker.setPosition(pos);
        map.panTo(pos);
    }

    // ✅ Show other receivers on the map (Phase 3 preview)
    if (emergency.otherReceivers && Array.isArray(emergency.otherReceivers)) {
        emergency.otherReceivers.forEach((other) => {
            if (!other.location || other.location.latitude == null) return;
            const otherPos = { lat: other.location.latitude, lng: other.location.longitude };

            if (otherMarkers[other.contactName]) {
                otherMarkers[other.contactName].setPosition(otherPos);
            } else {
                otherMarkers[other.contactName] = new google.maps.Marker({
                    position: otherPos,
                    map: map,
                    title: other.contactName,
                    icon: {
                        path: google.maps.SymbolPath.CIRCLE,
                        fillColor: '#2196F3',
                        fillOpacity: 0.9,
                        strokeColor: '#ffffff',
                        strokeWeight: 2,
                        scale: 8,
                    }
                });
            }
        });
    }
}

// ============================================
// Audio Recordings
// ============================================

let lastAudioCount = 0;

function updateAudio() {
    const audios = emergency.audioRecordings || [];
    const audioCount = audios.length;

    if (audioCount === lastAudioCount) return;
    lastAudioCount = audioCount;

    const container = document.getElementById('audioContainer');
    const list = document.getElementById('audioList');

    if (audioCount > 0 && container && list) {
        container.style.display = 'block';
        list.innerHTML = audios.map((audio, index) => `
            <div class="audio-chunk">
                <div class="audio-chunk-header">
                    <span>🎵 Chunk ${audio.chunkIndex ?? index + 1}</span>
                    <span>${audio.durationSeconds ?? 30}s</span>
                </div>
                <audio controls preload="none">
                    <source src="${audio.url}" type="audio/mp4">
                    Your browser does not support audio playback.
                </audio>
            </div>
        `).join('');
    }
}

// ============================================
// Location Sharing (Phase 3 preview)
// ============================================

async function startSharingLocation() {
    if (!navigator.geolocation) {
        alert('Geolocation is not supported by your browser');
        return;
    }

    isSharingLocation = true;

    // Update UI
    const btn = document.getElementById('shareLocationBtn');
    if (btn) {
        btn.textContent = '🛑 Stop Sharing';
        btn.style.background = '#e53935';
    }

    // Watch position and send to backend
    locationWatchId = navigator.geolocation.watchPosition(
        async (position) => {
            try {
                await fetch(`/api/emergency/receiver/${token}/location`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        latitude: position.coords.latitude,
                        longitude: position.coords.longitude,
                        accuracy: position.coords.accuracy,
                    }),
                });
                console.log('📍 Location shared:', position.coords.latitude, position.coords.longitude);
            } catch (e) {
                console.error('Failed to send location:', e);
            }
        },
        (error) => console.error('Geolocation error:', error),
        { enableHighAccuracy: true, maximumAge: 5000, timeout: 30000 }
    );
}

async function stopSharingLocation() {
    isSharingLocation = false;

    if (locationWatchId !== null) {
        navigator.geolocation.clearWatch(locationWatchId);
        locationWatchId = null;
    }

    try {
        await fetch(`/api/emergency/receiver/${token}/stop-sharing`, {
            method: 'POST',
        });
    } catch (e) {
        console.error('Failed to stop sharing:', e);
    }

    const btn = document.getElementById('shareLocationBtn');
    if (btn) {
        btn.textContent = '📍 Share My Location';
        btn.style.background = '#00897b';
    }
}

// ============================================
// Images
// ============================================

let lastImageCount = 0;

function updateImages() {
    const imgs = emergency.cameraImages || [];
    const imageCount = imgs.length;

    if (imageCount === lastImageCount) return;
    lastImageCount = imageCount;

    const container = document.getElementById('imagesContainer');
    const grid = document.getElementById('imageGrid');

    if (imageCount > 0 && container && grid) {
        container.style.display = 'block';
        grid.innerHTML = imgs
            .slice()  // copy array
            .reverse()  // newest first
            .map((img) => {
                const label = img.camera === 'front' ? '🤳 Front' : '📷 Back';
                const time = img.capturedAt
                    ? new Date(img.capturedAt).toLocaleTimeString()
                    : '';
                return `
                    <div style="display:flex;flex-direction:column;gap:4px;">
                        <img src="${img.url}" style="width:100%;height:150px;object-fit:cover;border-radius:12px;border:1px solid #eee;">
                        <div style="font-size:11px;color:#666;text-align:center;">
                            ${label} • ${time}
                        </div>
                    </div>
                `;
            })
            .join('');
    }
}

// ============================================
// Replies
// ============================================

let lastReplyCount = 0;

function updateReplies() {
    const replies = emergency.receiverReplies || [];
    const replyCount = replies.length;

    if (replyCount === lastReplyCount) return;
    lastReplyCount = replyCount;

    const list = document.getElementById('repliesList');
    if (!list) return;

    list.innerHTML = replies.map(r => `
        <div class="reply-item">
            <span><b>${r.contactName || 'Viewer'}:</b> ${r.message}</span>
        </div>
    `).join('');
}

// ============================================
// Send Reply
// ============================================

async function sendReply() {
    const input = document.getElementById('replyInput');
    const message = input?.value.trim();
    if (!message) return;

    try {
        // ✅ Use the NEW /receiver/:token endpoint
        const response = await fetch(`/api/emergency/receiver/${token}/reply`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                message,
                viewerName: receiver?.contactName || 'Web Viewer'
            })
        });

        const data = await response.json();
        if (data.success) {
            input.value = '';
            await fetchEmergencyData();
        } else {
            alert('Failed: ' + (data.message || 'Unknown error'));
        }
    } catch (e) {
        console.error('Reply error:', e);
    }
}

// ============================================
// Helpers
// ============================================

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
    updateInterval = setInterval(fetchEmergencyData, 8000);
}

// Bind buttons
document.getElementById('sendReplyBtn')?.addEventListener('click', sendReply);
document.getElementById('replyInput')?.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') sendReply();
});
document.getElementById('shareLocationBtn')?.addEventListener('click', () => {
    if (isSharingLocation) {
        stopSharingLocation();
    } else {
        startSharingLocation();
    }
});

window.addEventListener('beforeunload', () => {
    if (updateInterval) clearInterval(updateInterval);
    if (locationWatchId) navigator.geolocation.clearWatch(locationWatchId);
});