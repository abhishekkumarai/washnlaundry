'use strict';
'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useCart, SERVICES_META } from '../../context/CartContext';
import styles from './page.module.css';

const TIME_SLOTS = [
  '07:00 AM - 10:00 AM',
  '10:00 AM - 01:00 PM',
  '01:00 PM - 04:00 PM',
  '04:00 PM - 07:00 PM',
  '07:00 PM - 10:00 PM',
];

export default function BookingPage() {
  const router = useRouter();
  const {
    cartItems,
    cartTotal,
    cartCount,
    updateQuantity,
    scheduling,
    setScheduling,
    address,
    setAddress,
    clearCart,
    setOrderId,
  } = useCart();

  const [step, setStep] = useState<number>(1);
  const [pickupDates, setPickupDates] = useState<{ label: string; val: number; dateStr: string }[]>([]);
  const [deliveryDates, setDeliveryDates] = useState<{ label: string; val: number; dateStr: string }[]>([]);

  // Address inputs local state
  const [addressForm, setAddressForm] = useState(address);

  // Generate scheduling dates on mount
  useEffect(() => {
    const generateDates = (offsetDays: number = 0) => {
      const dates = [];
      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      for (let i = 0; i < 5; i++) {
        const d = new Date();
        d.setDate(d.getDate() + i + offsetDays);
        dates.push({
          label: days[d.getDay()],
          val: d.getDate(),
          dateStr: d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }),
        });
      }
      return dates;
    };

    setPickupDates(generateDates(0));
  }, []);

  // Update delivery calendar based on selected pickup date
  useEffect(() => {
    if (scheduling.pickupDate) {
      const pickupIndex = pickupDates.findIndex((d) => d.dateStr === scheduling.pickupDate);
      // Delivery must be at least 1 day after pickup for standard, or same day + 4h for sprint
      const offset = scheduling.isSprint ? 0 : (pickupIndex > -1 ? pickupIndex + 1 : 1);
      
      const dates = [];
      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      for (let i = 0; i < 5; i++) {
        const d = new Date();
        d.setDate(d.getDate() + i + offset);
        dates.push({
          label: days[d.getDay()],
          val: d.getDate(),
          dateStr: d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }),
        });
      }
      setDeliveryDates(dates);

      // Auto-select first delivery date if current delivery date is invalid
      if (!scheduling.isSprint) {
        setScheduling({
          ...scheduling,
          deliveryDate: dates[0].dateStr,
        });
      }
    }
  }, [scheduling.pickupDate, scheduling.isSprint, pickupDates]);

  const handleSprintToggle = (e: React.ChangeEvent<HTMLInputElement>) => {
    const isChecked = e.target.checked;
    const todayStr = new Date().toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
    
    setScheduling({
      ...scheduling,
      isSprint: isChecked,
      // If Sprint is active, delivery date matches pickup date
      deliveryDate: isChecked ? scheduling.pickupDate || todayStr : scheduling.deliveryDate,
      deliverySlot: isChecked ? 'Express Within 4 Hours' : scheduling.deliverySlot,
    });
  };

  const handleNextStep = () => {
    if (step === 1) {
      // Auto-populate default dates/slots if empty
      const defaultPickup = scheduling.pickupDate || (pickupDates[0] ? pickupDates[0].dateStr : '');
      const defaultPickupSlot = scheduling.pickupSlot || TIME_SLOTS[0];
      const defaultDelivery = scheduling.isSprint ? defaultPickup : (scheduling.deliveryDate || (deliveryDates[0] ? deliveryDates[0].dateStr : ''));
      const defaultDeliverySlot = scheduling.isSprint ? 'Express Within 4 Hours' : (scheduling.deliverySlot || TIME_SLOTS[1]);

      setScheduling({
        ...scheduling,
        pickupDate: defaultPickup,
        pickupSlot: defaultPickupSlot,
        deliveryDate: defaultDelivery,
        deliverySlot: defaultDeliverySlot,
      });

      setStep(2);
    } else if (step === 2) {
      if (!scheduling.pickupDate || !scheduling.pickupSlot || !scheduling.deliveryDate || !scheduling.deliverySlot) {
        alert('Please select pickup and delivery windows.');
        return;
      }
      setStep(3);
    } else if (step === 3) {
      if (!addressForm.fullName || !addressForm.phone || !addressForm.addressLine || !addressForm.pincode) {
        alert('Please fill out all required address fields.');
        return;
      }
      setAddress(addressForm);
      setStep(4);
    }
  };

  const handlePrevStep = () => {
    if (step > 1) {
      setStep(step - 1);
    }
  };

  const handlePlaceOrder = () => {
    // Generate a random mock order ID
    const randomNum = Math.floor(100000 + Math.random() * 900000);
    const generatedId = `FW-${randomNum}`;

    setOrderId(generatedId);
    // Redirect to tracking dashboard
    router.push(`/track`);
    
    // Clear cart items in a delayed block so context clears after navigation starts
    setTimeout(() => {
      clearCart();
    }, 100);
  };

  return (
    <div className={`container ${styles.bookingPage}`}>
      <h1 className={styles.title}>Schedule Your Service</h1>

      {/* Stepper Header */}
      <div className={styles.stepper}>
        <div className={`${styles.step} ${step === 1 ? styles.stepActive : ''} ${step > 1 ? styles.stepDone : ''}`}>
          <div className={styles.stepNum}>1</div>
          <span className={styles.stepText}>Review Cart</span>
        </div>
        <div className={`${styles.step} ${step === 2 ? styles.stepActive : ''} ${step > 2 ? styles.stepDone : ''}`}>
          <div className={styles.stepNum}>2</div>
          <span className={styles.stepText}>Schedule</span>
        </div>
        <div className={`${styles.step} ${step === 3 ? styles.stepActive : ''} ${step > 3 ? styles.stepDone : ''}`}>
          <div className={styles.stepNum}>3</div>
          <span className={styles.stepText}>Address</span>
        </div>
        <div className={`${styles.step} ${step === 4 ? styles.stepActive : ''}`}>
          <div className={styles.stepNum}>4</div>
          <span className={styles.stepText}>Confirm</span>
        </div>
      </div>

      {/* Booking Form Content */}
      <div className={styles.layout}>
        <div className={styles.mainCard}>
          {step === 1 && (
            <div>
              <h2 className={styles.cardTitle}>Your Basket Review</h2>
              {cartItems.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '40px 0' }}>
                  <p style={{ color: 'var(--text-medium)', marginBottom: '20px' }}>Your basket is empty.</p>
                  <button onClick={() => router.push('/services')} className="btn-outline">
                    Browse Services &amp; Add Items
                  </button>
                </div>
              ) : (
                <>
                  <div className={styles.itemsList}>
                    {cartItems.map((item, idx) => (
                      <div key={idx} className={styles.itemRow}>
                        <div>
                          <span className={styles.itemName}>{item.garmentName}</span>
                          <span className={styles.itemSub}>
                            {SERVICES_META[item.serviceType as keyof typeof SERVICES_META]?.name || item.serviceType}
                          </span>
                        </div>
                        <div className={styles.qtyBox}>
                          <button
                            className={styles.btnQty}
                            onClick={() => updateQuantity(item.garmentId, item.serviceType, item.quantity - 1)}
                          >
                            -
                          </button>
                          <span style={{ fontWeight: 700, width: '20px', textAlign: 'center' }}>{item.quantity}</span>
                          <button
                            className={styles.btnQty}
                            onClick={() => updateQuantity(item.garmentId, item.serviceType, item.quantity + 1)}
                          >
                            +
                          </button>
                          <span style={{ fontWeight: 700, marginLeft: '12px', minWidth: '50px', textAlign: 'right' }}>
                            ₹{item.quantity * item.rate}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>

                  {/* Express Sprint toggle */}
                  <div className={styles.sprintToggleBox}>
                    <div>
                      <h4 className={styles.sprintTitle}>🚀 Express Sprint Delivery</h4>
                      <p className={styles.sprintDesc}>
                        Get your processed clothes back within 4 hours flat. (50% speed premium applied)
                      </p>
                    </div>
                    <label className={styles.toggleSwitch}>
                      <input
                        type="checkbox"
                        checked={scheduling.isSprint}
                        onChange={handleSprintToggle}
                      />
                      <span className={styles.toggleSlider}></span>
                    </label>
                  </div>
                </>
              )}
            </div>
          )}

          {step === 2 && (
            <div>
              <h2 className={styles.cardTitle}>Choose Pickup &amp; Delivery Schedule</h2>

              {/* Pickup Date Calendar Grid */}
              <h3 className={styles.slotsTitle}>Select Pickup Date</h3>
              <div className={styles.dateGrid}>
                {pickupDates.map((d, idx) => (
                  <button
                    key={idx}
                    className={`${styles.dateBtn} ${scheduling.pickupDate === d.dateStr ? styles.dateBtnActive : ''}`}
                    onClick={() => setScheduling({ ...scheduling, pickupDate: d.dateStr })}
                  >
                    <span className={styles.dayName}>{d.label}</span>
                    <span className={styles.dayVal}>{d.val}</span>
                  </button>
                ))}
              </div>

              {/* Pickup Time Slots */}
              <h3 className={styles.slotsTitle}>Select Pickup Time Slot</h3>
              <div className={styles.slotsGrid}>
                {TIME_SLOTS.map((slot, idx) => (
                  <button
                    key={idx}
                    className={`${styles.slotBtn} ${scheduling.pickupSlot === slot ? styles.slotBtnActive : ''}`}
                    onClick={() => setScheduling({ ...scheduling, pickupSlot: slot })}
                  >
                    {slot}
                  </button>
                ))}
              </div>

              {/* Delivery Schedule Section */}
              {!scheduling.isSprint ? (
                <>
                  <h3 className={styles.slotsTitle}>Select Delivery Date</h3>
                  <div className={styles.dateGrid}>
                    {deliveryDates.map((d, idx) => (
                      <button
                        key={idx}
                        className={`${styles.dateBtn} ${scheduling.deliveryDate === d.dateStr ? styles.dateBtnActive : ''}`}
                        onClick={() => setScheduling({ ...scheduling, deliveryDate: d.dateStr })}
                      >
                        <span className={styles.dayName}>{d.label}</span>
                        <span className={styles.dayVal}>{d.val}</span>
                      </button>
                    ))}
                  </div>

                  <h3 className={styles.slotsTitle}>Select Delivery Time Slot</h3>
                  <div className={styles.slotsGrid}>
                    {TIME_SLOTS.map((slot, idx) => (
                      <button
                        key={idx}
                        className={`${styles.slotBtn} ${scheduling.deliverySlot === slot ? styles.slotBtnActive : ''}`}
                        onClick={() => setScheduling({ ...scheduling, deliverySlot: slot })}
                      >
                        {slot}
                      </button>
                    ))}
                  </div>
                </>
              ) : (
                <div
                  style={{
                    backgroundColor: '#fffbeb',
                    border: '1px solid #fef3c7',
                    padding: '16px',
                    borderRadius: 'var(--border-radius-sm)',
                    fontSize: '14px',
                    fontWeight: 600,
                    color: '#b45309',
                  }}
                >
                  ⚡ Express Sprint Mode Active: Delivery will occur automatically within 4 hours of your pickup slot.
                </div>
              )}
            </div>
          )}

          {step === 3 && (
            <div>
              <h2 className={styles.cardTitle}>Pickup &amp; Delivery Address</h2>
              <div className={styles.formGrid}>
                <div className={styles.inputGroup}>
                  <label className={styles.label}>Full Name *</label>
                  <input
                    type="text"
                    required
                    className={styles.input}
                    value={addressForm.fullName}
                    onChange={(e) => setAddressForm({ ...addressForm, fullName: e.target.value })}
                    placeholder="Enter your name"
                  />
                </div>
                <div className={styles.inputGroup}>
                  <label className={styles.label}>Phone Number *</label>
                  <input
                    type="tel"
                    required
                    className={styles.input}
                    value={addressForm.phone}
                    onChange={(e) => setAddressForm({ ...addressForm, phone: e.target.value })}
                    placeholder="Enter 10-digit mobile number"
                  />
                </div>
                <div className={styles.inputGroup}>
                  <label className={styles.label}>Pincode *</label>
                  <input
                    type="text"
                    required
                    maxLength={6}
                    className={styles.input}
                    value={addressForm.pincode}
                    onChange={(e) => setAddressForm({ ...addressForm, pincode: e.target.value })}
                    placeholder="e.g. 800025"
                  />
                </div>
                <div className={styles.inputGroup}>
                  <label className={styles.label}>City</label>
                  <input
                    type="text"
                    disabled
                    className={styles.input}
                    value={addressForm.city}
                    placeholder="Patna"
                  />
                </div>
                <div className={`${styles.inputGroup} ${styles.formCol2}`}>
                  <label className={styles.label}>Flat / House / Street Address *</label>
                  <input
                    type="text"
                    required
                    className={styles.input}
                    value={addressForm.addressLine}
                    onChange={(e) => setAddressForm({ ...addressForm, addressLine: e.target.value })}
                    placeholder="Flat No, Wing Name, Street Detail"
                  />
                </div>
                <div className={`${styles.inputGroup} ${styles.formCol2}`}>
                  <label className={styles.label}>Landmark</label>
                  <input
                    type="text"
                    className={styles.input}
                    value={addressForm.landmark}
                    onChange={(e) => setAddressForm({ ...addressForm, landmark: e.target.value })}
                    placeholder="e.g. Near Shyama Apartment"
                  />
                </div>
              </div>
            </div>
          )}

          {step === 4 && (
            <div>
              <h2 className={styles.cardTitle}>Review Order &amp; Place Booking</h2>
              <div className={styles.summaryBlock}>
                {/* 1. Schedule details summary */}
                <div className={styles.summaryGroup}>
                  <span className={styles.summaryGroupLabel}>Schedule Details</span>
                  <div className={styles.summaryValue}>
                    📅 Pickup: {scheduling.pickupDate} ({scheduling.pickupSlot}) <br />
                    🚚 Delivery:{' '}
                    {scheduling.isSprint ? (
                      <span style={{ color: 'var(--color-express-sprint)' }}>
                        Express Sprint Delivery (Within 4 Hours)
                      </span>
                    ) : (
                      `${scheduling.deliveryDate} (${scheduling.deliverySlot})`
                    )}
                  </div>
                </div>

                {/* 2. Address summary */}
                <div className={styles.summaryGroup}>
                  <span className={styles.summaryGroupLabel}>Pickup &amp; Delivery Address</span>
                  <div className={styles.summaryValue}>
                    👤 {addressForm.fullName} | 📞 {addressForm.phone} <br />
                    🏠 {addressForm.addressLine}, {addressForm.landmark ? `Near ${addressForm.landmark}, ` : ''}
                    {addressForm.city} - {addressForm.pincode}
                  </div>
                </div>

                {/* 3. Items summary */}
                <div className={styles.summaryGroup}>
                  <span className={styles.summaryGroupLabel}>Garments Details</span>
                  <div className={styles.summaryValue}>
                    {cartItems.map((item, idx) => (
                      <div
                        key={idx}
                        style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0', fontWeight: 500 }}
                      >
                        <span>
                          {item.garmentName} (x{item.quantity}) -{' '}
                          {SERVICES_META[item.serviceType as keyof typeof SERVICES_META]?.name || item.serviceType}
                        </span>
                        <span>₹{item.quantity * item.rate}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Wizard Action Controls */}
          <div className={styles.actions}>
            {step > 1 ? (
              <button className={styles.backBtn} onClick={handlePrevStep}>
                &larr; Back
              </button>
            ) : (
              <div></div>
            )}

            {step < 4 ? (
              <button
                className="btn-primary"
                onClick={handleNextStep}
                disabled={cartItems.length === 0}
                style={{ opacity: cartItems.length === 0 ? 0.6 : 1 }}
              >
                Continue &rarr;
              </button>
            ) : (
              <button className="btn-secondary" onClick={handlePlaceOrder}>
                ⚡ Confirm &amp; Place Order
              </button>
            )}
          </div>
        </div>

        {/* Sidebar Order Value totals */}
        <div className={styles.sidebar}>
          <h3 className={styles.sidebarTitle}>Fare Breakdown</h3>
          <div className={styles.pricingDetails}>
            <div className={styles.priceRow}>
              <span>Items Subtotal:</span>
              <span className={styles.priceVal}>₹{cartItems.reduce((acc, item) => acc + item.quantity * item.rate, 0)}</span>
            </div>
            {scheduling.isSprint && (
              <div className={styles.priceRow} style={{ color: 'var(--color-express-sprint)' }}>
                <span>Express Sprint Multiplier (1.5x):</span>
                <span className={styles.priceVal}>
                  + ₹{Math.round(cartItems.reduce((acc, item) => acc + item.quantity * item.rate, 0) * 0.5)}
                </span>
              </div>
            )}
            <div className={styles.priceRow}>
              <span>Logistics &amp; Delivery Fee:</span>
              <span className={styles.priceVal} style={{ color: '#10b981' }}>
                ₹0 (FREE)
              </span>
            </div>
            <div className={styles.priceRow}>
              <span>Green Bio-Packaging Charge:</span>
              <span className={styles.priceVal} style={{ color: '#10b981' }}>
                ₹0 (WAIVED)
              </span>
            </div>
          </div>

          <div className={styles.totalRow}>
            <span className={styles.totalLbl}>Total Estimated Charge</span>
            <span className={styles.totalAmount}>₹{cartTotal}</span>
          </div>

          <p style={{ fontSize: '12px', color: 'var(--text-light)', lineHeight: 1.4 }}>
            *Price includes free contactless door pickup, eco-friendly washing, sterilization processing, canvas bin transport, and EV-fleet delivery.
          </p>
        </div>
      </div>
    </div>
  );
}
