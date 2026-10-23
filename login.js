// These mock credentials are for the local prototype only, not real authentication.
// TODO Flask/MySQL: validate credentials server-side and issue a secure session cookie.
const demoAccounts=[
  {password:'Demo-Enfermeria-26',role:'nurse'},
  {password:'Demo-Orientacion-26',role:'guidance'},
  {password:'Demo-Admin-26',role:'admin'}
];
const loginForm=document.querySelector('#loginForm');
const roleSelect=loginForm?.elements.role;
const passwordInput=loginForm?.elements.password;
const feedback=document.querySelector('#loginFeedback');

// A login page must never leave a previous demo role active after a failed attempt.
localStorage.removeItem('ipha-role-v2');
localStorage.removeItem('ipha-demo-session-v1');

passwordInput?.addEventListener('input',()=>{
  const account=demoAccounts.find(item=>item.password===passwordInput.value);
  if(account)roleSelect.value=account.role;
});

loginForm?.addEventListener('submit',event=>{
  event.preventDefault();
  const account=demoAccounts.find(item=>item.role===roleSelect.value&&item.password===passwordInput.value);
  if(!account){
    localStorage.removeItem('ipha-role-v2');
    localStorage.removeItem('ipha-demo-session-v1');
    feedback.textContent='La contraseña no corresponde al rol seleccionado. Verifica los datos de prueba.';
    feedback.hidden=false;
    return;
  }
  localStorage.setItem('ipha-role-v2',account.role);
  localStorage.setItem('ipha-demo-session-v1','true');
  const destination=new URL('index.html',location.href);
  if(location.protocol==='file:')destination.searchParams.set('demoRole',account.role);
  location.replace(destination.href);
});
