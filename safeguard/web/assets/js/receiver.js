// ============================================
// SafeGuard - Receiver Web Page JavaScript
// ============================================

// Get token from URL
const token = window.location.pathname.split('/').pop();

// State
let emergency = null;
let map = null;
let marker = null;
let locationPath = [];
let updateInterval = null;

// DOM Elements
const loading = document.getElementById('loading');
const content = document.getElementById('content');
const senderName = document.getElementById('senderName');
const senderPhone = document.getElementById('senderPhone');
const avatar = document.getElementById('avatar');
const startedAt = document.getElementById('startedAt');
const statusValue = document.getElementById('statusValue');
const statusBadge = document.getElementById('statusBadge');
const durationValue = document.getElementById('durationValue');
const updateCount = document.getElementById('updateCount');
const imageCount = document.getElementById('imageCount');
const imageGrid = document.getElementById('imageGrid');
const imagesContainer = document.getElementById('imagesContainer');
const replyInput = document.getElementById('replyInput');
const sendReplyBtn = document.getElementById('sendReplyBtn');
const repliesList = document.getElementById('repliesList');

// ============================================
// Fetch Emergency Data
// ============================================

async function fetchEmergencyData() {
    try {
        const response = await fetch(`/api/emergency/web/${token}`);
        const data = await response.json();
        
        if (!data.success) {
            showError(data.message || 'Failed to load emergency data');
            return;
        }
        
        emergency = data.emergency;
        renderUI();
        startLiveUpdates();
        
    } catch (error) {
        console.error('Error fetching data:', error);
        showError('Connection error. Please try again.');
    }
}

// ============================================
// Render UI
// ============================================

function renderUI() {
    if (!emergency) return;
    
    // Show content, hide loading
    loading.style.display = 'none';
    content.style.display = 'block';
    
    // Sender Info
    senderName.textContent = emergency.userName || 'Unknown';
    senderPhone.textContent = `📱 ${emergency.userPhone || 'No phone'}`;
    avatar.textContent = (emergency.userName || 'U')[0].toUpperCase();
    
    const startTime = new Date(emergency.startTime);
    startedAt.textContent = `Started: ${formatTime(startTime)}`;
    
    // Status
    const isActive = emergency.status === 'active';
    statusValue.textContent = isActive ? '🔴 Active' : '✅ Resolved';
    statusValue.style.color = isActive ? '#ff1744' : '#00c853';
    statusBadge.textContent = isActive ? '● ACTIVE' : '● RESOLVED';
    statusBadge.className = `status ${isActive ? 'active' : 'resolved'}`;
    
    // Counts
    updateCount.textContent = emergency.locationPoints?.length || 0;
    imageCount.textContent = emergency.cameraImages?.length || 0;
    
    // Images
    if (emergency.cameraImages && emergency.cameraImages.length > 0) {
        imagesContainer.style.display = 'block';
        imageGrid.innerHTML = emergency.cameraImages.map(img => `
            <img src="${img.url}" alt="Emergency image" />
        `).join('');
    } else {
        imagesContainer.style.display = 'none';
    }
    
    // Replies
    renderReplies();
    
    // Map
    initMap();
    
    // Start duration timer
    startDurationTimer(startTime);
}

// ============================================
// Map
// ============================================

function initMap() {
    if (!emergency.currentLocation) return;
    
    const location = emergency.currentLocation;
    const center = { lat: location.latitude, lng: location.longitude };
    
    map = new google.maps.Map(document.getElementById('map'), {
        zoom: 15,
        center: center,
        mapTypeId: google.maps.MapTypeId.roadmap,
        styles: [
            { featureType: 'poi', elementType: 'labels', stylers: [{ visibility: 'off' }] }
        ]
    });
    
    // Add marker
    marker = new google.maps.Marker({
        position: center,
        map: map,
        title: 'Sender\'s Location',
        icon: {
            path: google.maps.SymbolPath.CIRCLE,
            fillColor: '#ff1744',
            fillOpacity: 1,
            strokeColor: '#ffffff',
            strokeWeight: 2,
            scale: 12,
        },
        animation: google.maps.Animation.BOUNCE,
    });
    
    // Draw path
    drawPath();
}

function drawPath() {
    if (!emergency.locationPoints || emergency.locationPoints.length < 2) return;
    
    const path = emergency.locationPoints.map(p => ({
        lat: p.latitude,
        lng: p.longitude
    }));
    
    new google.maps.Polyline({
        path: path,
        geodesic: true,
        strokeColor: '#ff1744',
        strokeOpacity: 1.0,
        strokeWeight: 3,
        map: map,
    });
}

