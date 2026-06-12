'use strict';
'use client';

import React, { useState, useEffect } from 'react';
import { useCart } from '../../context/CartContext';
import styles from './page.module.css';

const STEPS_META = [
  { title: 'Order Confirmed', desc: 'We have received your pickup request.' },
  { title: 'Rider Out for Pickup', desc: 'Rider is on the way to collect your garments.' },
  { title: 'At Laundry Facility', desc: 'Clothes have checked in and sorting has begun.' },
  { title: 'Washing & Processing', desc: 'Fabric-safe cycles are running soft-water washes.' },
  { title: 'Quality Checked & Packed', desc: 'Neat pressing is completed and packed in starch bags.' },
  { title: 'Rider Out for Delivery', desc: 'Rider is heading to your doorstep with fresh clothes.' },
  { title: 'Delivered', desc: 'Order completed. Thank you for choosing WashNLaundry!' },
];

export default function OrderTrackerPage() {
  const { orderId, setOrderId, scheduling, address } = useCart();
  const [activeStep, setActiveStep] = useState<number>(1); // default step "Rider Out for Pickup"
  const [inputOrderId, setInputOrderId] = useState<string>('');
  const [errorMessage, setErrorMessage] = useState<string>('');

  // Auto-advance step simulation or let the user click to simulate
  const handleNextMilestone = () => {
    if (activeStep < STEPS_META.length - 1) {
      setActiveStep((prev) => prev + 1);
    }
  };

  const handlePrevMilestone = () => {
    if (activeStep > 0) {
      setActiveStep((prev) => prev - 1);
    }
  };

  const handleSearchOrder = (e: React.FormEvent) => {
    e.preventDefault();
    if (inputOrderId && inputOrderId.toUpperCase().startsWith('FW-')) {
      setOrderId(inputOrderId.toUpperCase());
      setActiveStep(1); // Reset to "Rider Out for Pickup"
      setErrorMessage('');
    } else {
      setErrorMessage('Please enter a valid Order ID (e.g. FW-123456)');
    }
  };

  // Calculate percentage width for mapping route indicator
  const progressPercent = (activeStep / (STEPS_META.length - 1)) * 60 + 20;

  return (
    <div className={`container ${styles.trackPage}`}>
      <h1 className={styles.title}>Track Your Clothes</h1>
      <p className={styles.subtitle}>Get live status updates on your laundry and delivery rider.</p>

      {!orderId ? (
        /* Fallback form if no active order is generated */
        <div className={styles.searchBox}>
          <h3 className={styles.searchTitle}>Enter Your Order ID</h3>
          <p className={styles.searchDesc}>
            Check your sms confirmation receipt or enter a mock code to simulate the dashboard (e.g. FW-481920)
          </p>
          <form onSubmit={handleSearchOrder} className={styles.searchForm}>
            <input
              type="text"
              placeholder="e.g. FW-581902"
              className={styles.searchInput}
              value={inputOrderId}
              onChange={(e) => setInputOrderId(e.target.value)}
            />
            <button type="submit" className={styles.searchBtn}>
              Track Order
            </button>
          </form>
          {errorMessage && (
            <p style={{ color: '#ef4444', fontSize: '13px', marginTop: '12px', fontWeight: 600 }}>
              {errorMessage}
            </p>
          )}
        </div>
      ) : (
        /* Active order tracking dashboard */
        <div className={styles.layout}>
          {/* Timeline Panel */}
          <div className={styles.trackerCard}>
            <div className={styles.cardHeader}>
              <div>
                <span className={styles.orderId}>Order #{orderId}</span>
                <p style={{ fontSize: '14px', color: 'var(--text-medium)', marginTop: '4px' }}>
                  Slot: {scheduling.pickupDate ? `${scheduling.pickupDate} (${scheduling.pickupSlot})` : 'Today'}
                </p>
              </div>
              <span className={styles.orderDate}>Live Status</span>
            </div>

            <div className={styles.timeline}>
              <div className={styles.timelineLine}></div>
              {STEPS_META.map((stepMeta, idx) => {
                let statusClass = '';
                if (idx < activeStep) {
                  statusClass = styles.statusDone;
                } else if (idx === activeStep) {
                  statusClass = styles.statusActive;
                }

                return (
                  <div key={idx} className={`${styles.milestone} ${statusClass}`}>
                    <div className={styles.milestoneDot}></div>
                    <div className={styles.milestoneText}>
                      <h4 className={styles.milestoneTitle}>{stepMeta.title}</h4>
                      <p className={styles.milestoneDesc}>{stepMeta.desc}</p>
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Simulation controls */}
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'center', marginTop: '32px' }}>
              <button className={styles.simBtn} onClick={handlePrevMilestone} disabled={activeStep === 0}>
                &larr; Prev Step
              </button>
              <button
                className={styles.simBtn}
                onClick={handleNextMilestone}
                disabled={activeStep === STEPS_META.length - 1}
              >
                Next Step &rarr;
              </button>
            </div>
          </div>

          {/* Sidebar Courier Details & Mock Map */}
          <div className={styles.sidebar}>
            {/* Rider Profile Card */}
            <div className={styles.driverCard}>
              <div className={styles.driverHeader}>
                <div className={styles.driverAvatar}>FW</div>
                <div className={styles.driverInfo}>
                  <span className={styles.driverName}>WashNLaundry Personnel</span>
                  <span className={styles.driverRole}>⚡ EV Logistics Officer</span>
                </div>
              </div>

              <div className={styles.driverMeta}>
                <div>
                  <span className={styles.metaLabel}>Vehicle:</span> <br />
                  <span className={styles.metaVal}>EV-Scooter (KA-03-EG-4523)</span>
                </div>
                <div>
                  <span className={styles.metaLabel}>Rating:</span> <br />
                  <span className={styles.metaVal}>4.9 ★</span>
                </div>
              </div>

              <button
                className={`btn-outline ${styles.callBtn}`}
                style={{ width: '100%', justifyContent: 'center' }}
                onClick={() => alert('Dialing WashNLaundry Personnel (08407000048)...')}
              >
                📞 Contact Rider
              </button>
            </div>

            {/* Map Representation */}
            <div className={styles.mapCard}>
              <div className={styles.mapGrid}></div>
              <div className={styles.mapRoute}>
                <div className={styles.mapRouteActive} style={{ width: `${progressPercent}%` }}></div>
              </div>
              <div className={styles.mapHub} title="WashNLaundry Hub"></div>
              <div className={styles.mapHome} title="Your Home"></div>
              <div
                className={styles.mapRider}
                style={{ left: `${progressPercent}%` }}
                title="WashNLaundry Personnel (EV)"
              >
                🛵
              </div>

              {/* Status overlay */}
              <div
                style={{
                  position: 'absolute',
                  bottom: '12px',
                  left: '12px',
                  right: '12px',
                  backgroundColor: 'white',
                  padding: '8px 12px',
                  borderRadius: '20px',
                  fontSize: '12px',
                  fontWeight: 700,
                  boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  justifyContent: 'center',
                }}
              >
                <span
                  style={{
                    width: '8px',
                    height: '8px',
                    backgroundColor: '#10b981',
                    borderRadius: '50%',
                    display: 'inline-block',
                  }}
                ></span>
                {activeStep === 0 && 'Order has been placed. Waiting for rider pickup assignment.'}
                {activeStep === 1 && 'WashNLaundry Personnel is on the way. Arriving at your doorstep in 12 mins.'}
                {activeStep > 1 && activeStep < 5 && 'Garments are being processed at Patna hub.'}
                {activeStep === 5 && 'WashNLaundry Personnel has collected processed clothes. Heading to you.'}
                {activeStep === 6 && 'Clothes successfully delivered. Welcome to WashNLaundry.'}
              </div>
            </div>

            <button
              className={styles.simBtn}
              onClick={() => {
                setOrderId('');
                localStorage.removeItem('fw_order_id');
              }}
            >
              Track Another Order
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

