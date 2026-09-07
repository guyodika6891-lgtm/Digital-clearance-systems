// ============================================
// DIGITAL CLEARANCE SYSTEM - JAVASCRIPT
// ============================================

// Toggle between login and register forms
function showRegister() {
    document.querySelector('.login-box').style.display = 'none';
    document.querySelector('.register-box').style.display = 'block';
}

function showLogin() {
    document.querySelector('.login-box').style.display = 'block';
    document.querySelector('.register-box').style.display = 'none';
}

// Handle Login
document.getElementById('loginForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const student_id = document.getElementById('student_id').value;
    const password = document.getElementById('password').value;
    const submitBtn = e.target.querySelector('button[type="submit"]');
    
    // Show loading state
    submitBtn.disabled = true;
    submitBtn.textContent = 'Logging in...';
    
    try {
        const response = await fetch('php/login.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `student_id=${encodeURIComponent(student_id)}&password=${encodeURIComponent(password)}`
        });
        
        const data = await response.json();
        
        if (data.success) {
            window.location.href = data.redirect || 'dashboard.html';
        } else {
            showAlert(data.message || 'Login failed', 'danger');
        }
    } catch (error) {
        showAlert('Error: ' + error.message, 'danger');
    } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Login';
    }
});

// Handle Registration
document.getElementById('registerForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const student_id = document.getElementById('reg_student_id').value;
    const full_name = document.getElementById('reg_full_name').value;
    const email = document.getElementById('reg_email').value;
    const password = document.getElementById('reg_password').value;
    const role = document.getElementById('reg_role') ? document.getElementById('reg_role').value : 'student';
    const submitBtn = e.target.querySelector('button[type="submit"]');
    
    // Show loading state
    submitBtn.disabled = true;
    submitBtn.textContent = 'Registering...';
    
    try {
        const response = await fetch('php/register.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `student_id=${encodeURIComponent(student_id)}&full_name=${encodeURIComponent(full_name)}&email=${encodeURIComponent(email)}&password=${encodeURIComponent(password)}&role=${encodeURIComponent(role)}`
        });
        
        const data = await response.json();
        
        if (data.success) {
            showAlert('Registration successful! Please login.', 'success');
            showLogin();
            document.getElementById('registerForm').reset();
        } else {
            showAlert('Registration failed: ' + data.message, 'danger');
        }
    } catch (error) {
        showAlert('Error: ' + error.message, 'danger');
    } finally {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Register';
    }
});

