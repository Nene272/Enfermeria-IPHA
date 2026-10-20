// Demo-only credentials; never use this client-side check for real authentication.
// TODO Flask/MySQL: validate credentials and resolve roles server-side, then issue a secure session cookie.
const demoAccounts = [
  { password: 'Demo-Enfermeria-26', role: 'nurse' },
  { password: 'Demo-Orientacion-26', role: 'guidance' },
  { password: 'Demo-Admin-26', role: 'admin' }
];
document.querySelector('#loginForm')?.addEventListener('submit', event => {
  event.preventDefault();
  const form = event.currentTarget;
  const role = form.elements.role.value;
  const password = form.elements.password.value;
  const account = demoAccounts.find(item => item.role === role && item.password === password);
  const feedback = document.querySelector('#loginFeedback');
  if (!account) { feedback.textContent = 'Usuario o contraseña de prueba incorrectos.'; feedback.hidden = false; return }
  localStorage.setItem('ipha-role-v2', account.role);
  localStorage.setItem('ipha-demo-session-v1', 'true');
  location.replace('index.html');
});
