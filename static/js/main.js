(function(){
'use strict';
document.addEventListener('DOMContentLoaded',function(){
  // Mobile Menu
  var btn=document.querySelector('[data-menu-toggle]');
  var menu=document.querySelector('[data-menu]');
  if(btn&&menu){
    btn.addEventListener('click',function(){
      menu.classList.toggle('open');
      var isOpen=menu.classList.contains('open');
      btn.setAttribute('aria-expanded',isOpen);
    });
    menu.querySelectorAll('a').forEach(function(l){
      l.addEventListener('click',function(){
        menu.classList.remove('open');
        btn.setAttribute('aria-expanded','false');
      });
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
      // For now, show success (backend connection in next step)
      setTimeout(function(){
        form.innerHTML='<div class="text-center py-8"><p class="text-xl font-semibold mb-2" style="color:hsl(84,75%,45%)">Bedankt voor uw aanvraag!</p><p class="text-gray-600">Wij nemen zo snel mogelijk contact met u op.</p></div>';
      }, 500);
    });
  }

  // Service Selector (energielabel page)
  var selector=document.querySelector('[data-service-selector]');
  if(selector){
    var cards=selector.querySelectorAll('[data-option]');
    cards.forEach(function(card){
      card.addEventListener('click',function(){
        // Remove active from siblings
        card.parentElement.querySelectorAll('[data-option]').forEach(function(c){
          c.classList.remove('ring-2','ring-green-500','bg-green-50');
          c.classList.add('bg-white');
        });
        // Add active to clicked
        card.classList.add('ring-2','ring-green-500','bg-green-50');
        card.classList.remove('bg-white');
      });
    });
  }
});
})();
