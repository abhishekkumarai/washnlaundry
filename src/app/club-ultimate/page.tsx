'use strict';
'use client';

import React, { useState } from 'react';
import styles from './page.module.css';

interface Plan {
  name: string;
  price: number;
  description: string;
  benefits: string[];
  popular: boolean;
}

export default function ClubUltimatePage() {
  const [itemsCount, setItemsCount] = useState<number>(40);
  const [serviceType, setServiceType] = useState<'wash-fold' | 'wash-iron'>('wash-fold');

  // FAQ state
  const [activeFaq, setActiveFaq] = useState<number | null>(null);

  const toggleFaq = (index: number) => {
    if (activeFaq === index) {
      setActiveFaq(null);
    } else {
      setActiveFaq(index);
    }
  };

  const plans: Plan[] = [
    {
      name: 'ClubLite',
      price: 149,
      description: 'Ideal for singles and couples who need standard weekly service.',
      benefits: [
        '4 Pickups & Deliveries per month',
        'Standard booking slots priority',
        '2% Flat Cashback on all orders',
        'Zero surge pricing during holidays',
      ],
      popular: false,
    },
    {
      name: 'ClubPlus',
      price: 299,
      description: 'Perfect for small families who want hassle-free bi-weekly service.',
      benefits: [
        '8 Pickups & Deliveries per month',
        'Guaranteed next-day delivery slots',
        '5% Flat Cashback on all orders',
        'Zero delivery fees on all orders',
        'Free hangers packaging upgrade',
      ],
      popular: true,
    },
    {
      name: 'ClubPremium',
      price: 499,
      description: 'The ultimate luxury care package for complete laundry peace of mind.',
      benefits: [
        'Unlimited Pickups & Deliveries',
        'Guaranteed same-day/next-day slots',
        '10% Flat Cashback on all orders',
        'Zero delivery fees, zero minimums',
        'Free hangers packaging upgrade',
        '2 Free express Sprint (4h) upgrades monthly',
      ],
      popular: false,
    },
  ];

  const faqs = [
    {
      q: 'Can I cancel or pause my subscription anytime?',
      a: 'Yes, absolutely. You can cancel, upgrade, downgrade, or pause your membership at any time directly through the app settings. No contracts, no exit fees.',
    },
    {
      q: 'Do unused pickups roll over to the next month?',
      a: 'No, pickups do not roll over. However, with ClubPremium, you get unlimited pickups, and with ClubLite/Plus, the credits reset monthly.',
    },
    {
      q: 'How do autopilot recurring schedules work?',
      a: 'Once subscribed, you can set your preferred pickup days and hours (e.g. Tuesdays at 7 PM and Saturdays at 10 AM). Our app will automatically generate bookings and dispatch drivers, so you do not have to book manually.',
    },
    {
      q: 'Are dry cleaning and special garment items covered by memberships?',
      a: 'Yes, memberships grant flat cashbacks (up to 10% depending on tier) and zero delivery fees/surge charges on all garments, including delicate silk sarees, leather coats, and duvets processed under dry cleaning.',
    },
  ];

  // Pricing calculations for ROI
  const normalItemRate = serviceType === 'wash-fold' ? 20 : 25;
  const normalDeliveryFee = 30; // ₹30 per pickup
  const normalOrderSize = 10; // average 10 items per pickup

  const normalPickups = Math.ceil(itemsCount / normalOrderSize);
  const normalLaundryCost = itemsCount * normalItemRate;
  const normalDeliveryCost = normalPickups * normalDeliveryFee;
  const normalTotal = normalLaundryCost + normalDeliveryCost;

  // Club calculations (Using ClubPlus ₹299/mo as savings target)
  const clubSubscription = 299;
  const clubCashbackRate = 0.05; // 5% cashback
  const clubCashback = normalLaundryCost * clubCashbackRate;
  const clubDeliveryCost = 0; // free delivery
  const clubTotal = normalLaundryCost + clubSubscription - clubCashback;

  const netSavings = normalTotal - clubTotal;

  return (
    <div>
      {/* 1. Hero Header */}
      <section className={styles.hero}>
        <div className="container">
          <span className={styles.badge}>ClubUltimate memberships</span>
          <h1 className={styles.title}>Put Your Laundry On Autopilot</h1>
          <p className={styles.subtitle}>
            Join ClubUltimate and never think about laundry scheduling or delivery fees again. Choose a monthly tier that works for you.
          </p>
        </div>
      </section>

      {/* 2. Tier Cards */}
      <section className="container">
        <div className={styles.tiersGrid}>
          {plans.map((plan, idx) => (
            <div
              key={idx}
              className={`${styles.tierCard} ${plan.popular ? styles.popularCard : ''}`}
            >
              {plan.popular && <span className={styles.popularBadge}>Most Popular</span>}
              <h3 className={styles.tierName}>{plan.name}</h3>
              <div className={styles.tierPriceBox}>
                <span className={styles.currency}>₹</span>
                <span className={styles.price}>{plan.price}</span>
                <span className={styles.period}>/ month</span>
              </div>
              <p className={styles.tierDesc}>{plan.description}</p>

              <ul className={styles.benefitsList}>
                {plan.benefits.map((benefit, bidx) => (
                  <li key={bidx} className={styles.benefitItem}>
                    <span className={styles.benefitCheck}>✓</span>
                    <span>{benefit}</span>
                  </li>
                ))}
              </ul>

              <button
                className={`btn-primary ${styles.tierBtn}`}
                onClick={() => alert(`Subscribed to ${plan.name}! Checkout simulated.`)}
              >
                Subscribe Now
              </button>
            </div>
          ))}
        </div>
      </section>

      {/* 3. Savings ROI Calculator */}
      <section className={styles.calcSection}>
        <div className="container">
          <h2 className={styles.calcTitle}>Calculate Your Monthly Savings</h2>
          <p className={styles.calcSubtitle}>
            See how much you save with ClubPlus compared to pay-as-you-go pricing.
          </p>

          <div className={styles.calcGrid}>
            <div className={styles.calcPanel}>
              {/* Slider Input */}
              <div className={styles.controlGroup}>
                <div className={styles.labelRow}>
                  <label className={styles.label}>Monthly Garments Cleaned</label>
                  <span className={styles.valueIndicator}>{itemsCount} items</span>
                </div>
                <input
                  type="range"
                  min={20}
                  max={150}
                  step={5}
                  value={itemsCount}
                  onChange={(e) => setItemsCount(parseInt(e.target.value))}
                  className={styles.slider}
                />
              </div>

              {/* Service Selection */}
              <div className={styles.controlGroup}>
                <label className={styles.label}>Primary Service Type</label>
                <div className={styles.radioGroup}>
                  <button
                    className={`${styles.radioBtn} ${serviceType === 'wash-fold' ? styles.activeRadioBtn : ''}`}
                    onClick={() => setServiceType('wash-fold')}
                  >
                    Wash &amp; Fold (₹20/pc)
                  </button>
                  <button
                    className={`${styles.radioBtn} ${serviceType === 'wash-iron' ? styles.activeRadioBtn : ''}`}
                    onClick={() => setServiceType('wash-iron')}
                  >
                    Wash &amp; Iron (₹25/pc)
                  </button>
                </div>
              </div>
            </div>

            {/* Calculations results display box */}
            <div className={styles.resultsBox}>
              <h3 className={styles.resultsTitle}>Monthly Price Comparison</h3>

              <div className={styles.breakdownRow}>
                <span className={styles.breakdownLbl}>Normal pay-as-you-go cost:</span>
                <span className={styles.breakdownVal}>₹{normalTotal}</span>
              </div>
              <div style={{ fontSize: '12px', color: 'rgba(255,255,255,0.6)', marginTop: '-8px', marginBottom: '16px' }}>
                (Includes ₹{normalLaundryCost} laundry + ₹{normalDeliveryCost} delivery fees)
              </div>

              <div className={styles.breakdownRow}>
                <span className={styles.breakdownLbl}>ClubPlus subscription rate:</span>
                <span className={styles.breakdownVal}>₹{clubSubscription}</span>
              </div>
              <div className={styles.breakdownRow}>
                <span className={styles.breakdownLbl}>Laundry Cost (excl. delivery):</span>
                <span className={styles.breakdownVal}>₹{normalLaundryCost}</span>
              </div>
              <div className={styles.breakdownRow}>
                <span className={styles.breakdownLbl}>Cashback Earned (5%):</span>
                <span className={styles.breakdownVal} style={{ color: '#a7f3d0' }}>
                  - ₹{clubCashback.toFixed(0)}
                </span>
              </div>
              <div className={styles.breakdownRow}>
                <span className={styles.breakdownLbl}>Delivery Charges:</span>
                <span className={styles.breakdownVal} style={{ color: '#a7f3d0' }}>
                  ₹0 (FREE)
                </span>
              </div>

              <div className={styles.netSavingsRow}>
                <span className={styles.netSavingsLbl}>Net Monthly Savings</span>
                <span className={styles.netSavingsVal}>
                  ₹{netSavings > 0 ? netSavings.toFixed(0) : '0'}
                </span>
              </div>

              <p style={{ fontSize: '13px', lineHeight: 1.4, color: 'rgba(255,255,255,0.7)', textAlign: 'center' }}>
                *Calculations are based on 10 garments per pickup and include standard door-to-door logistics fees.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* 4. FAQs Section */}
      <section className={styles.faqSection}>
        <div className="container">
          <h2 className={styles.faqTitle}>Frequently Asked Questions</h2>
          <div className={styles.faqGrid}>
            {faqs.map((faq, index) => {
              const isOpen = activeFaq === index;
              return (
                <div key={index} className={styles.faqItem}>
                  <button className={styles.faqHeader} onClick={() => toggleFaq(index)}>
                    <span>{faq.q}</span>
                    <span className={`${styles.faqToggleIcon} ${isOpen ? styles.faqToggleIconActive : ''}`}>
                      +
                    </span>
                  </button>
                  {isOpen && <div className={styles.faqBody}>{faq.a}</div>}
                </div>
              );
            })}
          </div>
        </div>
      </section>
    </div>
  );
}
