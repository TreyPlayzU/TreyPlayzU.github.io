// cart.js
const Cart = {
  getCart: function() {
    return JSON.parse(localStorage.getItem('cart')) || {};
  },
  
  addItem: function(product) {
    const cart = this.getCart();
    if (cart[product.id]) {
      cart[product.id].quantity += product.quantity || 1;
    } else {
      cart[product.id] = {...product, quantity: product.quantity || 1};
    }
    this.saveCart(cart);
  },
  
  removeItem: function(productId) {
    const cart = this.getCart();
    delete cart[productId];
    this.saveCart(cart);
  },
  
  updateQuantity: function(productId, quantity) {
    const cart = this.getCart();
    if (cart[productId]) {
      cart[productId].quantity = quantity;
      this.saveCart(cart);
    }
  },
  
  getCount: function() {
    const cart = this.getCart();
    return Object.values(cart).reduce((sum, item) => sum + item.quantity, 0);
  },
  
  saveCart: function(cart) {
    localStorage.setItem('cart', JSON.stringify(cart));
    this.updateCartCount();
  },
  
  updateCartCount: function() {
    const count = this.getCount();
    const countElements = document.querySelectorAll('.cart-count');
    countElements.forEach(el => el.textContent = count);
  }
};
