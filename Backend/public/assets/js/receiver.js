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

// ✅ Format any date as IST time
function formatIST(dateString) {
    if (!dateString) return '';
    return new Date(dateString).toLocaleTimeString('en-IN', {
        timeZone: 'Asia/Kolkata',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: true,
    });
}

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
let isLiveKitConnected = false;
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
        if (!isLiveKitConnected && emergency && emergency.id && emergency.status === 'active') {
            isLiveKitConnected = true;
            connectLiveKitVideo(emergency.id);
        }
        renderUI();

        // If emergency is stopped, clear polling interval
        if (emergency && emergency.status !== 'active') {
            if (updateInterval) {
                clearInterval(updateInterval);
                updateInterval = null;
                console.log("🛑 Emergency is resolved/stopped. Polling paused.");
            }
        }

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

    const callVictimBtn = document.getElementById('callVictimBtn');
    if (callVictimBtn) {
        if (emergency.userPhone && emergency.userPhone.trim()) {
            callVictimBtn.href = `tel:${emergency.userPhone.trim()}`;
            callVictimBtn.style.display = 'inline-flex';
        } else {
            callVictimBtn.style.display = 'none';
        }
    }

    const avatar = document.getElementById('avatar');
    if (avatar) avatar.textContent = (emergency.userName || 'U')[0].toUpperCase();

    // Stats
    const updateCount = document.getElementById('updateCount');
    if (updateCount) updateCount.textContent = emergency.locationPoints?.length || 0;

    const mediaCount = document.getElementById('mediaCount');
    const totalMedia = (emergency.cameraImages?.length || 0) + 
                       (emergency.audioRecordings?.length || 0) + 
                       ((emergency.videoRecordings?.length || 0) || (recordedVideoUrl ? 1 : 0));
    if (mediaCount) mediaCount.textContent = totalMedia;

    // Map
    updateMap();

    // Images
    updateImages();
    // Audio
    updateAudio();
    // Recorded Video
    updateVideoUI();

    // Replies
    updateReplies();

    // Handle emergency conclusion (Stop live location & finalize recording)
    if (emergency.status !== 'active') {
        stopStreamRecording();
        if (isSharingLocation) {
            stopSharingLocation();
        }
        if (locationWatchId !== null) {
            navigator.geolocation.clearWatch(locationWatchId);
            locationWatchId = null;
        }
    }


    // Duration
    const startMs = new Date(emergency.startTime).getTime();
    const endMs = (emergency.status !== 'active' && emergency.endTime) 
        ? new Date(emergency.endTime).getTime() 
        : Date.now();
    const diffSec = Math.max(0, Math.floor((endMs - startMs) / 1000));
    const mins = Math.floor(diffSec / 60).toString().padStart(2, '0');
    const secs = (diffSec % 60).toString().padStart(2, '0');
    const durationValue = document.getElementById('durationValue');
    if (durationValue) durationValue.textContent = `${mins}:${secs}`;

    // Status & Banner
    const statusValue = document.getElementById('statusValue');
    const statusBadge = document.getElementById('statusBadge');
    const stoppedBanner = document.getElementById('stoppedBanner');
    const stoppedTitle = document.getElementById('stoppedBannerTitle');
    const stoppedSubtitle = document.getElementById('stoppedBannerSubtitle');
    const videoContainer = document.getElementById('videoContainer');

    const triggerLabels = {
        'button': '👆 App Button',
        'shake': '📳 Shake',
        'voice': '🎤 Voice',
        'tile': '⚙️ Quick Tile',
        'widget': '📱 Home Widget'
    };
    const triggerText = triggerLabels[emergency.triggerSource] || 'Manual';

    if (emergency.status === 'active') {
        if (stoppedBanner) stoppedBanner.style.display = 'none';
        if (statusValue) {
            statusValue.textContent = triggerText;
            statusValue.style.color = '#ff1744';
            statusValue.style.fontSize = '16px';
        }
        if (statusBadge) {
            statusBadge.textContent = '● ACTIVE';
            statusBadge.className = 'status active';
            statusBadge.style.background = '#e53935';
        }
    } else {
        const stopTimeStr = formatIST(emergency.endTime || emergency.updatedAt || Date.now());
        if (stoppedBanner) {
            stoppedBanner.style.display = 'block';
            if (stoppedTitle) stoppedTitle.textContent = `🛑 EMERGENCY STOPPED (${stopTimeStr})`;
            if (stoppedSubtitle) stoppedSubtitle.textContent = `Victim stopped the alert at ${stopTimeStr}. Map displays the final last known location. All recorded media & photos are preserved below.`;
        }
        if (statusValue) {
            statusValue.innerHTML = `<span style="color:#c62828; font-weight:800;">🛑 Stopped</span><br><span style="font-size:12px;color:#555;font-weight:600;">at ${stopTimeStr}</span>`;
            statusValue.style.fontSize = '15px';
        }
        if (statusBadge) {
            statusBadge.textContent = `🛑 STOPPED (${stopTimeStr})`;
            statusBadge.className = 'status resolved';
            statusBadge.style.background = '#455a64';
        }
        if (videoContainer) videoContainer.style.display = 'none';
    }
}

