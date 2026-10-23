// Reemplaza por completo al login.js actual. Ya no hay contraseñas en el navegador.
document.querySelector('#loginForm')?.addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.currentTarget;
  const feedback = document.querySelector('#loginFeedback');
  const button = form.querySelector('button[type=submit]');
  button.disabled = true;
  try {
    const res = await fetch('/api/login', {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ role: form.elements.role.value, password: form.elements.password.value })
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || 'No se pudo iniciar sesión');
    location.replace('index.html');
  } catch (err) {
    feedback.textContent = err.message;
    feedback.hidden = false;
    button.disabled = false;
  }
});
