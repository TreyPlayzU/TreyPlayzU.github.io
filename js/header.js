document.addEventListener('DOMContentLoaded', function() {
  const header = document.getElementById('mainHeader');
  const menuToggle = document.getElementById('menuToggle');
  const mainNav = document.getElementById('mainNav');
  const overlay = document.getElementById('overlay');

  // Scroll header effect
  window.addEventListener('scroll', function() {
    if (window.scrollY > 50) {
      header?.classList.add('scrolled');
    } else {
      header?.classList.remove('scrolled');
    }
  });

  // Mobile menu toggle
  menuToggle?.addEventListener('click', function() {
    mainNav.classList.toggle('active');
    overlay.classList.toggle('active');
    document.body.style.overflow = mainNav.classList.contains('active') ? 'hidden' : '';
    menuToggle.innerHTML = mainNav.classList.contains('active') ? 
      '<i class="fas fa-times"></i>' : '<i class="fas fa-bars"></i>';
  });
  
  overlay?.addEventListener('click', function() {
    mainNav.classList.remove('active');
    overlay.classList.remove('active');
    document.body.style.overflow = '';
    menuToggle.innerHTML = '<i class="fas fa-bars"></i>';
  });

  // Smooth scrolling for anchor links
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function(e) {
      if (this.getAttribute('href') !== '#') {
        e.preventDefault();
        
        const targetId = this.getAttribute('href');
        const targetElement = document.querySelector(targetId);
        
        if (targetElement) {
          if (mainNav.classList.contains('active')) {
            mainNav.classList.remove('active');
            overlay.classList.remove('active');
            document.body.style.overflow = '';
            menuToggle.innerHTML = '<i class="fas fa-bars"></i>';
          }
          
          window.scrollTo({
            top: targetElement.offsetTop - 80,
            behavior: 'smooth'
          });
        }
      }
    });
  });
});
