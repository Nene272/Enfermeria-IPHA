// Cargar DESPUÉS de app.js en integracion-ia.html:  <script src="ia.js" defer></script>
(() => {
  const main = document.querySelector('.ai-main');
  if (!main) return;
  main.innerHTML = `
    <h2>Asistente de apoyo</h2>
    <p class="panel-subtitle">Orientación general. No diagnostica ni indica dosis. No escribas nombres ni teléfonos.</p>
    <div id="aiLog" style="max-height:340px;overflow:auto;display:grid;gap:.6rem;margin:1rem 0"></div>
    <form id="aiForm" style="display:grid;gap:.6rem">
      <textarea id="aiInput" maxlength="1500" required placeholder="Ej: ¿Qué hago ante un esguince leve mientras llega la familia?"></textarea>
      <button class="btn" id="aiSend" type="submit">Enviar</button>
    </form>`;
  const log = main.querySelector('#aiLog'), form = main.querySelector('#aiForm'),
        input = main.querySelector('#aiInput'), send = main.querySelector('#aiSend');
  const history = [];

  function bubble(who, text) {
    const div = document.createElement('div');
    div.className = 'callout';
    const strong = document.createElement('strong');
    strong.textContent = who === 'user' ? 'Tú: ' : 'Asistente: ';
    div.append(strong, document.createTextNode(text)); // textContent => sin XSS
    log.append(div); log.scrollTop = log.scrollHeight;
  }

  form.addEventListener('submit', async e => {
    e.preventDefault();
    const text = input.value.trim(); if (!text) return;
    bubble('user', text); history.push({ role: 'user', content: text });
    input.value = ''; send.disabled = true; send.textContent = 'Pensando…';
    try {
      const { answer } = await api.post('/api/ai/chat', { messages: history });
      history.push({ role: 'assistant', content: answer }); bubble('assistant', answer);
    } catch (err) { bubble('assistant', '⚠ ' + err.message); history.pop(); }
    send.disabled = false; send.textContent = 'Enviar';
  });
})();
