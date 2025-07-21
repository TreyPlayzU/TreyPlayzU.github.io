document.addEventListener('DOMContentLoaded', function() {
  const mainImage = document.getElementById('mainImage');
  const thumbnails = document.querySelectorAll('.product-thumbnail');
  const prevBtn = document.getElementById('prevImage');
  const nextBtn = document.getElementById('nextImage');
  const imageModal = document.getElementById('imageModal');
  const modalImage = document.getElementById('modalImage');
  const closeImageModal = document.getElementById('closeImageModal');

  if (!mainImage) return;

  const images = Array.from(thumbnails).map(thumb => thumb.dataset.image);
  let currentImageIndex = 0;

  function updateGallery(index) {
    mainImage.src = images[index];
    
    thumbnails.forEach((thumb, i) => {
      if (i === index) {
        thumb.classList.add('active');
      } else {
        thumb.classList.remove('active');
      }
    });
  }
  
  thumbnails.forEach((thumb, index) => {
    thumb.addEventListener('click', function() {
      currentImageIndex = index;
      updateGallery(currentImageIndex);
    });
  });
  
  prevBtn?.addEventListener('click', function() {
    currentImageIndex = (currentImageIndex - 1 + images.length) % images.length;
    updateGallery(currentImageIndex);
  });
  
  nextBtn?.addEventListener('click', function() {
    currentImageIndex = (currentImageIndex + 1) % images.length;
    updateGallery(currentImageIndex);
  });
  
  // Keyboard navigation
  document.addEventListener('keydown', function(e) {
    if (e.key === 'ArrowLeft') {
      currentImageIndex = (currentImageIndex - 1 + images.length) % images.length;
      updateGallery(currentImageIndex);
    } else if (e.key === 'ArrowRight') {
      currentImageIndex = (currentImageIndex + 1) % images.length;
      updateGallery(currentImageIndex);
    }
  });

  // Image modal
  const pcImages = document.querySelectorAll('.product-main-image img, .product-thumbnail img');
  pcImages.forEach(img => {
    img.style.cursor = 'pointer';
    img.addEventListener('click', function() {
      modalImage.src = this.src;
      imageModal.classList.add('active');
      document.body.style.overflow = 'hidden';
    });
  });
  
  closeImageModal?.addEventListener('click', function() {
    imageModal.classList.remove('active');
    document.body.style.overflow = '';
  });

  window.addEventListener('click', function(e) {
    if (e.target === imageModal) {
      imageModal.classList.remove('active');
      document.body.style.overflow = '';
    }
  });
});
