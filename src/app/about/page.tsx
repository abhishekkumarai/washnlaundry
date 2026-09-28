'use strict';
'use client';

import React from 'react';
import { useRouter } from 'next/navigation';
import styles from './page.module.css';

export default function AboutPage() {
  const router = useRouter();

  return (
    <div>
      {/* 1. Hero Section */}
      <section className={styles.hero}>
        <div className="container">
          <h1 className={styles.title}>Cleaner Clothes, Greener Planet</h1>
          <p className={styles.subtitle}>
            How WashNLaundry is redefining fabric care with clean water technology, electric vehicles, and plastic-free packaging.
          </p>
        </div>
      </section>

      {/* 2. Sustainability Stats */}
      <section className={styles.statsSection}>
        <div className="container">
          <div className={styles.statsGrid}>
            <div className={styles.statCard}>
              <span className={styles.statNum}>90%</span>
              <span className={styles.statLabel}>Water Recycled</span>
              <span className={styles.statDesc}>
                We clean and recycle our water using advanced purification, saving millions of gallons.
              </span>
            </div>
            <div className={styles.statCard}>
              <span className={styles.statNum}>100%</span>
              <span className={styles.statLabel}>EV Fleet deliveries</span>
              <span className={styles.statDesc}>
                Zero carbon emissions during pickup and delivery. Our custom vans are fully electric.
              </span>
            </div>
            <div className={styles.statCard}>
              <span className={styles.statNum}>0%</span>
              <span className={styles.statLabel}>Single-Use Plastics</span>
              <span className={styles.statDesc}>
                We wrap garments in plant-starch compostable bags and transport in reusable canvas bins.
              </span>
            </div>
          </div>
        </div>
      </section>

      {/* 3. Three Pillars of Green Laundry */}
      <section className={styles.pillarsSection}>
        <div className="container">
          <h2 className={styles.sectionTitle}>Our Three Pillars of Sustainability</h2>
          <p className={styles.sectionSubtitle}>
            Conventional laundry services consume massive amounts of water, coal energy, and toxic solvents. Here is how we do it differently.
          </p>

          <div className={styles.pillarsGrid}>
            {/* Pillar 1 */}
            <div className={styles.pillarCard}>
              <div className={styles.pillarIcon}>💧</div>
              <h3 className={styles.pillarName}>Water Conservation</h3>
              <p className={styles.pillarDesc}>
                Standard washing machines waste up to 40 gallons of water per load. Our centralized plant uses smart sensors, high-extraction washers, and reverse-osmosis recycling systems. We use only 3 gallons of fresh water per load.
              </p>
            </div>

            {/* Pillar 2 */}
            <div className={styles.pillarCard}>
              <div className={styles.pillarIcon}>🔌</div>
              <h3 className={styles.pillarName}>Carbon-Free Logistics</h3>
              <p className={styles.pillarDesc}>
                Our logistics network uses electric vehicles (EVs) charged by clean solar energy at our main hub. By scheduling pickups intelligently, we reduce road miles and deliver clothes with a net-zero transit footprint.
              </p>
            </div>

            {/* Pillar 3 */}
            <div className={styles.pillarCard}>
              <div className={styles.pillarIcon}>🌱</div>
              <h3 className={styles.pillarName}>Zero-Plastic Packaging</h3>
              <p className={styles.pillarDesc}>
                Traditional dry cleaners use thin polythene bags that sit in landfills for centuries. We deliver your shirts, gowns, and sheets wrapped in certified compostable bags made of tapioca starch, which dissolve safely in soil.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* 4. Tech Grid */}
      <section className={styles.techSection}>
        <div className="container">
          <div className={styles.techGrid}>
            <div className={styles.techText}>
              <h2 style={{ fontSize: '32px', fontWeight: 800 }}>The Technology Facility</h2>
              <p style={{ color: 'var(--text-medium)', fontSize: '15px' }}>
                Every single garment processed at WashNLaundry goes through an automated, software-tracked cleaning cycle designed to maximize fabric lifespan and minimize waste.
              </p>

              <div className={styles.techListItem}>
                <div className={styles.techListIcon}>1</div>
                <div>
                  <h4 className={styles.techItemTitle}>Garment RFID Tagging</h4>
                  <p className={styles.techItemDesc}>
                    Every clothing item is checked in with a unique barcode tag to track its status from pickup through inspection, washing, pressing, and bagging. No lost items.
                  </p>
                </div>
              </div>

              <div className={styles.techListItem}>
                <div className={styles.techListIcon}>2</div>
                <div>
                  <h4 className={styles.techItemTitle}>Computerized Detergent Dosing</h4>
                  <p className={styles.techItemDesc}>
                    We don&apos;t guess. Our automated chemical systems inject exact weights of bio-detergents, softeners, and sanitizers based on fabric type, weight, and soil density.
                  </p>
                </div>
              </div>

              <div className={styles.techListItem}>
                <div className={styles.techListIcon}>3</div>
                <div>
                  <h4 className={styles.techItemTitle}>Centralized Soft Water Processing</h4>
                  <p className={styles.techItemDesc}>
                    Hard water ruins fabrics and makes colors look faded. We filter all incoming city water to remove heavy minerals, reducing soap usage by 50% and leaving your shirts soft.
                  </p>
                </div>
              </div>
            </div>

            {/* Right Tech Grid illustration cards */}
            <div className={styles.techImagePlaceholder}>
              <div className={styles.techCardItem}>
                <span className={styles.techCardIcon}>🧪</span>
                <div>
                  <h4 className={styles.techCardTitle}>Eco-Solvent Cleaning</h4>
                  <p className={styles.techCardDesc}>Replacing cancer-linked PERC with biodegradable silicon solvents.</p>
                </div>
              </div>
              <div className={styles.techCardItem}>
                <span className={styles.techCardIcon}>📊</span>
                <div>
                  <h4 className={styles.techCardTitle}>Dynamic ERP Routing</h4>
                  <p className={styles.techCardDesc}>AI-driven scheduling maps to group neighborhood collections together.</p>
                </div>
              </div>
              <div className={styles.techCardItem}>
                <span className={styles.techCardIcon}>🧼</span>
                <div>
                  <h4 className={styles.techCardTitle}>Sterilization Treatment</h4>
                  <p className={styles.techCardDesc}>Mild ozone wash sanitizing steps to eradicate bacteria completely.</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* 5. CTA Section */}
      <section className="container">
        <div className={styles.ctaBox}>
          <h2 className={styles.ctaTitle}>Experience the Future of Laundry</h2>
          <p className={styles.ctaDesc}>
            Join the eco-friendly revolution. Save time, protect your clothes, and reduce your carbon footprint with one click.
          </p>
          <button className="btn-secondary" onClick={() => router.push('/#book')}>
            Schedule Your Green Pickup
          </button>
        </div>
      </section>
    </div>
  );
}

