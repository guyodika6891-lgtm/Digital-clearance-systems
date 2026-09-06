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
    
    try {
        const response = await fetch('php/login.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `student_id=${student_id}&password=${password}`
        });
        
        const data = await response.json();
        
        if (data.success) {
            window.location.href = 'dashboard.html';
        } else {
            alert('Login failed: ' + data.message);
        }
    } catch (error) {
        alert('Error: ' + error.message);
    }
});

// Handle Registration
document.getElementById('registerForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const student_id = document.getElementById('reg_student_id').value;
    const full_name = document.getElementById('reg_full_name').value;
    const email = document.getElementById('reg_email').value;
    const password = document.getElementById('reg_password').value;
    
    try {
        const response = await fetch('php/register.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `student_id=${student_id}&full_name=${full_name}&email=${email}&password=${password}`
        });
        
        const data = await response.json();
        
        if (data.success) {
            alert('Registration successful! Please login.');
            showLogin();
            document.getElementById('registerForm').reset();
        } else {
            alert('Registration failed: ' + data.message);
        }
    } catch (error) {
        alert('Error: ' + error.message);
    }
});

// Dashboard Functions
async function loadClearanceStatus() {
    try {
        const response = await fetch('php/clearance.php');
        const data = await response.json();
        
        const grid = document.querySelector('.clearance-grid');
        if (grid) {
            grid.innerHTML = '';
            data.forEach(item => {
                grid.innerHTML += `
                    <div class="clearance-card">
                        <h3>${item.department_name}</h3>
                        <p>Status: <span class="status status-${item.status}">${item.status.toUpperCase()}</span></p>
                        ${item.remarks ? `<p>Remarks: ${item.remarks}</p>` : ''}
                        ${item.cleared_at ? `<p>Cleared: ${new Date(item.cleared_at).toLocaleDateString()}</p>` : ''}
                    </div>
                `;
            });
        }
    } catch (error) {
        console.error('Error loading clearance:', error);
    }
}

// Logout
function logout() {
    window.location.href = 'php/logout.php';
}

// Call on dashboard load
if (window.location.pathname.includes('dashboard.html')) {
    loadClearanceStatus();
}