// Show alert message
function showAlert(message, type = 'info') {
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type}`;
    alertDiv.textContent = message;
    
    // Remove existing alerts
    const existingAlerts = document.querySelectorAll('.alert');
    existingAlerts.forEach(el => el.remove());
    
    // Insert at top of container
    const container = document.querySelector('.container');
    if (container) {
        container.insertBefore(alertDiv, container.firstChild);
    } else {
        // For dashboard
        const content = document.querySelector('.dashboard-content');
        if (content) {
            content.insertBefore(alertDiv, content.firstChild);
        }
    }
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
        if (alertDiv.parentNode) {
            alertDiv.remove();
        }
    }, 5000);
}

// ============================================
// DASHBOARD FUNCTIONS
// ============================================

// Load clearance status
async function loadClearanceStatus() {
    try {
        const response = await fetch('php/clearance.php');
        const data = await response.json();
        
        if (data.error) {
            console.error('Error:', data.error);
            return;
        }
        
        // Update stats
        updateStats(data);
        
        // Update grid
        const grid = document.querySelector('.clearance-grid');
        if (grid) {
            grid.innerHTML = '';
            
            if (data.length === 0) {
                grid.innerHTML = '<p style="grid-column: 1/-1; text-align: center; color: #666;">No clearance records found.</p>';
                return;
            }
            
            data.forEach(item => {
                const statusClass = item.status || 'pending';
                const statusColor = statusClass === 'approved' ? '#28a745' : 
                                   statusClass === 'rejected' ? '#dc3545' : 
                                   statusClass === 'cancelled' ? '#6c757d' : '#ffc107';
                
                let actionsHtml = '';
                if (window.location.pathname.includes('admin_dashboard.html') || 
                    window.location.pathname.includes('hod_dashboard.html')) {
                    actionsHtml = `
                        <div class="clearance-actions">
                            <button onclick="updateClearance('${item.student_id}', '${item.department_name}', 'approved')" class="btn-approve">Approve</button>
                            <button onclick="updateClearance('${item.student_id}', '${item.department_name}', 'rejected')" class="btn-reject">Reject</button>
                            <button onclick="updateClearance('${item.student_id}', '${item.department_name}', 'pending')" class="btn-pending">Pending</button>
                        </div>
                    `;
                }
                
                grid.innerHTML += `
                    <div class="clearance-card">
                        <h3>${item.department_name || 'Unknown Department'}</h3>
                        <p>Head: ${item.department_head || 'N/A'}</p>
                        <p>Status: <span class="status status-${statusClass}" style="color: ${statusColor}; font-weight: bold;">${(statusClass || 'pending').toUpperCase()}</span></p>
                        ${item.remarks ? `<p>Remarks: ${item.remarks}</p>` : ''}
                        ${item.cleared_at ? `<p>Cleared: ${new Date(item.cleared_at).toLocaleDateString()}</p>` : ''}
                        ${item.cleared_by_name ? `<p>Cleared By: ${item.cleared_by_name}</p>` : ''}
                        ${item.student_id ? `<p>Student: ${item.full_name || item.student_id}</p>` : ''}
                        ${actionsHtml}
                    </div>
                `;
            });
        }
    } catch (error) {
        console.error('Error loading clearance:', error);
        showAlert('Error loading clearance data', 'danger');
    }
}

// Update statistics
function updateStats(data) {
    const total = data.length;
    const cleared = data.filter(item => item.status === 'approved').length;
    const pending = data.filter(item => item.status === 'pending').length;
    const rejected = data.filter(item => item.status === 'rejected').length;
    
    document.getElementById('totalDepts').textContent = total;
    document.getElementById('clearedDepts').textContent = cleared;
    document.getElementById('pendingDepts').textContent = pending;
    document.getElementById('rejectedDepts').textContent = rejected;
}

// Load user info
async function loadUserInfo() {
    try {
        const response = await fetch('php/get_user.php');
        const data = await response.json();
        
        if (data.success) {
            const userInfo = document.querySelector('.user-info span');
            if (userInfo) {
                const roleBadge = data.role === 'admin' ? '🛡️' : 
                                 data.role === 'hod' ? '👔' : '👨‍🎓';
                userInfo.textContent = `${roleBadge} Welcome, ${data.full_name} (${data.role.toUpperCase()})`;
            }
        }
    } catch (error) {
        console.error('Error loading user info:', error);
    }
}

// Update clearance status (Admin/HOD only)
async function updateClearance(studentId, departmentName, status) {
    if (!confirm(`Are you sure you want to set ${departmentName} clearance to ${status}?`)) {
        return;
    }
    
    try {
        const response = await fetch('php/update_clearance.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `student_id=${encodeURIComponent(studentId)}&department=${encodeURIComponent(departmentName)}&status=${encodeURIComponent(status)}`
        });
        
        const data = await response.json();
        
        if (data.success) {
            showAlert('Clearance updated successfully!', 'success');
            loadClearanceStatus(); // Refresh
        } else {
            showAlert('Update failed: ' + data.message, 'danger');
        }
    } catch (error) {
        showAlert('Error: ' + error.message, 'danger');
    }
}

// Logout
function logout() {
    if (confirm('Are you sure you want to logout?')) {
        window.location.href = 'php/logout.php';
    }
}

// ============================================
// INITIALIZATION
// ============================================

// Call functions on page load
document.addEventListener('DOMContentLoaded', function() {
    const path = window.location.pathname;
    
    if (path.includes('dashboard.html') || path.includes('admin_dashboard.html') || path.includes('hod_dashboard.html')) {
        loadClearanceStatus();
        loadUserInfo();
    }
});
