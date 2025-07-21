document.addEventListener('DOMContentLoaded', function() {
  const settingsToggle = document.getElementById('settingsToggle');
  const settingsPanel = document.getElementById('settingsPanel');
  const closeSettings = document.getElementById('closeSettings');
  const resetSettingsBtn = document.getElementById('resetSettings');
  const themeRadios = document.querySelectorAll('input[name="theme"]');
  const animationsToggle = document.getElementById('animationsToggle');
  const html = document.documentElement;
  const overlay = document.getElementById('overlay');

  function loadTheme() {
    const savedTheme = localStorage.getItem('theme') || 'dark';
    html.setAttribute('data-theme', savedTheme);
    document.querySelector(`input[value="${savedTheme}"]`).checked = true;
    document.body.style.backgroundBlendMode = savedTheme === 'dark' ? 'overlay' : 'soft-light';
  }

  function loadAnimations() {
    const animationsEnabled = localStorage.getItem('animations') !== 'false';
    animationsToggle.checked = animationsEnabled;
    
    if (!animationsEnabled) {
      document.body.style.animation = 'none';
      document.querySelectorAll('*').forEach(el => {
        el.style.animation = 'none';
      });
    }
  }

  // Toggle settings panel
  settingsToggle?.addEventListener('click', function(e) {
    e.preventDefault();
    settingsPanel.classList.toggle('active');
    overlay.classList.toggle('active');
    document.body.style.overflow = settingsPanel.classList.contains('active') ? 'hidden' : '';
  });

  closeSettings?.addEventListener('click', function() {
    settingsPanel.classList.remove('active');
    overlay.classList.remove('active');
    document.body.style.overflow = '';
  });

  // Theme management
  themeRadios.forEach(radio => {
    radio.addEventListener('change', (e) => {
      const theme = e.target.value;
      html.setAttribute('data-theme', theme);
      localStorage.setItem('theme', theme);
      document.body.style.backgroundBlendMode = theme === 'dark' ? 'overlay' : 'soft-light';
    });
  });

  // Animations toggle
  animationsToggle?.addEventListener('change', (e) => {
    localStorage.setItem('animations', e.target.checked);
    
    if (!e.target.checked) {
      document.body.style.animation = 'none';
      document.querySelectorAll('*').forEach(el => {
        el.style.animation = 'none';
      });
    } else {
      document.body.style.animation = '';
      document.querySelectorAll('*').forEach(el => {
        el.style.animation = '';
      });
    }
  });

  // Reset settings
  resetSettingsBtn?.addEventListener('click', function() {
    localStorage.removeItem('theme');
    localStorage.removeItem('animations');
    loadTheme();
    loadAnimations();
  });

  // Initialize
  loadTheme();
  loadAnimations();
});