function updateMap() {
    if (!emergency.currentLocation || !map) return;
    
    const location = emergency.currentLocation;
    const pos = { lat: location.latitude, lng: location.longitude };
    
    // Update marker position
    if (marker) {
        marker.setPosition(pos);
        map.panTo(pos);
    }
    
    // Update count
    updateCount.textContent = emergency.locationPoints?.length || 0;
}

// ============================================
// Live Updates
// ============================================

function startLiveUpdates() {
    // Poll every 5 seconds
    updateInterval = setInterval(async () => {
        try {
            const response = await fetch(`/api/emergency/web/${token}`);
            const data = await response.json();
            
            if (data.success) {
                emergency = data.emergency;
                updateMap();
                renderReplies();
                
                // Update image count
                imageCount.textContent = emergency.cameraImages?.length || 0;
                
                // Check if emergency ended
                if (emergency.status !== 'active') {
                    clearInterval(updateInterval);
                    statusValue.textContent = '✅ Resolved';
                    statusValue.style.color = '#00c853';
                    statusBadge.textContent = '● RESOLVED';
                    statusBadge.className = 'status resolved';
                }
            }
        } catch (error) {
            console.error('Update error:', error);
        }
    }, 5000);
}

// ============================================
// Replies
// ============================================

function renderReplies() {
    if (!emergency.receiverReplies || emergency.receiverReplies.length === 0) {
        repliesList.innerHTML = '<div style="color: #888; font-size: 13px; text-align: center; padding: 8px;">No replies yet.</div>';
        return;
    }
    
    repliesList.innerHTML = emergency.receiverReplies.map(reply => `
        <div class="reply-item">
            <span class="sender">${reply.contactName || 'Unknown'}</span>
            <span>${reply.message}</span>
            <span class="time">${formatTime(new Date(reply.repliedAt))}</span>
        </div>
    `).join('');
}

// ============================================
// Send Reply
// ============================================

async function sendReply() {
    const message = replyInput.value.trim();
    if (!message) return;
    
    try {
        const response = await fetch('/api/emergency/reply', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                token: token,
                message: message
            })
        });
        
        const data = await response.json();
        
        if (data.success) {
            replyInput.value = '';
            // Add to replies list
            if (!emergency.receiverReplies) emergency.receiverReplies = [];
            emergency.receiverReplies.push({
                contactName: 'You',
                message: message,
                repliedAt: new Date().toISOString()
            });
            renderReplies();
            showToast('✅ Reply sent successfully');
        } else {
            showToast('❌ Failed to send reply: ' + data.message);
        }
    } catch (error) {
        console.error('Reply error:', error);
        showToast('❌ Error sending reply');
    }
}

// ============================================
// Helpers
// ============================================

function formatTime(date) {
    return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

function startDurationTimer(startTime) {
    setInterval(() => {
        const diff = Math.floor((Date.now() - new Date(startTime).getTime()) / 1000);
        const mins = Math.floor(diff / 60);
        const secs = diff % 60;
        durationValue.textContent = `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    }, 1000);
}

function showError(message) {
    loading.innerHTML = `
        <div style="text-align: center; padding: 20px;">
            <div style="font-size: 48px; margin-bottom: 16px;">❌</div>
            <p style="color: #666;">${message}</p>
            <button onclick="location.reload()" style="margin-top: 16px; padding: 10px 24px; background: #1a237e; color: white; border: none; border-radius: 8px; cursor: pointer;">
                Try Again
            </button>
        </div>
    `;
}

function showToast(message) {
    const toast = document.createElement('div');
    toast.style.cssText = `
        position: fixed;
        bottom: 20px;
        left: 50%;
        transform: translateX(-50%);
        background: ${message.includes('✅') ? '#00c853' : '#ff1744'};
        color: white;
        padding: 12px 24px;
        border-radius: 8px;
        font-weight: 500;
        z-index: 1000;
        box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        animation: fadeInUp 0.3s ease;
    `;
    toast.textContent = message;
    document.body.appendChild(toast);
    
    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transition = 'opacity 0.3s';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// ============================================
// Event Listeners
// ============================================

sendReplyBtn.addEventListener('click', sendReply);

replyInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') sendReply();
});

// ============================================
// Start
// ============================================

// Check token
if (!token || token === 'receiver.html') {
    showError('Invalid link. Please use the link from the emergency SMS.');
} else {
    fetchEmergencyData();
}