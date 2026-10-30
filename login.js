// Inicio de sesión real: el servidor (Flask + MySQL) valida la contraseña del rol y crea la sesión.
const loginForm = document.querySelector('#loginForm');
const roleSelect = loginForm?.elements.role;
const passwordInput = loginForm?.elements.password;
const feedback = document.querySelector('#loginFeedback');

// Restos de la versión de demostración (localStorage): se eliminan.
['ipha-role-v2', 'ipha-demo-session-v1'].forEach(key => localStorage.removeItem(key));

function showError(message) {
  feedback.textContent = message;
  feedback.hidden = false;
}

loginForm?.addEventListener('submit', async event => {
  event.preventDefault();
  feedback.hidden = true;
  if (location.protocol === 'file:') {
    showError('Abre la aplicación desde el servidor: ejecuta "python servidor.py" y entra a http://localhost:5000');
    return;
  }
  const button = loginForm.querySelector('button[type="submit"]');
  if (button) button.disabled = true;
  try {
    const response = await fetch('/api/login', {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ role: roleSelect.value, password: passwordInput.value }),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      showError(data.error || 'No se pudo iniciar sesión.');
      passwordInput.select();
      return;
    }
    location.replace('index.html');
  } catch {
    showError('No se pudo conectar con el servidor. Verifica que esté encendido (python servidor.py).');
  } finally {
    if (button) button.disabled = false;
  }
});
