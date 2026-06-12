'use strict';
'use client';

import React, { createContext, useContext, useState, useEffect } from 'react';

export interface Garment {
  id: string;
  name: string;
  category: 'men' | 'women' | 'household' | 'bedding';
  rates: {
    [key: string]: number; // rates for wash-fold, wash-iron, steam-iron, dry-clean
  };
}

export interface CartItem {
  garmentId: string;
  garmentName: string;
  serviceType: string; // 'wash-fold' | 'wash-iron' | 'steam-iron' | 'dry-clean'
  quantity: number;
  rate: number;
}

export interface SchedulingDetails {
  pickupDate: string;
  pickupSlot: string;
  deliveryDate: string;
  deliverySlot: string;
  isSprint: boolean;
}

export interface AddressDetails {
  fullName: string;
  phone: string;
  pincode: string;
  addressLine: string;
  landmark: string;
  city: string;
}

interface CartContextType {
  cartItems: CartItem[];
  selectedService: string;
  setSelectedService: (service: string) => void;
  addToCart: (garment: Garment, serviceType: string) => void;
  removeFromCart: (garmentId: string, serviceType: string) => void;
  updateQuantity: (garmentId: string, serviceType: string, quantity: number) => void;
  clearCart: () => void;
  cartTotal: number;
  cartCount: number;
  scheduling: SchedulingDetails;
  setScheduling: (details: SchedulingDetails) => void;
  address: AddressDetails;
  setAddress: (details: AddressDetails) => void;
  orderId: string;
  setOrderId: (id: string) => void;
}

const CartContext = createContext<CartContextType | undefined>(undefined);

export const SERVICES_META = {
  'wash-fold': { name: 'Wash & Fold', color: 'var(--color-wash-fold)', rateKey: 'wash-fold' },
  'wash-iron': { name: 'Wash & Iron', color: 'var(--color-wash-iron)', rateKey: 'wash-iron' },
  'steam-iron': { name: 'Steam Ironing', color: 'var(--color-steam-iron)', rateKey: 'steam-iron' },
  'dry-clean': { name: 'Dry Cleaning', color: 'var(--color-dry-clean)', rateKey: 'dry-clean' },
  'sprint': { name: 'Sprint Delivery', color: 'var(--color-express-sprint)', rateKey: 'sprint' },
};

export const GARMENTS_DATABASE: Garment[] = [
  // Men
  { id: 'm1', name: 'Shirt', category: 'men', rates: { 'wash-fold': 20, 'wash-iron': 30, 'steam-iron': 15, 'dry-clean': 70 } },
  { id: 'm2', name: 'T-Shirt', category: 'men', rates: { 'wash-fold': 18, 'wash-iron': 28, 'steam-iron': 12, 'dry-clean': 60 } },
  { id: 'm3', name: 'Trousers/Jeans', category: 'men', rates: { 'wash-fold': 25, 'wash-iron': 38, 'steam-iron': 18, 'dry-clean': 80 } },
  { id: 'm4', name: 'Suit (2-Piece)', category: 'men', rates: { 'wash-fold': 80, 'wash-iron': 120, 'steam-iron': 60, 'dry-clean': 220 } },
  { id: 'm5', name: 'Kurta', category: 'men', rates: { 'wash-fold': 25, 'wash-iron': 35, 'steam-iron': 20, 'dry-clean': 90 } },
  // Women
  { id: 'w1', name: 'Dress', category: 'women', rates: { 'wash-fold': 30, 'wash-iron': 45, 'steam-iron': 25, 'dry-clean': 110 } },
  { id: 'w2', name: 'Saree', category: 'women', rates: { 'wash-fold': 50, 'wash-iron': 80, 'steam-iron': 40, 'dry-clean': 180 } },
  { id: 'w3', name: 'Kurti', category: 'women', rates: { 'wash-fold': 22, 'wash-iron': 32, 'steam-iron': 18, 'dry-clean': 80 } },
  { id: 'w4', name: 'Jeans/Trousers', category: 'women', rates: { 'wash-fold': 25, 'wash-iron': 38, 'steam-iron': 18, 'dry-clean': 80 } },
  { id: 'w5', name: 'Skirt', category: 'women', rates: { 'wash-fold': 25, 'wash-iron': 35, 'steam-iron': 18, 'dry-clean': 80 } },
  // Household
  { id: 'h1', name: 'Bedspread (Single)', category: 'household', rates: { 'wash-fold': 60, 'wash-iron': 90, 'steam-iron': 40, 'dry-clean': 150 } },
  { id: 'h2', name: 'Bedspread (Double)', category: 'household', rates: { 'wash-fold': 90, 'wash-iron': 130, 'steam-iron': 60, 'dry-clean': 220 } },
  { id: 'h3', name: 'Curtain', category: 'household', rates: { 'wash-fold': 80, 'wash-iron': 120, 'steam-iron': 50, 'dry-clean': 200 } },
  { id: 'h4', name: 'Towel', category: 'household', rates: { 'wash-fold': 20, 'wash-iron': 30, 'steam-iron': 10, 'dry-clean': 50 } },
  // Bedding
  { id: 'b1', name: 'Blanket (Single)', category: 'bedding', rates: { 'wash-fold': 120, 'wash-iron': 150, 'steam-iron': 80, 'dry-clean': 250 } },
  { id: 'b2', name: 'Blanket (Double)', category: 'bedding', rates: { 'wash-fold': 180, 'wash-iron': 240, 'steam-iron': 120, 'dry-clean': 380 } },
  { id: 'b3', name: 'Pillow Cover', category: 'bedding', rates: { 'wash-fold': 15, 'wash-iron': 25, 'steam-iron': 10, 'dry-clean': 40 } },
];

