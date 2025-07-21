document.addEventListener('DOMContentLoaded', function() {
  const benchmarkModal = document.getElementById('benchmarkModal');
  const closeBenchmarkModal = document.getElementById('closeBenchmarkModal');
  const benchmarkModalTitle = document.getElementById('benchmarkModalTitle');
  const benchmarkModalResult = document.getElementById('benchmarkModalResult');
  const benchmarkModalDetails = document.getElementById('benchmarkModalDetails');
  const benchmarkCards = document.querySelectorAll('.benchmark-card');

  if (!benchmarkModal) return;

  const benchmarkDetails = {
    timespy: {
      title: "3DMARK TIME SPY DETAILS",
      result: "5,850 Points",
      details: "The FrostByte X scores 5,850 in 3DMark Time Spy, which indicates excellent performance for 1080p gaming..."
    },
    cinebench: {
      title: "CINEBENCH R23 DETAILS",
      result: "7,420 Points",
      details: "With a Cinebench R23 multi-core score of 7,420, the FrostByte X handles productivity tasks with ease..."
    },
    gaming1080: {
      title: "1080P GAMING PERFORMANCE",
      result: "100+ FPS",
      details: "At 1920×1080 resolution, the FrostByte X delivers exceptional frame rates..."
    },
    gaming1440: {
      title: "1440P GAMING PERFORMANCE",
      result: "60+ FPS",
      details: "At 2560×1440 resolution, the FrostByte X still delivers playable frame rates..."
    }
  };

  benchmarkCards.forEach(card => {
    card.style.cursor = 'pointer';
    card.addEventListener('click', function() {
      const benchmarkType = this.getAttribute('data-benchmark');
      const benchmarkData = benchmarkDetails[benchmarkType];
      
      benchmarkModalTitle.textContent = benchmarkData.title;
      benchmarkModalResult.textContent = benchmarkData.result;
      benchmarkModalDetails.innerHTML = benchmarkData.details;
      
      benchmarkModal.classList.add('active');
      document.body.style.overflow = 'hidden';
    });
  });
  
  closeBenchmarkModal?.addEventListener('click', function() {
    benchmarkModal.classList.remove('active');
    document.body.style.overflow = '';
  });

  window.addEventListener('click', function(e) {
    if (e.target === benchmarkModal) {
      benchmarkModal.classList.remove('active');
      document.body.style.overflow = '';
    }
  });
});
