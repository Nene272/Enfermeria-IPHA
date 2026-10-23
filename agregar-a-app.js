
function renderAI() {
  const main = document.querySelector('.ai-main'), badge = document.querySelector('.page-heading .status'), intro = document.querySelector('.page-heading div p:not(.eyebrow)'), stepNote = document.querySelectorAll('.ai-step p')[2];
  if (intro) intro.textContent = 'Resume el historial de visitas o redacta solicitudes de medicamentos. Es una ayuda informativa: no diagnostica ni reemplaza al personal de enfermería.';
  if (stepNote) stepNote.textContent = 'Listo: la clave de la IA vive solo en el servidor Python, nunca en el navegador.';
  const setBadge = (text, ok) => { if (badge) { badge.textContent = text; badge.style.opacity = ok ? '1' : '.7' } };
  setBadge('Comprobando…', false);
  fetch('/api/ia/estado').then(response => response.json()).then(state => setBadge(state.key ? 'Conectado' : 'Falta la clave', state.key)).catch(() => setBadge('Servidor apagado', false));
  if (!['nurse', 'admin'].includes(role)) { main.innerHTML = '<span class="ai-symbol" aria-hidden="true">✧</span><h2>Función no disponible para este perfil</h2><p>El asistente usa el historial de visitas, que solo consultan Enfermería y Administración.</p>'; return }

  const list = students().slice().sort((a, b) => a.name.localeCompare(b.name, 'es'));
  main.style.justifyContent = 'flex-start';
  main.innerHTML = `<span class="ai-symbol" aria-hidden="true">✧</span><h2>Asistente de apoyo</h2>
    <p>Elige una tarea. Antes de enviar, puedes ver exactamente qué datos viajan a la IA (nunca el nombre ni la matrícula).</p>
    <div class="fields-grid" style="margin-top:16px;max-width:520px">
      <div class="field full"><label for="aiTask">¿Qué necesitas?</label><select id="aiTask"><option value="resumen">Resumir las visitas de un estudiante</option><option value="solicitud">Redactar una solicitud de medicamento</option></select></div>
      <div class="field full" id="aiStudentBox"><label for="aiStudent">Estudiante</label><select id="aiStudent"><option value="">${list.length ? 'Selecciona un estudiante' : 'No hay estudiantes registrados'}</option>${list.map(item => `<option value="${esc(item.id)}">${esc(item.name)} · ${esc(item.grade)}</option>`).join('')}</select></div>
      <div class="field full" id="aiMedBox" hidden><label for="aiMedication">Medicamento</label><input id="aiMedication" maxlength="100" placeholder="Ej.: Acetaminofén en tabletas" /></div>
      <div class="field" id="aiQtyBox" hidden><label for="aiQuantity">Cantidad</label><input id="aiQuantity" maxlength="60" placeholder="Ej.: 2 cajas" /></div>
      <div class="field full" id="aiContextBox" hidden><label for="aiContext">Contexto (opcional, sin nombres)</label><textarea id="aiContext" rows="3" maxlength="300" placeholder="Ej.: Se agotó el stock del mes."></textarea></div>
    </div>
    <details style="margin:12px 0;max-width:520px"><summary style="cursor:pointer;font-size:11px;color:#4b5a70">Ver exactamente qué se enviará</summary><pre id="aiPreview" style="white-space:pre-wrap;font-size:10px;margin:8px 0 0;padding:10px;background:#f1f4f8;border-radius:8px"></pre></details>
    <div><button class="btn" id="aiRun" type="button">Generar con IA</button></div>
    <div id="aiResult" aria-live="polite"></div>`;

  const $ = selector => main.querySelector(selector), task = $('#aiTask'), studentSelect = $('#aiStudent'), run = $('#aiRun'), result = $('#aiResult'), preview = $('#aiPreview');
  // Quita el nombre del estudiante si alguien lo escribió dentro del motivo de la visita
  const maskName = (text, name) => name.split(/\s+/).filter(word => word.length > 2).reduce((out, word) => out.replace(new RegExp(word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi'), '[estudiante]'), String(text || ''));
  const buildPayload = () => {
    if (task.value === 'resumen') {
      const student = students().find(item => item.id === studentSelect.value);
      if (!student) return null;
      const visits = (read(keys.visits, {})[student.id] || []).slice(0, 30).map(visit => ({ date: visit.date, reason: maskName(visit.reason, student.name), dispatched: Boolean(visit.dispatched) }));
      return { mode: 'resumen', grade: student.grade, age: student.age ?? null, visits };
    }
    return { mode: 'solicitud', medication: $('#aiMedication').value.trim(), quantity: $('#aiQuantity').value.trim(), context: $('#aiContext').value.trim() };
  };
  const sync = () => {
    const summary = task.value === 'resumen';
    $('#aiStudentBox').hidden = !summary;
    ['#aiMedBox', '#aiQtyBox', '#aiContextBox'].forEach(selector => { $(selector).hidden = summary });
    const payload = buildPayload();
    preview.textContent = payload ? JSON.stringify(payload, null, 2) : 'Selecciona un estudiante para ver los datos.';
  };
  main.addEventListener('input', sync); main.addEventListener('change', sync); sync();

  run.addEventListener('click', async () => {
    const payload = buildPayload();
    if (!payload) { notify('Selecciona un estudiante.'); return }
    if (payload.mode === 'resumen' && !payload.visits.length) { result.innerHTML = '<p style="margin-top:14px">Este estudiante no tiene visitas registradas.</p>'; return }
    if (payload.mode === 'solicitud' && !payload.medication) { notify('Escribe el medicamento.'); return }
    run.disabled = true; run.textContent = 'Generando…'; result.innerHTML = '<p style="margin-top:14px">Consultando a la IA…</p>';
    try {
      const response = await fetch('/api/ia', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(data.error || 'La IA no respondió.');
      result.innerHTML = `<div style="margin-top:14px;padding:14px;border:1px solid var(--line);border-radius:9px;background:#fff;font-size:12px;line-height:1.6;white-space:pre-wrap">${esc(data.text)}</div><button class="btn secondary" id="aiCopy" type="button" style="margin-top:10px">Copiar texto</button>`;
      $('#aiCopy').addEventListener('click', () => navigator.clipboard.writeText(data.text).then(() => notify('Texto copiado')));
      audit('Usó la IA', payload.mode === 'resumen' ? 'Resumen de visitas' : 'Redacción de solicitud de medicamento');
    } catch (error) {
      const offline = error instanceof TypeError;
      result.innerHTML = `<p role="alert" style="margin-top:14px;color:#b42318">${esc(offline ? 'No se pudo conectar con el servidor Python. Verifica que esté encendido (python servidor.py) y que abriste la página desde http://localhost:5000.' : error.message)}</p>`;
    } finally { run.disabled = false; run.textContent = 'Generar con IA' }
  });
}
