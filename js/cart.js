document.addEventListener('DOMContentLoaded', function() {
  function updateCartCount() {
    const cartItems = localStorage.getItem('cartItems') ? parseInt(localStorage.getItem('cartItems')) : 0;
    const cartCount = document.getElementById('cartCount');
    if (cartCount) cartCount.textContent = cartItems;
  }
  
  updateCartCount();
  
  const ctaButtons = document.querySelectorAll('.action-buttons .btn');
  ctaButtons.forEach(button => {
    button.addEventListener('click', function(e) {
      if (this.getAttribute('href') === 'cart.html') {
        e.preventDefault();
        const product = {
          id: 'frostbyte-x',
          name: 'FrostByte X',
          price: 799.99,
          image: 'images/frostbyte1.jpg',
          quantity: 1,
          specs: [
            'Intel Core i3-12100F',
            'NVIDIA GTX 1660 Super 6GB',
            '16GB DDR4 3200MHz', 
            '512GB NVMe SSD'
          ]
        };
        
        let cart = JSON.parse(localStorage.getItem('cart')) || {};
        if (cart[product.id]) {
          cart[product.id].quantity += 1;
        } else {
          cart[product.id] = product;
        }
        
        localStorage.setItem('cart', JSON.stringify(cart));
        localStorage.setItem('cartItems', Object.values(cart).reduce((acc, item) => acc + item.quantity, 0));
        updateCartCount();
        
        alert(`${product.name} has been added to your cart!`);
      }
    });
  });
});