export const CartProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [cartItems, setCartItems] = useState<CartItem[]>([]);
  const [selectedService, setSelectedService] = useState<string>('wash-fold');
  const [orderId, setOrderId] = useState<string>('');
  
  const [scheduling, setSchedulingState] = useState<SchedulingDetails>({
    pickupDate: '',
    pickupSlot: '',
    deliveryDate: '',
    deliverySlot: '',
    isSprint: false,
  });

  const [address, setAddressState] = useState<AddressDetails>({
    fullName: '',
    phone: '',
    pincode: '',
    addressLine: '',
    landmark: '',
    city: 'Patna',
  });

  // Load from local storage on mount
  useEffect(() => {
    const storedCart = localStorage.getItem('fw_cart');
    const storedService = localStorage.getItem('fw_service');
    const storedScheduling = localStorage.getItem('fw_scheduling');
    const storedAddress = localStorage.getItem('fw_address');
    const storedOrderId = localStorage.getItem('fw_order_id');

    if (storedCart) {
      try {
        setCartItems(JSON.parse(storedCart));
      } catch (e) {
        console.error(e);
      }
    }
    if (storedService) {
      setSelectedService(storedService);
    }
    if (storedScheduling) {
      try {
        setSchedulingState(JSON.parse(storedScheduling));
      } catch (e) {}
    }
    if (storedAddress) {
      try {
        setAddressState(JSON.parse(storedAddress));
      } catch (e) {}
    }
    if (storedOrderId) {
      setOrderId(storedOrderId);
    }
  }, []);

  const saveCart = (items: CartItem[]) => {
    setCartItems(items);
    localStorage.setItem('fw_cart', JSON.stringify(items));
  };

  const addToCart = (garment: Garment, serviceType: string) => {
    const rate = garment.rates[serviceType] || 0;
    const existingIndex = cartItems.findIndex(
      (item) => item.garmentId === garment.id && item.serviceType === serviceType
    );

    if (existingIndex > -1) {
      const updated = [...cartItems];
      updated[existingIndex].quantity += 1;
      saveCart(updated);
    } else {
      saveCart([
        ...cartItems,
        {
          garmentId: garment.id,
          garmentName: garment.name,
          serviceType,
          quantity: 1,
          rate,
        },
      ]);
    }
  };

  const removeFromCart = (garmentId: string, serviceType: string) => {
    const updated = cartItems.filter(
      (item) => !(item.garmentId === garmentId && item.serviceType === serviceType)
    );
    saveCart(updated);
  };

  const updateQuantity = (garmentId: string, serviceType: string, quantity: number) => {
    if (quantity <= 0) {
      removeFromCart(garmentId, serviceType);
      return;
    }
    const updated = cartItems.map((item) => {
      if (item.garmentId === garmentId && item.serviceType === serviceType) {
        return { ...item, quantity };
      }
      return item;
    });
    saveCart(updated);
  };

  const clearCart = () => {
    saveCart([]);
    setSchedulingState({
      pickupDate: '',
      pickupSlot: '',
      deliveryDate: '',
      deliverySlot: '',
      isSprint: false,
    });
    localStorage.removeItem('fw_scheduling');
  };

  const setScheduling = (details: SchedulingDetails) => {
    setSchedulingState(details);
    localStorage.setItem('fw_scheduling', JSON.stringify(details));
  };

  const setAddress = (details: AddressDetails) => {
    setAddressState(details);
    localStorage.setItem('fw_address', JSON.stringify(details));
  };

  const handleSetOrderId = (id: string) => {
    setOrderId(id);
    if (id) {
      localStorage.setItem('fw_order_id', id);
    } else {
      localStorage.removeItem('fw_order_id');
    }
  };

  const cartTotal = cartItems.reduce((acc, item) => {
    let price = item.quantity * item.rate;
    if (scheduling.isSprint) {
      // Sprint has a 1.5x speed premium
      price = price * 1.5;
    }
    return acc + price;
  }, 0);

  const cartCount = cartItems.reduce((acc, item) => acc + item.quantity, 0);

  return (
    <CartContext.Provider
      value={{
        cartItems,
        selectedService,
        setSelectedService: (service) => {
          setSelectedService(service);
          localStorage.setItem('fw_service', service);
        },
        addToCart,
        removeFromCart,
        updateQuantity,
        clearCart,
        cartTotal,
        cartCount,
        scheduling,
        setScheduling,
        address,
        setAddress,
        orderId,
        setOrderId: handleSetOrderId,
      }}
    >
      {children}
    </CartContext.Provider>
  );
};

export const useCart = () => {
  const context = useContext(CartContext);
  if (context === undefined) {
    throw new Error('useCart must be used within a CartProvider');
  }
  return context;
};
