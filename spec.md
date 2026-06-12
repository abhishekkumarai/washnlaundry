# WashNLaundry - Project Specification

## 1. Project Overview
This project is a high-performance, visually premium Next.js website inspired by [LaundryMate](https://laundrymate.in/) rebranded as **WashNLaundry**. It targets urban consumers with a seamless booking flow, pricing estimator, interactive order tracker, subscription plans, and sustainability initiatives representation.

The application is optimized for deployment on Vercel.

---

## 2. Design & Branding System
Inspired by the core branding of LaundryMate and reimagined for WashNLaundry, the website uses a modern, vibrant color scheme, smooth micro-animations, premium typography, and responsive grid layouts.

### Typography
- **Primary Font**: Merriweather Sans / Inter (fallback) for clean, high-readability interfaces.
- **Secondary Font**: Merriweather / Serif (fallback) for elegant headings.

### Color Palette (CSS Custom Properties)
- **Primary Blue**: `#0074bc` (Used for primary branding, buttons, Wash & Fold representation)
- **Highlight Yellow**: `#ffcc04` (Used for secondary buttons, important details, notifications)
- **Wash & Iron Pink**: `#c63e96`
- **Steam Ironing Purple**: `#6850a1`
- **Dry Cleaning Teal**: `#009599`
- **Express Sprint Orange**: `#E76400`
- **Dark Text (Title)**: `#0f0f0f`
- **Medium Text (Body)**: `#4d4d4d`
- **Light BG**: `#f7f7f8`
- **White**: `#ffffff`

### Design Accents
- Glassmorphism effects for cards and floating bars.
- Custom HSL-based shadow systems.
- Smooth transitions (`cubic-bezier(0.4, 0, 0.2, 1)`) on interactive actions.
- Clear structural layout suitable for both desktop and mobile viewports.

---

## 3. Page Structure & Features

The web app is structured as a Next.js App Router application with the following routes:

### 3.1. Landing Page (`/`)
- **Hero Banner**: Engaging title "Your Laundry, on Autopilot", dynamic delivery timeline display, and an interactive pin/zip code checker.
- **Services Grid**: Visual selection of services (Wash & Fold, Wash & Iron, Steam Ironing, Dry Cleaning, WashNLaundry Sprint) with hover zoom and custom accent styling.
- **ClubUltimate Membership Section**: Banner showcasing the monthly autopilot laundry subscription starting from â‚¹149.
- **How It Works**: Sleek vertical/horizontal timeline showing:
  1. Schedule Pickup
  2. Professional Care
  3. 24h Express Turnaround
- **Sustainability Promise**: Details on EV deliveries, recycled water usage, and zero plastic packaging.
- **Customer Testimonials**: Premium testimonial cards grid with client reviews.

### 3.2. Services & Pricing Page (`/services`)
- **Garment Price Calculator**:
  - Interactive item selection (Men, Women, Household, Bedding).
  - Add/remove items with quantity selectors.
  - Choose service type to calculate instant estimated pricing.
- **Detailed Service Profiles**: Detailed breakdowns of processing steps for dry cleaning vs. steam ironing.

### 3.3. ClubUltimate Page (`/club-ultimate`)
- **Subscription Tier Presentation**: Pricing structure detailing plan benefits.
- **ROI / Savings Calculator**: An interactive slider allowing users to estimate their monthly laundry loads and see their projected savings.
- **FAQ Section**: Accordion detailing subscription rules (rollover, scheduling, cancellations).

### 3.4. Booking Engine (`/book`)
- A modern multi-step scheduling wizard:
  - **Step 1: Item Basket**: Select service types and quantity of items.
  - **Step 2: Scheduling**: Pick pickup and delivery dates and time slots (featuring standard 24h delivery vs. Sprint 4-hour option).
  - **Step 3: Address & Contact**: Enter address, landmark, and phone details.
  - **Step 4: Summary & Confirm**: Review order layout and complete checkout mock.

### 3.5. Order Tracker Dashboard (`/track`)
- **Order Stepper**: Live tracking tracker showing:
  - *Order Placed -> Rider Picked Up -> Washing & Dry Cleaning -> Quality Inspection -> Out for Delivery -> Completed*
- **Delivery Agent Details**: Mock information block featuring driver photo, vehicle (EV), contact, and ETA timer.

### 3.6. About & Eco-Impact (`/about`)
- Overview of WashNLaundry's tech-driven operations.
- Interactive counters for gallons of water saved, EV miles driven, and clothes cleaned.

---

## 4. Technical Architecture

- **Framework**: Next.js 14/15 (App Router, React server components)
- **Styling**: Vanilla CSS using CSS Modules (`*.module.css`) to maintain clean scoped styling without heavy external libraries.
- **State Management**: React Context / React hooks for cart calculations and checkout states.
- **SEO & Performance**: 
  - Dynamic page metadata.
  - Semantic HTML tags (`<header>`, `<main>`, `<footer>`, `<section>`).
  - Next.js `<Image>` component optimization.
- **Deployment**: Configured for instant deployment on Vercel.