// ============================================
// Map
// ============================================

let locationPathLine = null;

function updateMap() {
    let loc = emergency.currentLocation;
    if ((!loc || (loc.latitude === 0 && loc.longitude === 0)) && emergency.locationPoints?.length > 0) {
        const lp = emergency.locationPoints[emergency.locationPoints.length - 1];
        loc = { latitude: lp.latitude, longitude: lp.longitude };
    }
    if (!loc || (loc.latitude === 0 && loc.longitude === 0)) return;

    const pos = { lat: loc.latitude, lng: loc.longitude };
    const stopTimeStr = formatIST(emergency.endTime || emergency.updatedAt);
    const markerTitle = emergency.status !== 'active'
        ? `Last Known Location (Emergency Stopped at ${stopTimeStr})`
        : `${emergency.userName || 'Victim'}'s Live Location`;

    if (!map) {
        map = new google.maps.Map(document.getElementById('map'), {
            zoom: 16,
            center: pos,
            mapTypeId: google.maps.MapTypeId.roadmap,
            styles: [
                { featureType: 'poi', elementType: 'labels', stylers: [{ visibility: 'off' }] }
            ]
        });

        marker = new google.maps.Marker({
            position: pos,
            map: map,
            title: markerTitle,
            icon: {
                path: google.maps.SymbolPath.CIRCLE,
                fillColor: emergency.status === 'active' ? '#ff1744' : '#d32f2f',
                fillOpacity: 1,
                strokeColor: '#ffffff',
                strokeWeight: 3,
                scale: 10,
            }
        });
    } else {
        marker.setPosition(pos);
        marker.setTitle(markerTitle);
        marker.setIcon({
            path: google.maps.SymbolPath.CIRCLE,
            fillColor: emergency.status === 'active' ? '#ff1744' : '#d32f2f',
            fillOpacity: 1,
            strokeColor: '#ffffff',
            strokeWeight: 3,
            scale: 10,
        });
        map.panTo(pos);
    }

    // Polyline of victim route
    if (emergency.locationPoints && emergency.locationPoints.length > 1) {
        const pathCoords = emergency.locationPoints
            .filter(p => p.latitude !== 0 && p.longitude !== 0)
            .map(p => ({ lat: p.latitude, lng: p.longitude }));

        if (pathCoords.length > 1) {
            if (!locationPathLine) {
                locationPathLine = new google.maps.Polyline({
                    path: pathCoords,
                    geodesic: true,
                    strokeColor: '#e53935',
                    strokeOpacity: 0.8,
                    strokeWeight: 4,
                    map: map
                });
            } else {
                locationPathLine.setPath(pathCoords);
            }
        }
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
// Audio Recordings (Preview max 5, Show More opens Media Hub)
// ============================================

let lastAudioCount = -1;

function renderAudioChunkItem(audio, index) {
    const chunkNum = audio.chunkIndex ?? (index + 1);
    const dur = audio.durationSeconds ?? 30;
    const time = audio.recordedAt ? formatIST(audio.recordedAt) : '';
    return `
        <div class="audio-chunk">
            <div class="audio-chunk-header">
                <span>🎵 Chunk #${chunkNum} ${time ? '• ' + time : ''}</span>
                <span>${dur}s</span>
            </div>
            <audio controls preload="none">
                <source src="${audio.url}" type="audio/mp4">
                Your browser does not support audio playback.
            </audio>
            <div style="text-align: right;">
                <a href="${audio.url}" download="audio_chunk_${chunkNum}.m4a" style="font-size: 11px; color: #1a237e; text-decoration: none; font-weight: 600;">
                    ⬇ Download Audio
                </a>
            </div>
        </div>
    `;
}

function updateAudio() {
    const audios = emergency.audioRecordings || [];
    const audioCount = audios.length;

    if (audioCount === lastAudioCount) return;
    lastAudioCount = audioCount;

    const container = document.getElementById('audioContainer');
    const list = document.getElementById('audioList');
    const showMoreContainer = document.getElementById('audioShowMoreContainer');
    const modalList = document.getElementById('modalAudioContent');
    const modalCount = document.getElementById('modalAudioCount');

    if (modalCount) modalCount.textContent = audioCount;

    if (audioCount > 0 && container && list) {
        container.style.display = 'block';
        
        // Show max 5 on main page preview
        const previewAudios = audios.slice(0, 5);
        list.innerHTML = previewAudios.map((a, i) => renderAudioChunkItem(a, i)).join('');

        if (showMoreContainer) {
            if (audioCount > 5) {
                showMoreContainer.innerHTML = `
                    <button class="show-more-btn" onclick="openMediaSection('audio')">
                        📂 Show More Audio (${audioCount} total) ↗
                    </button>
                `;
            } else {
                showMoreContainer.innerHTML = '';
            }
        }

        // Render ALL in modal
        if (modalList) {
            modalList.innerHTML = audios.map((a, i) => renderAudioChunkItem(a, i)).join('');
        }
    } else if (modalList) {
        modalList.innerHTML = '<p style="text-align:center; color:#888; padding:20px;">No audio recordings yet.</p>';
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
// Camera Images (Preview max 6 with View & Download, Show More opens Media Hub)
// ============================================

let lastImageCount = -1;

function renderImageCard(img, index) {
    const label = img.camera === 'front'
        ? '🤳 Front'
        : img.camera === 'back'
            ? '📷 Back'
            : '📷 Photo';
    
    const time = formatIST(img.capturedAt);
    const captionEscaped = `${label} • ${time}`;

    return `
        <div class="img-card-wrapper">
            <img src="${img.url}" 
                 alt="Evidence Photo" 
                 style="width:100%;height:135px;object-fit:cover;border-radius:10px;cursor:pointer;"
                 onclick="openLightbox('${img.url}', '${captionEscaped}')">
            <div style="font-size:11px;color:#666;text-align:center;font-weight:500;">
                ${captionEscaped}
            </div>
            <div class="img-action-bar">
                <button class="btn-img-action view" onclick="openLightbox('${img.url}', '${captionEscaped}')">
                    🔍 View
                </button>
                <a class="btn-img-action download" href="${img.url}" download="evidence_${index + 1}.jpg" target="_blank">
                    ⬇ Save
                </a>
            </div>
        </div>
    `;
}

function updateImages() {
    const imgs = emergency.cameraImages || [];
    const imageCount = imgs.length;

    if (imageCount === lastImageCount) return;
    lastImageCount = imageCount;

    const container = document.getElementById('imagesContainer');
    const grid = document.getElementById('imageGrid');
    const showMoreContainer = document.getElementById('imagesShowMoreContainer');
    const modalGrid = document.getElementById('modalImagesContent');
    const modalCount = document.getElementById('modalImagesCount');

    if (modalCount) modalCount.textContent = imageCount;

    if (imageCount > 0 && container && grid) {
        container.style.display = 'block';

        const reversedImgs = imgs.slice().reverse();

        // Main preview: show up to 6
        const previewImgs = reversedImgs.slice(0, 6);
        grid.innerHTML = previewImgs.map((img, idx) => renderImageCard(img, idx)).join('');

        if (showMoreContainer) {
            if (imageCount > 6) {
                showMoreContainer.innerHTML = `
                    <button class="show-more-btn" onclick="openMediaSection('images')">
                        📂 Show More Images (${imageCount} total) ↗
                    </button>
                `;
            } else {
                showMoreContainer.innerHTML = '';
            }
        }

        // Render ALL in modal
        if (modalGrid) {
            modalGrid.innerHTML = reversedImgs.map((img, idx) => renderImageCard(img, idx)).join('');
        }
    } else if (modalGrid) {
        modalGrid.innerHTML = '<p style="text-align:center; color:#888; padding:20px; grid-column:span 2;">No camera images captured yet.</p>';
    }
}

// ============================================
// LiveKit Video & Audio Streaming + Remote Camera Control
// ============================================
let currentLiveKitRoom = null;
let currentActiveCamera = 'back'; // 'back' | 'front'
let isSwitchingCamera = false;

function updateCameraUI(camera) {
    currentActiveCamera = camera;
    isSwitchingCamera = false;
    const badge = document.getElementById('cameraBadge');
    const btn = document.getElementById('switchCameraBtn');

    if (badge) {
        badge.innerHTML = camera === 'front' ? '🤳 Front Camera' : '📷 Back Camera';
    }

    if (btn) {
        btn.disabled = false;
        btn.style.opacity = '1';
        btn.innerHTML = camera === 'front' 
            ? '<span>🔄</span> Switch to Back' 
            : '<span>🔄</span> Switch to Front';
    }
}

async function requestCameraSwitch(target) {
    if (!currentLiveKitRoom) {
        alert("Live stream is not connected yet.");
        return;
    }
    if (isSwitchingCamera) return;

    const nextCamera = target || (currentActiveCamera === 'back' ? 'front' : 'back');
    isSwitchingCamera = true;

    const btn = document.getElementById('switchCameraBtn');
    if (btn) {
        btn.disabled = true;
        btn.style.opacity = '0.7';
        btn.innerHTML = '<span>⏳</span> Switching...';
    }

    try {
        const payload = new TextEncoder().encode(JSON.stringify({
            action: 'SWITCH_CAMERA',
            target: nextCamera
        }));
        await currentLiveKitRoom.localParticipant.publishData(payload, { reliable: true });
        console.log(`📤 Sent remote camera switch request: ${nextCamera}`);

        // Safety fallback re-enable after 5s if device hasn't acknowledged
        setTimeout(() => {
            if (isSwitchingCamera) {
                updateCameraUI(currentActiveCamera);
            }
        }, 5000);
    } catch (e) {
        console.error("Failed to request camera switch:", e);
        updateCameraUI(currentActiveCamera);
    }
}


function toggleVideoFullscreen() {
    const video = document.getElementById('liveVideoPlayer');
    if (!video) return;
    if (!document.fullscreenElement) {
        if (video.requestFullscreen) video.requestFullscreen();
        else if (video.webkitRequestFullscreen) video.webkitRequestFullscreen();
    } else {
        if (document.exitFullscreen) document.exitFullscreen();
    }
}

async function connectLiveKitVideo(emergencyId) {
    try {
        const response = await fetch(`/api/livekit/token?emergencyId=${emergencyId}&participantName=WebViewer&isReceiver=true`);
        const data = await response.json();
        
        if (!data.success) return;

        const room = new LivekitClient.Room();
        currentLiveKitRoom = room;
        
        room.on(LivekitClient.RoomEvent.TrackSubscribed, (track, publication, participant) => {
            console.log(`📡 LiveKit Track Subscribed: ${track.kind} (${publication.trackName})`);

            if (track.kind === LivekitClient.Track.Kind.Video) {
                const videoEl = document.getElementById('liveVideoPlayer');
                if (videoEl) {
                    track.attach(videoEl);
                    videoEl.play().then(() => {
                        ensureStreamReadyAndRecord();
                    }).catch(e => console.log("Video play pending interaction:", e));
                    videoEl.onloadedmetadata = () => {
                        ensureStreamReadyAndRecord();
                    };
                }

                const container = document.getElementById('videoContainer');
                if (container) container.style.display = 'block';

                if (publication.trackName === "front_camera") {
                    updateCameraUI('front');
                } else if (publication.trackName === "back_camera") {
                    updateCameraUI('back');
                }
            } else if (track.kind === LivekitClient.Track.Kind.Audio) {
                const audioEl = document.getElementById('liveAudioPlayer');
                if (audioEl) {
                    track.attach(audioEl);
                    audioEl.play().catch(e => console.log("Audio play pending interaction:", e));
                }
            }
        });

        room.on(LivekitClient.RoomEvent.TrackUnsubscribed, (track, publication) => {
            console.log(`📡 LiveKit Track Unsubscribed: ${track.kind}`);
            if (track.kind === LivekitClient.Track.Kind.Video) {
                const videoEl = document.getElementById('liveVideoPlayer');
                if (videoEl) track.detach(videoEl);
            } else if (track.kind === LivekitClient.Track.Kind.Audio) {
                const audioEl = document.getElementById('liveAudioPlayer');
                if (audioEl) track.detach(audioEl);
            }
        });

        room.on(LivekitClient.RoomEvent.DataReceived, (payload, participant) => {
            try {
                const text = new TextDecoder().decode(payload);
                console.log("📩 LiveKit Data Received:", text);
                const msg = JSON.parse(text);
                if (msg.type === "CAMERA_STATE" && msg.activeCamera) {
                    updateCameraUI(msg.activeCamera);
                }
            } catch (err) {
                console.error("Error parsing LiveKit data message:", err);
            }
        });

        await room.connect(data.url, data.token);
        console.log("✅ Connected to LiveKit Stream");

        // Force video and audio to play on first user interaction
        document.body.addEventListener('click', () => {
            const videoEl = document.getElementById('liveVideoPlayer');
            const audioEl = document.getElementById('liveAudioPlayer');
            if (videoEl) videoEl.play().catch(() => {});
            if (audioEl) audioEl.play().catch(() => {});
        }, { once: true });

    } catch (e) {
        console.error("LiveKit Connection Error:", e);
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
// ============================================
// Live Stream Robust Compositor & 10-Min / Stop Emergency Recording
// ============================================

let mediaStreamRecorder = null;
let recordedVideoChunks = [];
let isRecordingLiveStream = false;
let isRecordingFinalized = false;
let recordedVideoBlob = null;
let recordedVideoUrl = null;
let hasUploadedStream = false;

let compositorCanvas = null;
let compositorCtx = null;
let compositorInterval = null;
let streamRecordingTimer = null;
let recordingStartTimestamp = null;
let recordingElapsedInterval = null;

const MAX_RECORDING_DURATION_MS = 10 * 60 * 1000; // 10 minutes cutoff

function initCompositor() {
    if (!compositorCanvas) {
        compositorCanvas = document.createElement('canvas');
        compositorCanvas.width = 1280;
        compositorCanvas.height = 720;
        compositorCtx = compositorCanvas.getContext('2d');
    }
}

function startCompositorLoop() {
    initCompositor();
    if (compositorInterval) clearInterval(compositorInterval);

    // Keep continuous 30fps draw tick even if tab is in background
    compositorInterval = setInterval(() => {
        if (!isRecordingLiveStream) return;
        const video = document.getElementById('liveVideoPlayer');
        if (video && video.readyState >= 2 && video.videoWidth > 0) {
            try {
                compositorCtx.drawImage(video, 0, 0, 1280, 720);
            } catch (err) {
                // Ignore transient draw error during camera switch
            }
        }
    }, 33);
}

function ensureStreamReadyAndRecord() {
    if (isRecordingLiveStream || isRecordingFinalized) return;
    if (emergency && emergency.status !== 'active') return;

    const video = document.getElementById('liveVideoPlayer');
    if (!video) return;

    if (video.videoWidth > 0 && video.readyState >= 2) {
        startStreamRecording();
    } else {
        const onReady = () => {
            video.removeEventListener('playing', onReady);
            video.removeEventListener('loadeddata', onReady);
            setTimeout(startStreamRecording, 600);
        };
        video.addEventListener('playing', onReady);
        video.addEventListener('loadeddata', onReady);
    }
}

function startStreamRecording() {
    if (isRecordingLiveStream || isRecordingFinalized) return;
    if (emergency && emergency.status !== 'active') return;

    const video = document.getElementById('liveVideoPlayer');
    if (!video) return;

    try {
        startCompositorLoop();
        const canvasStream = compositorCanvas.captureStream(30);

        // Mix live audio track
        const audio = document.getElementById('liveAudioPlayer');
        if (audio && audio.srcObject) {
            const audioTracks = audio.srcObject.getAudioTracks();
            if (audioTracks.length > 0) {
                canvasStream.addTrack(audioTracks[0]);
            }
        }

        // Detect supported container format (prefer MP4, fallback to WebM)
        let mimeType = 'video/webm;codecs=vp8,opus';
        if (typeof MediaRecorder !== 'undefined') {
            if (MediaRecorder.isTypeSupported('video/mp4;codecs=avc1,mp4a.40.2')) {
                mimeType = 'video/mp4;codecs=avc1,mp4a.40.2';
            } else if (MediaRecorder.isTypeSupported('video/mp4')) {
                mimeType = 'video/mp4';
            } else if (MediaRecorder.isTypeSupported('video/webm;codecs=vp8,opus')) {
                mimeType = 'video/webm;codecs=vp8,opus';
            } else if (MediaRecorder.isTypeSupported('video/webm')) {
                mimeType = 'video/webm';
            }
        }

        recordedVideoChunks = [];
        mediaStreamRecorder = new MediaRecorder(canvasStream, { mimeType });

        mediaStreamRecorder.ondataavailable = (e) => {
            if (e.data && e.data.size > 0) {
                recordedVideoChunks.push(e.data);
            }
        };

        mediaStreamRecorder.onstop = () => {
            console.log("🎥 Live stream recording stopped. Total chunks collected:", recordedVideoChunks.length);
            if (compositorInterval) {
                clearInterval(compositorInterval);
                compositorInterval = null;
            }
            if (recordingElapsedInterval) {
                clearInterval(recordingElapsedInterval);
                recordingElapsedInterval = null;
            }
            if (streamRecordingTimer) {
                clearTimeout(streamRecordingTimer);
                streamRecordingTimer = null;
            }

            if (recordedVideoChunks.length > 0) {
                const totalDur = recordingStartTimestamp ? Math.round((Date.now() - recordingStartTimestamp) / 1000) : 0;
                recordedVideoBlob = new Blob(recordedVideoChunks, { type: mimeType });
                recordedVideoUrl = URL.createObjectURL(recordedVideoBlob);
                isRecordingFinalized = true;

                console.log(`✅ Compiled recorded stream video (${(recordedVideoBlob.size / 1024 / 1024).toFixed(2)} MB, ${totalDur}s)`);
                updateVideoUI();
                uploadRecordedStream(recordedVideoBlob, totalDur);
            }
        };

        // Record with 1s timeslices so chunks continuously flush
        mediaStreamRecorder.start(1000);
        isRecordingLiveStream = true;
        recordingStartTimestamp = Date.now();
        console.log("🎥 Live stream recording started (MIME: " + mimeType + "). Cutoff: 10 min or on Stop Emergency.");

        // Update UI
        updateVideoUI();
        if (recordingElapsedInterval) clearInterval(recordingElapsedInterval);
        recordingElapsedInterval = setInterval(() => {
            if (!isRecordingLiveStream) {
                clearInterval(recordingElapsedInterval);
                return;
            }
            const badge = document.getElementById('recordingTimerBadge');
            if (badge && recordingStartTimestamp) {
                const elapsedSec = Math.floor((Date.now() - recordingStartTimestamp) / 1000);
                const mins = Math.floor(elapsedSec / 60).toString().padStart(2, '0');
                const secs = (elapsedSec % 60).toString().padStart(2, '0');
                badge.textContent = `⏱️ Recording: ${mins}:${secs} / 10:00`;
            }
        }, 1000);

        // 10-Minute Cutoff Timer
        if (streamRecordingTimer) clearTimeout(streamRecordingTimer);
        streamRecordingTimer = setTimeout(() => {
            console.log("⏱️ 10 minutes reached! Finalizing stream recording...");
            stopStreamRecording("10_MIN_CUTOFF");
        }, MAX_RECORDING_DURATION_MS);

    } catch (e) {
        console.warn("Could not start live stream recorder:", e);
    }
}

function stopStreamRecording(reason) {
    if (!isRecordingLiveStream) return;
    console.log(`🛑 Finalizing stream recording (Trigger: ${reason || 'STOP_EMERGENCY'})...`);

    if (streamRecordingTimer) {
        clearTimeout(streamRecordingTimer);
        streamRecordingTimer = null;
    }
    if (recordingElapsedInterval) {
        clearInterval(recordingElapsedInterval);
        recordingElapsedInterval = null;
    }

    if (mediaStreamRecorder && mediaStreamRecorder.state !== 'inactive') {
        try {
            mediaStreamRecorder.stop();
        } catch (e) {
            console.warn("Error stopping MediaRecorder:", e);
        }
    }
    isRecordingLiveStream = false;
}

async function uploadRecordedStream(blob, durationSec) {
    if (hasUploadedStream || !token) return;
    hasUploadedStream = true;

    try {
        const formData = new FormData();
        const ext = blob.type.includes('mp4') ? 'mp4' : 'webm';
        formData.append('video', blob, `stream_recording_${Date.now()}.${ext}`);
        formData.append('durationSeconds', (durationSec || 0).toString());
        formData.append('recordedAt', new Date().toISOString());

        console.log("📤 Uploading recorded stream to backend...");
        const res = await fetch(`/api/emergency/receiver/${token}/video`, {
            method: 'POST',
            body: formData,
        });
        const data = await res.json();
        if (data.success && data.video) {
            console.log("✅ Stream recording permanently archived:", data.video.url);
            if (!emergency.videoRecordings) emergency.videoRecordings = [];
            emergency.videoRecordings.push(data.video);
            updateVideoUI();
        }
    } catch (err) {
        console.error("Failed to upload recorded stream:", err);
    }
}

function updateVideoUI() {
    const videoContent = document.getElementById('modalVideoContent');
    const modalVideoCount = document.getElementById('modalVideoCount');
    if (!videoContent) return;

    const savedVideos = emergency?.videoRecordings || [];
    const hasCompletedRecording = Boolean(savedVideos.length > 0 || (isRecordingFinalized && recordedVideoUrl));
    const activeVideoUrl = savedVideos.length > 0 
        ? savedVideos[savedVideos.length - 1].url 
        : (isRecordingFinalized ? recordedVideoUrl : null);

    if (modalVideoCount) {
        modalVideoCount.textContent = hasCompletedRecording ? Math.max(savedVideos.length, 1) : 0;
    }

    // 1. If recording has finalized (after 10 min or on Stop Emergency) OR already saved on server:
    if (hasCompletedRecording && activeVideoUrl) {
        const ext = activeVideoUrl.endsWith('.mp4') ? 'mp4' : 'webm';
        videoContent.innerHTML = `
            <div style="background:#000; border-radius:14px; overflow:hidden; margin-bottom:12px; box-shadow:0 4px 14px rgba(0,0,0,0.2);">
                <video src="${activeVideoUrl}" controls playsinline style="width:100%; max-height:360px; object-fit:contain; background:#000;"></video>
            </div>
            <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:10px; padding: 4px 0;">
                <div>
                    <span style="font-weight:700; color:#1a237e; font-size:14px;">🎥 Live Stream Full Recording</span>
                    <div style="font-size:12px; color:#666;">Generated after 10 min or on Stop Emergency</div>
                </div>
                <a href="${activeVideoUrl}" download="emergency_recording_${Date.now()}.${ext}" class="btn-download-primary">
                    ⬇ Download Video
                </a>
            </div>
        `;
    } 
    // 2. If emergency is active and recording is in progress (under 10 minutes):
    else if (emergency?.status === 'active') {
        const elapsedSec = recordingStartTimestamp ? Math.floor((Date.now() - recordingStartTimestamp) / 1000) : 0;
        const mins = Math.floor(elapsedSec / 60).toString().padStart(2, '0');
        const secs = (elapsedSec % 60).toString().padStart(2, '0');

        videoContent.innerHTML = `
            <div style="text-align:center; padding: 36px 16px; background: #fdfdfe; border-radius: 16px; border: 1.5px dashed #3949ab;">
                <span style="font-size: 42px; display: inline-block; animation: pulse 1.5s infinite;">🔴</span>
                <h4 style="margin: 14px 0 6px; font-size: 16px; color: #1a237e;">Live Stream Recording in Progress</h4>
                <p style="font-size: 13px; color: #555; max-width: 440px; margin: 0 auto; line-height: 1.4;">
                    The full recorded video will be processed and available here automatically <b>after 10 minutes</b> or as soon as <b>"STOP EMERGENCY"</b> is triggered.
                </p>
                <div id="recordingTimerBadge" style="margin-top: 14px; display: inline-block; background: #e8eaf6; color: #1a237e; font-size: 13px; font-weight: bold; padding: 6px 14px; border-radius: 20px;">
                    ⏱️ Recording: ${mins}:${secs} / 10:00
                </div>
            </div>
        `;
    } 
    // 3. If emergency has concluded and no video was recorded:
    else {
        videoContent.innerHTML = `
            <div style="text-align:center; padding: 36px 14px; color: #777;">
                <span style="font-size: 38px;">🎥</span>
                <h4 style="margin: 12px 0 6px; font-size: 15px;">No Stream Recording Available</h4>
                <p style="font-size: 13px;">Stream recordings are created automatically during active video streams.</p>
            </div>
        `;
    }
}

// ============================================
// Media Modal & Tab Switching
// ============================================

function openMediaSection(tab) {
    const modal = document.getElementById('mediaModal');
    if (modal) {
        modal.style.display = 'flex';
        switchMediaTab(tab || 'video');
    }
}

function closeMediaSection() {
    const modal = document.getElementById('mediaModal');
    if (modal) modal.style.display = 'none';
}

function switchMediaTab(tab) {
    const tabs = ['video', 'audio', 'images'];
    tabs.forEach(t => {
        const btn = document.getElementById('tabBtn' + t.charAt(0).toUpperCase() + t.slice(1));
        const pane = document.getElementById('modalPane' + t.charAt(0).toUpperCase() + t.slice(1));
        if (btn) btn.classList.toggle('active', t === tab);
        if (pane) pane.classList.toggle('active', t === tab);
    });

    if (tab === 'video') updateVideoUI();
}

// ============================================
// Image Lightbox Viewer
// ============================================

function openLightbox(url, caption) {
    const modal = document.getElementById('imageLightbox');
    const img = document.getElementById('lightboxImg');
    const cap = document.getElementById('lightboxCaption');
    const dl = document.getElementById('lightboxDownloadBtn');

    if (modal && img) {
        img.src = url;
        if (cap) cap.textContent = caption || '';
        if (dl) {
            dl.href = url;
            dl.download = 'evidence_photo.jpg';
        }
        modal.style.display = 'flex';
    }
}

function closeLightbox(e) {
    if (e && e.target && e.target.id === 'lightboxImg') return;
    const modal = document.getElementById('imageLightbox');
    if (modal) modal.style.display = 'none';
}

// Close modals on ESC key
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeLightbox();
        closeMediaSection();
    }
});
