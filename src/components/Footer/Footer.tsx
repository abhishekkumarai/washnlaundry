'use strict';

import React from 'react';
import Link from 'next/link';
import styles from './Footer.module.css';

export default function Footer() {
  return (
    <footer className={styles.footer}>
      <div className={`container ${styles.footerGrid}`}>
        {/* Column 1: Brand details */}
        <div className={styles.brandCol}>
          <Link href="/" className={styles.logo}>
            <img src="/logo.png" alt="WashNLaundry Logo" className={styles.logoImg} />
            <span>
              WashN<span className={styles.logoSpan}>Laundry</span>
            </span>
          </Link>
          <p className={styles.brandDesc}>
            WashNLaundry is India&apos;s leading technology-driven, sustainable daily laundry & dry-cleaning service provider. Bringing affordable neighbourhood pricing to your doorstep.
          </p>
          <div className={styles.socials}>
            <a href="#" className={styles.socialIcon} aria-label="Facebook">
              F
            </a>
            <a href="#" className={styles.socialIcon} aria-label="Instagram">
              I
            </a>
            <a href="#" className={styles.socialIcon} aria-label="Twitter">
              T
            </a>
            <a href="#" className={styles.socialIcon} aria-label="LinkedIn">
              L
            </a>
          </div>
        </div>

        {/* Column 2: Quick Links */}
        <div>
          <h4 className={styles.title}>Services</h4>
          <ul className={styles.linksList}>
            <li className={styles.linkItem}>
              <Link href="/services?tab=wash-fold">Wash & Fold</Link>
            </li>
            <li className={styles.linkItem}>
              <Link href="/services?tab=wash-iron">Wash & Iron</Link>
            </li>
            <li className={styles.linkItem}>
              <Link href="/services?tab=steam-iron">Steam Ironing</Link>
            </li>
            <li className={styles.linkItem}>
              <Link href="/services?tab=dry-clean">Dry Cleaning</Link>
            </li>
            <li className={styles.linkItem}>
              <Link href="/book?sprint=true">Sprint Express (4h)</Link>
            </li>
          </ul>
        </div>

        {/* Column 3: Corporate */}
        <div>
          <h4 className={styles.title}>Company</h4>
          <ul className={styles.linksList}>
            <li className={styles.linkItem}>
              <Link href="/about">About Eco-Promise</Link>
            </li>
            <li className={styles.linkItem}>
              <Link href="/club-ultimate">ClubUltimate Plans</Link>
            </li>
            <li className={styles.linkItem}>
              <Link href="/track">Track Live Order</Link>
            </li>
            <li className={styles.linkItem}>
              <a href="#">Corporate Laundry</a>
            </li>
            <li className={styles.linkItem}>
              <a href="#">Join Our Fleet</a>
            </li>
          </ul>
        </div>

        {/* Column 4: Contact details */}
        <div className={styles.contactCol}>
          <h4 className={styles.title}>Get in Touch</h4>
          <div className={styles.contactItem}>
            <span className={styles.contactIcon}>📍</span>
            <span className={styles.contactText}>
              WashNLaundry, Bailey Road, near Shyama Apartment, Lohiya Path, Chotti Rukanpura, Patna, Bihar 800025
            </span>
          </div>
          <div className={styles.contactItem}>
            <span className={styles.contactIcon}>📞</span>
            <span className={styles.contactText}>08407000048</span>
          </div>
          <div className={styles.contactItem}>
            <span className={styles.contactIcon}>✉️</span>
            <span className={styles.contactText}>support@washnlaundry.com</span>
          </div>
        </div>
      </div>

      {/* Bottom Bar */}
      <div className={`container ${styles.bottomBar}`}>
        <p className={styles.copyright}>
          &copy; {new Date().getFullYear()} WashNLaundry. Built for demonstration. All rights reserved.
        </p>
        <ul className={styles.legalLinks}>
          <li>
            <a href="#">Terms &amp; Conditions</a>
          </li>
          <li>
            <a href="#">Privacy Policy</a>
          </li>
          <li>
            <a href="#">Cancellation Policy</a>
          </li>
        </ul>
      </div>
    </footer>
  );
}

