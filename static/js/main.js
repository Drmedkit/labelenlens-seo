(function(){
'use strict';
document.addEventListener('DOMContentLoaded',function(){
  // Mobile Menu
  var btn=document.querySelector('[data-menu-toggle]');
  var menu=document.querySelector('[data-menu]');
  if(btn&&menu){
    btn.addEventListener('click',function(){
      var open=!menu.classList.toggle('hidden');
      btn.setAttribute('aria-expanded',open);
    });
    menu.querySelectorAll('a').forEach(function(l){
      l.addEventListener('click',function(){menu.classList.add('hidden');btn.setAttribute('aria-expanded','false');});
    });
  }
  // Contact Form
  var form=document.querySelector('[data-contact-form]');
  if(form){
    form.addEventListener('submit',function(e){
      e.preventDefault();
      var b=form.querySelector('button[type="submit"]');
      var t=b.textContent;b.textContent='Verzenden...';b.disabled=true;
      var d=new FormData(form);var o={};d.forEach(function(v,k){o[k]=v;});
      fetch(form.action||'#',{method:'POST',mode:'no-cors',headers:{'Content-Type':'application/json'},body:JSON.stringify(o)})
      .then(function(){form.innerHTML='<div class="text-center py-8"><p class="text-xl font-semibold text-green-600 mb-2">Bedankt voor uw aanvraag!</p><p class="text-gray-600">Wij nemen zo snel mogelijk contact met u op.</p></div>';})
      .catch(function(){b.textContent=t;b.disabled=false;alert('Er ging iets mis. Bel ons op +31 6 43 73 57 19.');});
    });
  }
});
})();
