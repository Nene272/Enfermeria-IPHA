// api.js — reemplaza el localStorage por el servidor Flask (que guarda en MySQL).
// app.js sigue usando read()/write() como antes; aquí se traducen a llamadas /api/...
// Debe cargarse ANTES de app.js.
(() => {
  const K = { students: 'ipha-students-v2', visits: 'ipha-visits-v2', messages: 'ipha-messages-v2', audit: 'ipha-audit-v2', archive: 'ipha-archive-v2' };
  const CLIENT_AUDIT = ['Consultó mensajes', 'Consultó visitas', 'Usó la IA'];   // el resto lo registra el servidor al guardar
  const cache = {}, messageIds = {}, postedVisits = new Set();
  let queue = Promise.resolve(), pendingOps = [];

  async function call(method, url, body) {
    let response;
    try {
      response = await fetch(url, { method, credentials: 'same-origin', keepalive: method !== 'GET', headers: { 'Content-Type': 'application/json' }, body: body === undefined ? undefined : JSON.stringify(body) });
    } catch {
      const error = new Error('No se pudo conectar con el servidor. Verifica que esté encendido (python servidor.py).');
      error.status = 0; throw error;
    }
    const data = await response.json().catch(() => ({}));
    if (!response.ok) { const error = new Error(data.error || 'Error del servidor.'); error.status = response.status; throw error }
    return data;
  }

  // Las escrituras van en fila para que "crear" siempre termine antes que "editar".
  function enqueue(task) {
    const operation = queue.then(task);
    queue = operation.catch(() => {});
    operation.catch(error => {
      if (error.status === 401) { location.replace('login.html'); return }
      if (typeof notify === 'function') notify('No se pudo guardar: ' + error.message);
      setTimeout(() => location.reload(), 2500);        // vuelve a cargar lo que realmente quedó en la base
    });
    pendingOps.push(operation);
  }

  function syncStudents(before, after) {
    const previous = new Map((before || []).map(student => [student.id, student]));
    for (const student of after) {
      const old = previous.get(student.id), { infoHistory = [], ...fields } = student;
      if (!old) { enqueue(() => call('POST', '/api/estudiantes', fields)); continue }
      if (JSON.stringify(old) === JSON.stringify(student)) continue;
      const known = new Set((old.infoHistory || []).map(note => note.id));
      const newNotes = infoHistory.filter(note => !known.has(note.id)).map(note => note.text);
      enqueue(() => call('PUT', '/api/estudiantes/' + encodeURIComponent(student.id), { ...fields, newNotes }));
    }
  }

  function syncVisits(before, after) {
    for (const [studentId, list] of Object.entries(after)) for (const visit of list) {
      if (visit.id != null || postedVisits.has(visit.recordedAt)) continue;
      postedVisits.add(visit.recordedAt);
      enqueue(() => call('POST', '/api/visitas', { student: studentId, date: visit.date, time: visit.time, reason: visit.reason, dispatched: visit.dispatched }));
    }
  }

  function syncMessages(before, after) {
    const previous = new Map((before || []).map(message => [message.id, message]));
    for (const message of after) {
      const old = previous.get(message.id);
      if (!old) {
        enqueue(async () => { const result = await call('POST', '/api/solicitudes', { to: message.to, medication: message.medication, presentation: message.presentation, quantityRequested: message.quantityRequested, body: message.body }); messageIds[message.id] = result.id });
      } else if (old.status === 'Pendiente' && message.status !== 'Pendiente') {
        enqueue(() => call('PUT', '/api/solicitudes/' + (messageIds[message.id] || message.id), { status: message.status, quantityDelivered: message.quantityDelivered, responseNote: message.responseNote }));
      }
    }
  }

  window.ipha = {
    async start() {
      const data = await call('GET', '/api/datos');
      cache[K.students] = data.students; cache[K.visits] = data.visits; cache[K.messages] = data.messages;
      cache[K.audit] = data.audit; cache[K.archive] = data.archive;
      return { role: data.role };
    },
    read(key, fallback) { const value = cache[key]; return value === undefined || value === null ? fallback : structuredClone(value) },
    write(key, value) {
      const before = cache[key]; cache[key] = structuredClone(value);
      if (key === K.students) syncStudents(before, value);
      else if (key === K.visits) syncVisits(before, value);
      else if (key === K.messages) syncMessages(before, value);
      // auditoría y archivo los escribe únicamente el servidor
    },
    flush() { const operations = pendingOps; pendingOps = []; return Promise.all(operations) },     // espera a que todo se guarde
    audit(action, detail) { if (CLIENT_AUDIT.includes(action)) call('POST', '/api/auditoria', { action, detail }).catch(() => {}) },
    async archive(id) { await queue; return call('POST', '/api/estudiantes/' + encodeURIComponent(id) + '/archivar', {}) },
    async closeYear(graduateGrade) { await queue; return call('POST', '/api/cierre', { graduateGrade }) },
    logout() { return call('POST', '/api/logout', {}).catch(() => {}) },
    async login(role, password) { return call('POST', '/api/login', { role, password }) },
  };
})();
