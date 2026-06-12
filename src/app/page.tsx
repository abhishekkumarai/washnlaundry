'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useCart } from '../context/CartContext';
import styles from './page.module.css';

// Active areas mapping
const ACTIVE_PINCODES = ['800025', '801503', '800001', '800020', '800013'];

export default function Home() {
  const router = useRouter();
  const { setSelectedService } = useCart();
  const [pincode, setPincode] = useState('');
  const [checking, setChecking] = useState(false);
  const [checkStatus, setCheckStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const [openFaqIndex, setOpenFaqIndex] = useState<number | null>(null);

  // Enquiry form states
  const [enquiryName, setEnquiryName] = useState('');
  const [enquiryEmail, setEnquiryEmail] = useState('');
  const [enquiryPhone, setEnquiryPhone] = useState('');
  const [enquiryService, setEnquiryService] = useState('');
  const [enquirySubmitted, setEnquirySubmitted] = useState(false);

  const handleEnquirySubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!enquiryName || !enquiryPhone) {
      alert('Please enter your name and phone number.');
      return;
    }
    setEnquirySubmitted(true);
  };

  const toggleFaq = (index: number) => {
    setOpenFaqIndex(openFaqIndex === index ? null : index);
  };

  const faqItems = [
    {
      question: 'What areas in Patna does WashNLaundry serve?',
      answer: 'WashNLaundry currently provides laundry and dry cleaning services to several active pincodes in Patna, Bihar, including Bailey Road, Lohiya Path, Chotti Rukanpura, Saguna More, Kankarbagh, and surrounding areas. You can enter your pincode in our checker above to verify serviceability.'
    },
    {
      question: 'How does the 24-hour pickup and delivery work?',
      answer: 'Once you schedule a booking on our website, a WashNLaundry rider will arrive in an electric vehicle (EV) to collect your laundry. We process your garments using eco-friendly detergents at our specialized facility and deliver them back to your doorstep within 24 hours, freshly cleaned, ironed, and neatly folded.'
    },
    {
      question: 'Do you offer express delivery for urgent laundry?',
      answer: 'Yes! We offer a 4-hour express "Sprint" service at checkout for steam ironing and quick wash services. This is perfect for last-minute business meetings or special occasions.'
    },
    {
      question: 'What makes WashNLaundry eco-friendly?',
      answer: 'We care deeply about Patna\'s environment. We use 100% biodegradable detergents, recycle water in our washing machines, deliver using our proprietary EV fleet to reduce carbon emissions, and package all your garments in reusable, zero-plastic packaging.'
    },
    {
      question: 'What are the pricing rates for laundry and dry cleaning?',
      answer: 'Our rates start at ₹20 per piece for Wash & Fold, ₹25 per piece for Wash & Iron, ₹15 per piece for Steam Ironing, and ₹70 per piece for dry cleaning. You can view the full pricing breakdown on our Services page.'
    }
  ];

  const localBusinessSchema = {
    "@context": "https://schema.org",
    "@type": "LaundryBusiness",
    "name": "WashNLaundry",
    "image": "https://washnlaundry.com/logo.png",
    "@id": "https://washnlaundry.com",
    "url": "https://washnlaundry.com",
    "telephone": "+9108407000048",
    "priceRange": "$$",
    "address": {
      "@type": "PostalAddress",
      "streetAddress": "Bailey Road, near Shyama Apartment, Lohiya Path, Chotti Rukanpura",
      "addressLocality": "Patna",
      "addressRegion": "Bihar",
      "postalCode": "800025",
      "addressCountry": "IN"
    },
    "geo": {
      "@type": "GeoCoordinates",
      "latitude": 25.6112,
      "longitude": 85.0874
    },
    "openingHoursSpecification": {
      "@type": "OpeningHoursSpecification",
      "dayOfWeek": [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday"
      ],
      "opens": "08:00",
      "closes": "20:00"
    },
    "sameAs": [
      "https://www.instagram.com/WashNLaundry"
    ]
  };

  const faqSchema = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": faqItems.map((item) => ({
      "@type": "Question",
      "name": item.question,
      "acceptedAnswer": {
        "@type": "Answer",
        "text": item.answer
      }
    }))
  };


  const handlePincodeSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!pincode || pincode.trim().length !== 6) {
      setCheckStatus('error');
      return;
    }

    setChecking(true);
    setCheckStatus('idle');

    setTimeout(() => {
      setChecking(false);
      if (ACTIVE_PINCODES.includes(pincode.trim())) {
        setCheckStatus('success');
      } else {
        setCheckStatus('error');
      }
    }, 800);
  };

  const handleServiceSelect = (serviceKey: string) => {
    setSelectedService(serviceKey);
    router.push('/services');
  };

  const services = [
    {
      key: 'wash-fold',
      name: 'Wash & Fold',
      desc: 'Professionally washed, tumble-dried, and neatly folded everyday apparel.',
      icon: '🧺',
      rate: '₹20/piece',
      color: 'var(--color-wash-fold)',
      bgColor: 'rgba(0, 116, 188, 0.08)',
    },
    {
      key: 'wash-iron',
      name: 'Wash & Iron',
      desc: 'Thorough cleaning followed by professional ironing for crisp, clean apparel.',
      icon: '👕',
      rate: '₹25/piece',
      color: 'var(--color-wash-iron)',
      bgColor: 'rgba(198, 62, 150, 0.08)',
    },
    {
      key: 'steam-iron',
      name: 'Steam Ironing',
      desc: 'High-pressure steam treatment to eliminate creases and refresh fabric styling.',
      icon: '💨',
      rate: '₹15/piece',
      color: 'var(--color-steam-iron)',
      bgColor: 'rgba(104, 80, 161, 0.08)',
    },
    {
      key: 'dry-clean',
      name: 'Dry Cleaning',
      desc: 'Expert care and chemical processing for delicate, premium, and formal wear.',
      icon: '✨',
      rate: '₹70/piece',
      color: 'var(--color-dry-clean)',
      bgColor: 'rgba(0, 149, 153, 0.08)',
    },
  ];

  return (
    <div>
      {/* 1. Hero Section */}
      <section className={styles.hero}>
        <div className={`container ${styles.heroContent}`}>
          <div className={styles.heroLeft}>
            <h1 className={styles.heroTitle}>
              Professional <br />
              <span className={styles.heroTitleHighlight}>LAUNDRY & DRY</span> <br />
              Cleaning Services
            </h1>
            <p className={styles.heroDesc}>
              Reliable, hygienic, and consistent laundry solutions
            </p>

            <div className={styles.heroButtons}>
              <a href="tel:08407000048" className={styles.btnCall}>
                <span className={styles.btnIcon}>📞</span> Call Us!
              </a>
              <a 
                href="https://wa.me/9108407000048" 
                target="_blank" 
                rel="noopener noreferrer" 
                className={styles.btnWhatsapp}
              >
                <span className={styles.btnIcon}>💬</span> WhatsApp Us
              </a>
            </div>
          </div>

          <div className={styles.heroRight}>
            <div className={styles.enquiryCard}>
              <h3 className={styles.enquiryTitle}>Get in Touch</h3>
              {enquirySubmitted ? (
                <div className={styles.enquirySuccess}>
                  <h4>🎉 Thank You!</h4>
                  <p>Your callback request has been received. We will contact you shortly.</p>
                </div>
              ) : (
                <form onSubmit={handleEnquirySubmit} className={styles.enquiryForm}>
                  <input
                    type="text"
                    placeholder="Full Name"
                    className={styles.formInput}
                    value={enquiryName}
                    onChange={(e) => setEnquiryName(e.target.value)}
                    required
                  />
                  <input
                    type="email"
                    placeholder="Email address"
                    className={styles.formInput}
                    value={enquiryEmail}
                    onChange={(e) => setEnquiryEmail(e.target.value)}
                  />
                  <input
                    type="tel"
                    placeholder="Phone"
                    className={styles.formInput}
                    value={enquiryPhone}
                    onChange={(e) => setEnquiryPhone(e.target.value)}
                    required
                  />
                  <select
                    className={styles.formSelect}
                    value={enquiryService}
                    onChange={(e) => setEnquiryService(e.target.value)}
                    required
                  >
                    <option value="" disabled>Choose Service</option>
                    <option value="wash-fold">Wash & Fold</option>
                    <option value="wash-iron">Wash & Iron</option>
                    <option value="steam-iron">Steam Ironing</option>
                    <option value="dry-clean">Dry Cleaning</option>
                  </select>
                  <button type="submit" className={styles.formSubmitBtn}>
                    Submit
                  </button>
                </form>
              )}
            </div>

            {/* Bottom Indicators */}
            <div className={styles.indicators}>
              <div className={styles.indicatorPill}>
                <span>📞</span> 08407000048
              </div>
              <div className={styles.indicatorPill}>
                <span>🕒</span> 9am - 8pm
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* 2. Services Section */}
      <section className="section-padding" style={{ backgroundColor: '#ffffff' }}>
        <div className="container">
          <h2 className={styles.servicesTitle}>Our Professional Services</h2>
          <p className={styles.servicesSubtitle}>
            We handle everything from daily wear to premium silk sarees, leather jackets, and heavy comforters with specialized care.
          </p>

          <div className={styles.servicesGrid}>
            {services.map((service) => (
              <div
                key={service.key}
                className={styles.serviceCard}
                style={{ '--card-accent': service.color, '--card-accent-bg': service.bgColor } as React.CSSProperties}
                onClick={() => handleServiceSelect(service.key)}
              >
                <div className={styles.serviceIcon}>{service.icon}</div>
                <h3 className={styles.serviceName}>{service.name}</h3>
                <p className={styles.serviceDesc}>{service.desc}</p>
                <span className={styles.serviceRate}>Starts at {service.rate}</span>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 3. ClubUltimate Autopilot Section */}
      <section className="container">
        <div className={styles.clubSection}>
          <div className={styles.clubGrid}>
            <div>
              <h2 className={styles.clubTitle}>Put Your Laundry on Autopilot</h2>
              <h3 className={styles.clubSubtitle}>Introducing ClubUltimate Memberships</h3>
              <p className={styles.clubText}>
                No more scheduling pick-ups every week. Enjoy automated recurring schedules, zero delivery charges, guaranteed priority slots, and flat cashbacks. Starting at just ₹149/month.
              </p>
              <button onClick={() => router.push('/club-ultimate')} className="btn-secondary">
                Explore Membership Plans
              </button>
            </div>
            <div className={styles.clubRight}>
              <ul className={styles.clubBenefitsList}>
                <li className={styles.clubBenefitItem}>
                  <span className={styles.clubBenefitCheck}>✓</span> Guaranteed pickup slot availability
                </li>
                <li className={styles.clubBenefitItem}>
                  <span className={styles.clubBenefitCheck}>✓</span> Set autopilot recurring schedules
                </li>
                <li className={styles.clubBenefitItem}>
                  <span className={styles.clubBenefitCheck}>✓</span> Up to 10% monthly cashback
                </li>
                <li className={styles.clubBenefitItem}>
                  <span className={styles.clubBenefitCheck}>✓</span> Zero surge pricing, zero delivery fees
                </li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* 4. How It Works Section */}
      <section className="section-padding" style={{ backgroundColor: '#ffffff' }}>
        <div className="container">
          <h2 className={styles.hiwTitle}>How WashNLaundry Works</h2>
          <div className={styles.hiwTimeline}>
            <div className={styles.hiwStep}>
              <div className={styles.hiwNum}>1</div>
              <h3 className={styles.hiwHeading}>You Schedule</h3>
              <p className={styles.hiwText}>
                Select the items you want cleaned, pick a pickup and delivery window, and book in a couple of clicks.
              </p>
            </div>
            <div className={styles.hiwStep}>
              <div className={styles.hiwNum}>2</div>
              <h3 className={styles.hiwHeading}>We Clean</h3>
              <p className={styles.hiwText}>
                Our specialized facilities wash, dry, iron, or dry-clean your garments using eco-friendly materials.
              </p>
            </div>
            <div className={styles.hiwStep}>
              <div className={styles.hiwNum}>3</div>
              <h3 className={styles.hiwHeading}>We Deliver</h3>
              <p className={styles.hiwText}>
                Your fresh, neatly packed clothes are brought back to your doorstep within 24 hours via our EV fleet.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* 5. Testimonials Section */}
      <section className="section-padding">
        <div className="container">
          <h2 className={styles.testimonialsTitle}>What Our Customers Say</h2>
          <p className={styles.testimonialsSubtitle}>
            Join thousands of happy households in Patna who use WashNLaundry.
          </p>

          <div className={styles.testimonialsGrid}>
            <div className={styles.testCard}>
              <div className={styles.testStars}>★★★★★</div>
              <p className={styles.testQuote}>
                &quot;Absolutely flawless service. The 24-hour turnaround is real. The clothes came back smelling fresh, folded beautifully, and delivered in zero-plastic packaging. Highly recommended!&quot;
              </p>
              <div className={styles.testUser}>
                <div className={styles.testAvatar}>R</div>
                <div className={styles.testUserInfo}>
                  <span className={styles.testName}>Rohan Sharma</span>
                  <span className={styles.testLoc}>Chotti Rukanpura, Patna</span>
                </div>
              </div>
            </div>

            <div className={styles.testCard}>
              <div className={styles.testStars}>★★★★★</div>
              <p className={styles.testQuote}>
                &quot;ClubUltimate has put my laundry on autopilot. I have set weekly Saturday morning pickups. The delivery rider arrives in an EV exactly on time. Outstanding convenience.&quot;
              </p>
              <div className={styles.testUser}>
                <div className={styles.testAvatar}>P</div>
                <div className={styles.testUserInfo}>
                  <span className={styles.testName}>Priya Patel</span>
                  <span className={styles.testLoc}>Saguna More, Patna</span>
                </div>
              </div>
            </div>

            <div className={styles.testCard}>
              <div className={styles.testStars}>★★★★★</div>
              <p className={styles.testQuote}>
                &quot;Tried their Steam Ironing express. Got my formal wear back in 4 hours flat. The quality of packaging and care is superior to any local ironwalas around.&quot;
              </p>
              <div className={styles.testUser}>
                <div className={styles.testAvatar}>A</div>
                <div className={styles.testUserInfo}>
                  <span className={styles.testName}>Amit Verma</span>
                  <span className={styles.testLoc}>Kankarbagh, Patna</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* 6. FAQ Section (GEO/AEO Optimization) */}
      <section className={styles.faqSection}>
        <div className="container">
          <h2 className={styles.faqTitle}>Frequently Asked Questions</h2>
          <p className={styles.faqSubtitle}>
            Got questions about our Patna laundry & dry cleaning service? We have got answers.
          </p>

          <div className={styles.faqContainer}>
            {faqItems.map((item, idx) => (
              <div
                key={idx}
                className={`${styles.faqItem} ${openFaqIndex === idx ? styles.faqItemActive : ''}`}
              >
                <button
                  className={styles.faqQuestion}
                  onClick={() => toggleFaq(idx)}
                  aria-expanded={openFaqIndex === idx}
                >
                  <span>{item.question}</span>
                  <span className={`${styles.faqIcon} ${openFaqIndex === idx ? styles.faqIconActive : ''}`}>
                    +
                  </span>
                </button>
                <div className={`${styles.faqAnswer} ${openFaqIndex === idx ? styles.faqAnswerActive : ''}`}>
                  <p className={styles.faqAnswerText}>{item.answer}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* JSON-LD Schemas for Search & AI Engines */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(localBusinessSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }}
      />
    </div>
  );
}

