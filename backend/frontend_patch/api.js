// Cargar ANTES de app.js en TODAS las páginas:  <script src="api.js"></script>
// Cliente del backend + caché en memoria (reemplaza al localStorage).
const api = (() => {
  async function req(method, url, body) {
    const res = await fetch(url, {
      method,
      credentials: 'same-origin',
      headers: body ? { 'Content-Type': 'application/json' } : {},
      body: body ? JSON.stringify(body) : undefined
    });
    const data = await res.json().catch(() => ({}));
    if (res.status === 401 && !location.pathname.endsWith('login.html')) {
      location.replace('login.html');
      throw new Error('Sesión expirada');
    }
    if (!res.ok) throw new Error(data.error || 'Error del servidor');
    return data;
  }
  return {
    get: url => req('GET', url),
    post: (url, body = {}) => req('POST', url, body),
    put: (url, body) => req('PUT', url, body),
    patch: (url, body) => req('PATCH', url, body),
    me: () => req('GET', '/api/me'),
    logout: () => req('POST', '/api/logout')
  };
})();

// Datos que app.js lee de forma síncrona (misma forma que tenía el localStorage)
const cache = { students: [], visits: {}, messages: [] };

async function loadAll() {
  const [students, visits, messages] = await Promise.all([
    api.get('/api/students'),
    api.get('/api/visits'),
    api.get('/api/medication-requests')
  ]);
  cache.students = students;
  cache.visits = visits;
  cache.messages = messages;
}
async function refreshStudents() { cache.students = await api.get('/api/students'); }
