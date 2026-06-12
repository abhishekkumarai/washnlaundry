'use strict';
'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useCart, GARMENTS_DATABASE, SERVICES_META } from '../../context/CartContext';
import styles from './page.module.css';

export default function ServicesPage() {
  const router = useRouter();
  const {
    cartItems,
    selectedService,
    setSelectedService,
    addToCart,
    updateQuantity,
    cartTotal,
    cartCount,
  } = useCart();

  const [activeCategory, setActiveCategory] = useState<'men' | 'women' | 'household' | 'bedding'>('men');

  // Filter garments based on active category
  const filteredGarments = GARMENTS_DATABASE.filter((g) => g.category === activeCategory);

  const serviceTabs = [
    { key: 'wash-fold', name: 'Wash & Fold', icon: '🧺', color: 'var(--color-wash-fold)', bg: 'rgba(0, 116, 188, 0.08)' },
    { key: 'wash-iron', name: 'Wash & Iron', icon: '👕', color: 'var(--color-wash-iron)', bg: 'rgba(198, 62, 150, 0.08)' },
    { key: 'steam-iron', name: 'Steam Ironing', icon: '💨', color: 'var(--color-steam-iron)', bg: 'rgba(104, 80, 161, 0.08)' },
    { key: 'dry-clean', name: 'Dry Cleaning', icon: '✨', color: 'var(--color-dry-clean)', bg: 'rgba(0, 149, 153, 0.08)' },
  ];

  const categories = [
    { key: 'men', name: 'Men\'s Wear' },
    { key: 'women', name: 'Women\'s Wear' },
    { key: 'household', name: 'Household' },
    { key: 'bedding', name: 'Bedding & Linen' },
  ];

  return (
    <div>
      {/* Page Header */}
      <section className={styles.headerSection}>
        <div className="container">
          <h1 className={styles.title}>Services &amp; Pricing Estimator</h1>
          <p className={styles.subtitle}>
            Explore our rates, select your garments, and calculate an estimate before placing your order.
          </p>

          {/* Service Tabs */}
          <div className={styles.serviceSelector}>
            {serviceTabs.map((tab) => {
              const isActive = selectedService === tab.key;
              return (
                <button
                  key={tab.key}
                  className={`${styles.serviceTabBtn} ${isActive ? styles.activeServiceTabBtn : ''}`}
                  onClick={() => setSelectedService(tab.key)}
                  style={
                    {
                      '--tab-accent': tab.color,
                      '--tab-accent-bg': tab.bg,
                    } as React.CSSProperties
                  }
                >
                  <span className={styles.tabIcon}>{tab.icon}</span>
                  <span>{tab.name}</span>
                </button>
              );
            })}
          </div>
        </div>
      </section>

      {/* Main Grid Content */}
      <section className="container">
        <div className={styles.layoutGrid}>
          {/* Garments Picker Panel */}
          <div className={styles.garmentsPanel}>
            <div className={styles.categoryNav}>
              {categories.map((cat) => (
                <button
                  key={cat.key}
                  className={`${styles.categoryBtn} ${activeCategory === cat.key ? styles.activeCategoryBtn : ''}`}
                  onClick={() => setActiveCategory(cat.key as any)}
                >
                  {cat.name}
                </button>
              ))}
            </div>

            <div className={styles.itemList}>
              {filteredGarments.map((garment) => {
                const rate = garment.rates[selectedService] || 0;
                // Find if item is in cart
                const cartItem = cartItems.find(
                  (item) => item.garmentId === garment.id && item.serviceType === selectedService
                );
                const quantity = cartItem ? cartItem.quantity : 0;

                return (
                  <div key={garment.id} className={styles.itemRow}>
                    <div>
                      <span className={styles.itemName}>{garment.name}</span>
                      <span className={styles.itemRate}>₹{rate} / piece</span>
                    </div>

                    <div className={styles.quantityControls}>
                      {quantity === 0 ? (
                        <button
                          className={styles.addBtn}
                          onClick={() => addToCart(garment, selectedService)}
                        >
                          Add +
                        </button>
                      ) : (
                        <>
                          <button
                            className={styles.qtyBtn}
                            onClick={() => updateQuantity(garment.id, selectedService, quantity - 1)}
                          >
                            -
                          </button>
                          <span className={styles.qtyVal}>{quantity}</span>
                          <button
                            className={styles.qtyBtn}
                            onClick={() => updateQuantity(garment.id, selectedService, quantity + 1)}
                          >
                            +
                          </button>
                        </>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Sticky Cart Summary Sidebar */}
          <div className={styles.sidebar}>
            <div className={styles.summaryBox}>
              <h3 className={styles.summaryTitle}>
                <span>Order Summary</span>
                {cartCount > 0 && <span style={{ fontSize: '13px', color: 'var(--text-light)' }}>{cartCount} items</span>}
              </h3>

              {cartItems.length === 0 ? (
                <div className={styles.emptyState}>
                  <p>Your laundry basket is empty.</p>
                  <p style={{ fontSize: '12px', marginTop: '6px' }}>Select garments on the left to add items.</p>
                </div>
              ) : (
                <>
                  <div className={styles.summaryItemsList}>
                    {cartItems.map((item, idx) => {
                      const serviceMeta = SERVICES_META[item.serviceType as keyof typeof SERVICES_META];
                      return (
                        <div key={`${item.garmentId}-${item.serviceType}-${idx}`} className={styles.summaryItemRow}>
                          <div>
                            <span className={styles.summaryItemName}>
                              {item.garmentName} ({item.quantity})
                            </span>
                            <span
                              style={{
                                display: 'block',
                                fontSize: '11px',
                                color: serviceMeta?.color || 'var(--text-light)',
                                fontWeight: 600,
                              }}
                            >
                              {serviceMeta?.name || item.serviceType}
                            </span>
                          </div>
                          <span className={styles.summaryItemPrice}>₹{item.quantity * item.rate}</span>
                        </div>
                      );
                    })}
                  </div>

                  <div className={styles.totalRow}>
                    <span className={styles.totalLabel}>Estimated Total</span>
                    <span className={styles.totalVal}>₹{cartTotal}</span>
                  </div>

                  <button
                    className={`btn-primary ${styles.checkoutBtn}`}
                    onClick={() => router.push('/book')}
                    style={{ width: '100%', justifyContent: 'center' }}
                  >
                    Confirm &amp; Book Pickup
                  </button>
                </>
              )}
            </div>

            {/* Additional info banner */}
            <div
              style={{
                backgroundColor: 'var(--bg-white)',
                padding: '20px',
                borderRadius: 'var(--border-radius-md)',
                border: '1px solid var(--border-light)',
                fontSize: '13px',
              }}
            >
              <h4 style={{ fontWeight: 700, marginBottom: '8px', color: 'var(--text-dark)' }}>
                🧼 WashNLaundry Clean Assurance
              </h4>
              <p style={{ color: 'var(--text-medium)', lineHeight: 1.5 }}>
                We use eco-friendly detergents, computerized cycle checks, soft water, and clean energy. Free re-cleaning guarantee if you are not satisfied.
              </p>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}

