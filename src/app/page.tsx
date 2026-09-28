"use client";

import { useState, useEffect } from "react";
import { 
  ArrowRight, 
  Check, 
  ChevronDown, 
  Clock3, 
  MapPin, 
  Menu, 
  Phone, 
  Shirt, 
  Sparkles, 
  X, 
  Cookie, 
  FileText, 
  Navigation,
  CheckCircle2
} from "lucide-react";

const services = [
  {
    number: "01",
    title: "Wash & Fold",
    image: "/images/5.png",
    tag: "Everyday Care",
    copy: "Everyday essentials washed with filtered soft water, tumble-dried, and neatly folded with hotel-level care.",
  },
  {
    number: "02",
    title: "Dry Cleaning",
    image: "/images/1.png",
    tag: "Fine Fabrics",
    copy: "Specialized solvent care for tailoring, suits, silks, designer occasionwear, and delicate garments.",
  },
  {
    number: "03",
    title: "Press & Finish",
    image: "/images/3.png",
    tag: "Crisp Polish",
    copy: "A precise high-pressure steam press on commercial boilers that restores structure, crisp lines, and fabric polish.",
  },
];

const standards = [
  {
    num: "01",
    title: "Collected with care",
    desc: "Your clothes are tagged, separated by fabric type, and handled by a dedicated care team from door to door.",
  },
  {
    num: "02",
    title: "Finished to a higher bar",
    desc: "Commercial-grade equipment, gentle eco-friendly detergents, and a rigorous quality check before packing.",
  },
  {
    num: "03",
    title: "Returned on your schedule",
    desc: "Convenient pickup and return time windows. Every garment returned fresh, protected, and ready to wear.",
  },
  {
    num: "04",
    title: "Always within reach",
    desc: "Our local support team is available seven days a week, ready to assist whenever you have a question.",
  },
];

const serviceAreas = [
  { name: "Boring Road & Canal Road", status: "Active Doorstep Service", timing: "08:00 AM – 08:00 PM" },
  { name: "Patliputra Colony & Industrial Area", status: "Active Doorstep Service", timing: "08:00 AM – 08:00 PM" },
  { name: "Bailey Road & Raja Bazar", status: "Active Doorstep Service", timing: "08:00 AM – 08:00 PM" },
  { name: "Kankarbagh Main Road", status: "Active Doorstep Service", timing: "09:00 AM – 07:00 PM" },
  { name: "Anisabad & Phulwari Sharif", status: "Active Doorstep Service", timing: "09:00 AM – 07:00 PM" },
  { name: "Danapur Cantt & Saguna More", status: "Active Doorstep Service", timing: "09:00 AM – 07:00 PM" },
];

export default function LandingPage() {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [formData, setFormData] = useState({
    name: "",
    phone: "",
    service: "Wash & Fold",
    address: "",
  });
  const [submitted, setSubmitted] = useState(false);

  // Modals & Floating Banners
  const [isLocationModalOpen, setIsLocationModalOpen] = useState(false);
  const [isTermsModalOpen, setIsTermsModalOpen] = useState(false);
  const [isCookiesModalOpen, setIsCookiesModalOpen] = useState(false);
  const [showCookieBanner, setShowCookieBanner] = useState(false);
  
  // Geolocation detection
  const [detectingLocation, setDetectingLocation] = useState(false);
  const [locationResult, setLocationResult] = useState<string | null>(null);

  useEffect(() => {
    const cookieConsent = localStorage.getItem("wnl_cookie_consent");
    if (!cookieConsent) {
      setShowCookieBanner(true);
    }
  }, []);

  const handleAcceptCookies = () => {
    localStorage.setItem("wnl_cookie_consent", "accepted");
    setShowCookieBanner(false);
    setIsCookiesModalOpen(false);
  };

  const handleTrackCurrentLocation = () => {
    setDetectingLocation(true);
    setLocationResult(null);

    if (!navigator.geolocation) {
      setDetectingLocation(false);
      setLocationResult("Geolocation is not supported by your browser. Please type your locality.");
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude } = position.coords;
        const isPatnaRegion = latitude >= 25.5 && latitude <= 25.7 && longitude >= 85.0 && longitude <= 85.3;
        
        setDetectingLocation(false);
        const detectedText = isPatnaRegion
          ? "Location confirmed: Patna Central Service Zone. Doorstep pickup is available."
          : `Coordinates detected (${latitude.toFixed(3)}° N, ${longitude.toFixed(3)}° E). Doorstep collection active in all central zones.`;
        
        setLocationResult(detectedText);
        setFormData(prev => ({
          ...prev,
          address: prev.address ? prev.address : "Detected Area: Central Patna Service Zone"
        }));
      },
      () => {
        setDetectingLocation(false);
        setLocationResult("Could not access location. Please check browser permissions or enter your area.");
      },
      { timeout: 8000 }
    );
  };

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setSubmitted(true);
  };

  return (
    <div className="min-h-screen bg-[#F8F7F5] text-[#141A24] flex flex-col antialiased selection:bg-[#182C4F] selection:text-white">
      {/* Clean Marketing Header */}
      <header className="sticky top-0 z-40 border-b border-[#E4E0D8] bg-[#F8F7F5]/90 backdrop-blur-md">
        <nav className="mx-auto flex max-w-[1240px] items-center justify-between px-5 py-4 lg:px-8">
          {/* Brand */}
          <a href="#home" className="flex items-center gap-3">
            <span className="flex h-10 w-10 items-center justify-center rounded-[10px] bg-[#182C4F] text-xs font-extrabold tracking-tight text-white shadow-xs">
              WNL
            </span>
            <span className="text-[17px] font-bold tracking-tight text-slate-900">
              Wash<span className="text-[#2563EB]">N</span>Laundry
            </span>
          </a>

          {/* Nav links */}
          <div className="hidden items-center gap-7 text-[13px] font-semibold text-[#64748B] md:flex">
            <a href="#services" className="transition-colors hover:text-[#182C4F]">
              Services
            </a>
            <a href="#standard" className="transition-colors hover:text-[#182C4F]">
              Our standard
            </a>
            <button
              onClick={() => {
                setIsLocationModalOpen(true);
                handleTrackCurrentLocation();
              }}
              className="flex items-center gap-1.5 transition-colors hover:text-[#182C4F] cursor-pointer"
            >
              <MapPin size={14} className="text-[#2563EB]" />
              <span>Track Location</span>
            </button>
            <a href="tel:08407000048" className="transition-colors hover:text-[#182C4F] flex items-center gap-1.5">
              <Phone size={13} className="text-[#2563EB]" />
              <span>08407 000 048</span>
            </a>
          </div>

          {/* Direct CTA */}
          <a
            href="#book"
            className="hidden items-center gap-2 rounded-full bg-[#182C4F] px-5 py-2.5 text-[13px] font-semibold text-white transition-all hover:bg-[#101E38] hover:-translate-y-0.5 shadow-xs md:flex"
          >
            <span>Book a pickup</span>
            <ArrowRight size={14} />
          </a>

          {/* Mobile menu toggle */}
          <button
            className="rounded-[8px] p-2 text-slate-700 hover:bg-slate-200/60 md:hidden"
            onClick={() => setIsMenuOpen(!isMenuOpen)}
            aria-label="Toggle navigation menu"
          >
            {isMenuOpen ? <X size={22} /> : <Menu size={22} />}
          </button>
        </nav>

        {/* Mobile menu drawer */}
        {isMenuOpen && (
          <div className="border-t border-[#E4E0D8] bg-[#F8F7F5] px-6 py-5 md:hidden">
            <div className="flex flex-col gap-4 text-sm font-semibold text-slate-800">
              <a href="#services" onClick={() => setIsMenuOpen(false)}>Services</a>
              <a href="#standard" onClick={() => setIsMenuOpen(false)}>Our standard</a>
              <button
                onClick={() => {
                  setIsMenuOpen(false);
                  setIsLocationModalOpen(true);
                  handleTrackCurrentLocation();
                }}
                className="text-left flex items-center gap-2 py-1 text-slate-800"
              >
                <MapPin size={16} className="text-[#2563EB]" />
                <span>Track Location & Coverage</span>
              </button>
              <a href="tel:08407000048" className="text-[#2563EB] flex items-center gap-1.5">
                <Phone size={14} />
                <span>08407 000 048</span>
              </a>
              <a
                href="#book"
                onClick={() => setIsMenuOpen(false)}
                className="mt-2 rounded-full bg-[#182C4F] px-4 py-3 text-center text-white"
              >
                Book a pickup
              </a>
            </div>
          </div>
        )}
      </header>

      {/* Main Container */}
      <main className="flex-1">
        {/* Hero Section */}
        <section id="home" className="mx-auto grid max-w-[1240px] gap-10 px-5 pb-16 pt-12 lg:grid-cols-[1.05fr_.95fr] lg:items-center lg:px-8 lg:pb-24 lg:pt-20">
          <div>
            <p className="eyebrow mb-6">
              Premium garment care, delivered
            </p>
            <h1 className="text-[clamp(3.2rem,6.5vw,6rem)] font-bold leading-[0.92] tracking-[-0.065em] text-[#141A24]">
              Laundry,<br />
              <span className="font-serif italic font-normal text-[#182C4F]">elevated.</span>
            </h1>
            <p className="mt-7 max-w-[480px] text-base lg:text-lg leading-relaxed text-[#64748B]">
              A better standard of care for the clothes you live in. We collect, clean, finish, and return every piece looking and feeling its best.
            </p>

            <div className="mt-8 flex flex-wrap items-center gap-4">
              <a
                href="#book"
                className="inline-flex items-center gap-2 rounded-full bg-[#182C4F] px-6 py-3.5 text-sm font-semibold text-white transition-transform hover:-translate-y-0.5 hover:bg-[#101E38] shadow-sm"
              >
                <span>Schedule a pickup</span>
                <ArrowRight size={15} />
              </a>
              <button
                onClick={() => {
                  setIsLocationModalOpen(true);
                  handleTrackCurrentLocation();
                }}
                className="inline-flex items-center gap-2 rounded-full border border-[#E4E0D8] bg-white px-5 py-3 text-sm font-semibold text-[#141A24] transition hover:bg-slate-50 cursor-pointer"
              >
                <MapPin size={15} className="text-[#2563EB]" />
                <span>Track Service Location</span>
              </button>
            </div>

            <div className="mt-12 flex gap-8 border-t border-[#E4E0D8] pt-6 text-xs text-[#64748B]">
              <div>
                <strong className="block text-sm font-bold text-[#141A24]">24–48 hrs</strong>
                <span>Typical turnaround</span>
              </div>
              <div>
                <strong className="block text-sm font-bold text-[#141A24]">7 Days</strong>
                <span>Doorstep collection</span>
              </div>
              <div>
                <strong className="block text-sm font-bold text-[#141A24]">100%</strong>
                <span>Fabric satisfaction promise</span>
              </div>
            </div>
          </div>

          {/* Right Visual Card with Canva Image 3 (Steaming Fresh Laundry in Wicker Hamper) */}
          <div className="relative min-h-[440px] lg:min-h-[520px] overflow-hidden rounded-[14px] bg-[#182C4F] flex flex-col justify-end p-8 sm:p-10 shadow-lg text-white group">
            <img 
              src="/images/3.png" 
              alt="Steaming freshly laundered and folded shirts in woven wicker basket" 
              className="absolute inset-0 h-full w-full object-cover opacity-90 transition-all duration-700 group-hover:scale-105"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-[#182C4F] via-[#182C4F]/30 to-transparent" />
            
            <div className="relative z-10">
              <p className="text-[10px] font-bold uppercase tracking-[0.22em] text-white/80 mb-2">
                The WashNLaundry Promise
              </p>
              <p className="font-serif italic text-2xl sm:text-3xl leading-tight max-w-[360px] text-white">
                “The kind of clean you can genuinely feel.”
              </p>
            </div>
          </div>
        </section>

        {/* Services Section with Canva Photography */}
        <section id="services" className="border-y border-[#E4E0D8] bg-[#F0EEE9]/60 px-5 py-16 lg:px-8 lg:py-24">
          <div className="mx-auto max-w-[1240px]">
            <div className="mb-12 flex flex-col justify-between gap-4 lg:flex-row lg:items-end">
              <div>
                <p className="eyebrow mb-2">What we do</p>
                <h2 className="text-3xl sm:text-5xl font-bold tracking-[-0.05em] text-[#141A24]">
                  Care that respects<br />
                  <span className="font-serif italic font-normal text-[#182C4F]">every fabric.</span>
                </h2>
              </div>
              <p className="max-w-[360px] text-xs sm:text-sm leading-relaxed text-[#64748B]">
                From weekly everyday essentials to your most cherished occasionwear, our process is built around quality and consistency.
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {services.map(({ number, title, copy, image, tag }) => (
                <article
                  key={number}
                  className="group bg-white rounded-[14px] border border-[#E4E0D8] overflow-hidden hover:border-[#182C4F] transition-all hover:shadow-md flex flex-col justify-between"
                >
                  <div>
                    {/* Visual Card Header */}
                    <div className="relative h-52 overflow-hidden bg-slate-100">
                      <img
                        src={image}
                        alt={title}
                        className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                      />
                      <div className="absolute top-3 left-3 bg-[#182C4F]/90 backdrop-blur-xs text-white text-[11px] font-mono font-bold px-2 py-0.5 rounded">
                        {number}
                      </div>
                      <div className="absolute top-3 right-3 bg-white/90 backdrop-blur-xs text-slate-800 text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded">
                        {tag}
                      </div>
                    </div>

                    <div className="p-6">
                      <h3 className="text-xl font-bold tracking-tight text-slate-900">{title}</h3>
                      <p className="mt-2.5 text-xs sm:text-sm leading-relaxed text-slate-500">{copy}</p>
                    </div>
                  </div>

                  <div className="px-6 pb-6 pt-2 border-t border-[#E4E0D8]/60">
                    <a
                      href="#book"
                      className="inline-flex items-center gap-1.5 text-xs font-bold text-[#182C4F] group-hover:text-[#2563EB] transition"
                    >
                      <span>Book this service</span>
                      <ArrowRight size={14} className="transition-transform group-hover:translate-x-1" />
                    </a>
                  </div>
                </article>
              ))}
            </div>
          </div>
        </section>

        {/* Standards Section with Canva Image 4 (Hand-to-Hand Delivery) */}
        <section id="standard" className="mx-auto max-w-[1240px] px-5 py-16 lg:px-8 lg:py-24">
          <div className="grid lg:grid-cols-[1fr_.9fr] gap-12 items-center">
            <div>
              <p className="eyebrow mb-2">Our standard</p>
              <h2 className="text-3xl sm:text-5xl font-bold tracking-[-0.06em] text-[#141A24]">
                The details<br />
                <span className="font-serif italic font-normal text-[#182C4F]">matter.</span>
              </h2>
              <p className="mt-4 text-sm text-[#64748B] leading-relaxed max-w-md">
                We treat laundry as garment craftsmanship, using gentle solvents, softened water, and dedicated quality checks before packing.
              </p>

              <div className="grid sm:grid-cols-2 gap-6 border-t border-[#E4E0D8] pt-8 mt-8">
                {standards.map((std) => (
                  <div key={std.num}>
                    <p className="text-3xl font-bold tracking-[-0.08em] text-[#182C4F]">{std.num}</p>
                    <h3 className="mt-2 text-sm font-bold text-slate-900">{std.title}</h3>
                    <p className="mt-1.5 text-xs leading-5 text-slate-500">{std.desc}</p>
                  </div>
                ))}
              </div>
            </div>

            {/* Right Photo Card with Canva 4 (Hand-to-Hand Laundry Handoff) */}
            <div className="relative rounded-[14px] overflow-hidden border border-[#E4E0D8] shadow-md bg-white">
              <img
                src="/images/4.png"
                alt="Hand-to-hand doorstep delivery of fresh white folded laundry"
                className="w-full h-auto object-cover"
              />
              <div className="p-5 bg-white border-t border-[#E4E0D8]">
                <div className="flex items-center gap-2">
                  <CheckCircle2 size={16} className="text-emerald-600" />
                  <span className="text-xs font-bold text-slate-900">Doorstep Collection &amp; Return</span>
                </div>
                <p className="text-xs text-slate-500 mt-1">
                  Handled exclusively by trained garment specialists with protective garment covers.
                </p>
              </div>
            </div>
          </div>
        </section>

        {/* Fabric Care Grid Showcase Banner (Canva Image 2) */}
        <section className="border-t border-[#E4E0D8] bg-[#F8F7F5] py-14">
          <div className="mx-auto max-w-[1240px] px-5 lg:px-8">
            <div className="bg-white rounded-[16px] border border-[#E4E0D8] p-8 sm:p-10 shadow-sm grid lg:grid-cols-[1.1fr_.9fr] gap-8 items-center">
              <div>
                <p className="eyebrow mb-2">Comprehensive Fabric Care</p>
                <h3 className="text-2xl sm:text-4xl font-bold tracking-tight text-slate-900">
                  Washing, drying, folding <br className="hidden sm:inline" />
                  <span className="font-serif italic font-normal text-[#182C4F]">&amp; delicate care.</span>
                </h3>
                <p className="mt-3 text-xs sm:text-sm text-slate-600 leading-relaxed max-w-lg">
                  Every fabric type has its own washing chemistry and temperature profile. From pure cotton bed linens to cashmere, silk sarees, and tailored suits, our specialists ensure gentle handling.
                </p>
                <div className="mt-6 flex flex-wrap items-center gap-3">
                  <a
                    href="#book"
                    className="inline-flex items-center gap-2 rounded-full bg-[#182C4F] px-5 py-2.5 text-xs font-bold text-white hover:bg-[#101E38] transition shadow-xs"
                  >
                    <span>Schedule a collection</span>
                    <ArrowRight size={13} />
                  </a>
                  <span className="text-xs text-slate-500 font-medium">Over 15 fabric care treatments available</span>
                </div>
              </div>

              {/* Showcase Image */}
              <div className="rounded-[12px] overflow-hidden border border-[#E4E0D8] shadow-xs">
                <img
                  src="/images/2.png"
                  alt="15 laundry and garment care services grid"
                  className="w-full h-auto object-cover"
                />
              </div>
            </div>
          </div>
        </section>

        {/* Booking Form Section */}
        <section id="book" className="mx-auto max-w-[1240px] px-5 py-16 lg:px-8 lg:py-24 border-t border-[#E4E0D8]">
          <div className="grid lg:grid-cols-[1fr_.85fr] gap-12 items-center">
            <div>
              <p className="eyebrow mb-2">Ready when you are</p>
              <h2 className="text-3xl sm:text-5xl font-bold tracking-[-0.06em] text-[#141A24]">
                Give your week<br />
                back to <span className="font-serif italic font-normal text-[#182C4F]">you.</span>
              </h2>
              <p className="mt-4 text-sm sm:text-base leading-relaxed text-[#64748B] max-w-md">
                Tell us a little about what you need and our care team will contact you to schedule your first pickup.
              </p>

              <div className="mt-8 space-y-3 text-xs text-[#64748B]">
                <div className="flex items-center gap-2">
                  <Check size={16} className="text-emerald-600" />
                  <span>No upfront payment &mdash; confirmed on intake</span>
                </div>
                <div className="flex items-center gap-2">
                  <Check size={16} className="text-emerald-600" />
                  <span>Doorstep pickup with sanitized garment bags</span>
                </div>
                <div className="flex items-center gap-2">
                  <Check size={16} className="text-emerald-600" />
                  <span>SMS and WhatsApp updates on delivery</span>
                </div>
              </div>
            </div>

            {/* Form Card */}
            <div className="rounded-[12px] border border-[#E4E0D8] bg-white p-7 sm:p-9 shadow-sm">
              {submitted ? (
                <div className="flex min-h-[300px] flex-col items-start justify-center py-6">
                  <div className="flex h-12 w-12 items-center justify-center rounded-full bg-[#182C4F] text-white">
                    <Check size={22} />
                  </div>
                  <h3 className="mt-6 text-2xl font-bold text-slate-900">We’ll be in touch.</h3>
                  <p className="mt-2 text-xs text-slate-600 leading-relaxed">
                    Thank you, <span className="font-bold text-slate-900">{formData.name}</span>. A care specialist will contact you shortly at <span className="font-bold text-slate-900">{formData.phone}</span> to confirm your pickup time window.
                  </p>
                  <button
                    onClick={() => setSubmitted(false)}
                    className="mt-6 text-xs font-bold text-[#2563EB] hover:underline cursor-pointer"
                  >
                    ← Schedule another request
                  </button>
                </div>
              ) : (
                <form onSubmit={handleSubmit} className="space-y-4">
                  <h3 className="text-xl font-bold text-slate-900 mb-1">Book your first pickup</h3>
                  <p className="text-xs text-slate-500 mb-4">No commitment. We’ll confirm all details before we start.</p>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">Full Name</label>
                    <input
                      required
                      placeholder="e.g. Abhishek Kumar"
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                      className="field"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">Phone Number</label>
                    <input
                      required
                      type="tel"
                      placeholder="e.g. 08407 000 048"
                      value={formData.phone}
                      onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                      className="field"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1">Service Required</label>
                    <div className="relative">
                      <select
                        value={formData.service}
                        onChange={(e) => setFormData({ ...formData, service: e.target.value })}
                        className="field appearance-none cursor-pointer"
                      >
                        <option>Wash & Fold</option>
                        <option>Dry Cleaning</option>
                        <option>Press & Finish</option>
                      </select>
                      <ChevronDown size={16} className="pointer-events-none absolute right-4 top-4 text-slate-400" />
                    </div>
                  </div>

                  <div>
                    <div className="flex items-center justify-between mb-1">
                      <label className="block text-xs font-semibold text-slate-700">Pickup Locality or Address</label>
                      <button
                        type="button"
                        onClick={handleTrackCurrentLocation}
                        className="text-[11px] font-bold text-[#2563EB] hover:text-[#182C4F] flex items-center gap-1 cursor-pointer"
                      >
                        <Navigation size={11} />
                        <span>{detectingLocation ? "Detecting..." : "Detect my location"}</span>
                      </button>
                    </div>
                    <input
                      placeholder="e.g. Boring Road, Patliputra, Bailey Road"
                      value={formData.address}
                      onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                      className="field"
                    />
                    {locationResult && (
                      <p className="mt-1.5 text-[11px] text-emerald-700 font-medium flex items-start gap-1">
                        <Check size={12} className="mt-0.5 flex-shrink-0" />
                        <span>{locationResult}</span>
                      </p>
                    )}
                  </div>

                  <button
                    type="submit"
                    className="h-12 w-full rounded-[10px] bg-[#182C4F] hover:bg-[#101E38] text-white text-xs font-bold transition flex items-center justify-center gap-2 shadow-xs cursor-pointer mt-2"
                  >
                    <span>Request a pickup</span>
                    <ArrowRight size={15} />
                  </button>

                  <p className="text-center text-[11px] text-slate-400 mt-2">
                    Doorstep collection available 7 days a week.
                  </p>
                </form>
              )}
            </div>
          </div>
        </section>
      </main>

      {/* Clean Footer with Terms, Cookies & Location Links */}
      <footer className="border-t border-[#E4E0D8] bg-[#F0EEE9] py-12 text-xs text-[#64748B]">
        <div className="mx-auto flex max-w-[1240px] flex-col justify-between gap-8 px-5 lg:px-8">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div>
              <div className="flex items-center gap-3">
                <span className="flex h-8 w-8 items-center justify-center rounded-[8px] bg-[#182C4F] text-[10px] font-extrabold text-white">
                  WNL
                </span>
                <span className="font-bold text-slate-900 text-sm">WashNLaundry</span>
              </div>
              <p className="mt-2 text-xs text-slate-500 max-w-sm">
                Premium laundry and dry cleaning, collected and delivered with care across verified neighborhood service zones.
              </p>
            </div>

            <div className="flex flex-wrap gap-x-8 gap-y-2 text-xs font-semibold text-slate-600">
              <a href="#services" className="hover:text-slate-900">Services</a>
              <a href="#standard" className="hover:text-slate-900">Our standard</a>
              <button
                onClick={() => {
                  setIsLocationModalOpen(true);
                  handleTrackCurrentLocation();
                }}
                className="hover:text-slate-900 cursor-pointer flex items-center gap-1"
              >
                <MapPin size={12} className="text-[#2563EB]" />
                <span>Track Location</span>
              </button>
              <a href="tel:08407000048" className="hover:text-slate-900">08407 000 048</a>
            </div>
          </div>

          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-t border-[#E4E0D8] pt-6 text-[11px] text-slate-500">
            <div>
              © 2026 WashNLaundry Technologies Pvt Ltd. All rights reserved.
            </div>

            <div className="flex flex-wrap items-center gap-6 font-medium">
              <button
                onClick={() => setIsTermsModalOpen(true)}
                className="hover:text-slate-900 hover:underline cursor-pointer"
              >
                Terms and Conditions
              </button>
              <button
                onClick={() => setIsCookiesModalOpen(true)}
                className="hover:text-slate-900 hover:underline cursor-pointer flex items-center gap-1"
              >
                <Cookie size={12} className="text-amber-700" />
                <span>Cookies Policy</span>
              </button>
              <button
                onClick={() => setIsTermsModalOpen(true)}
                className="hover:text-slate-900 hover:underline cursor-pointer"
              >
                Privacy Policy
              </button>
            </div>
          </div>
        </div>
      </footer>

      {/* 1. TRACK LOCATION & COVERAGE MODAL */}
      {isLocationModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-xs animate-in fade-in duration-150">
          <div className="w-full max-w-lg bg-white rounded-[14px] border border-[#E4E0D8] shadow-2xl p-6 sm:p-7 relative">
            <button
              onClick={() => setIsLocationModalOpen(false)}
              className="absolute top-4 right-4 text-slate-400 hover:text-slate-700 p-1 rounded-lg"
              aria-label="Close location modal"
            >
              <X size={18} />
            </button>

            <div className="flex items-center gap-2.5 text-[#182C4F] mb-2">
              <MapPin size={20} className="text-[#2563EB]" />
              <h3 className="text-lg font-bold text-slate-900">Track Location & Service Coverage</h3>
            </div>
            <p className="text-xs text-slate-500 mb-4">
              Check active doorstep collection and return coverage for your neighborhood.
            </p>

            <div className="bg-[#F8F7F5] border border-[#E4E0D8] rounded-[10px] p-4 mb-5">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-bold text-slate-800">Live GPS Location Check</span>
                <button
                  onClick={handleTrackCurrentLocation}
                  disabled={detectingLocation}
                  className="px-3 py-1.5 bg-[#182C4F] hover:bg-[#101E38] text-white text-xs font-semibold rounded-[6px] transition flex items-center gap-1.5 cursor-pointer disabled:opacity-50"
                >
                  <Navigation size={12} />
                  <span>{detectingLocation ? "Detecting GPS..." : "Detect Current Location"}</span>
                </button>
              </div>

              {locationResult && (
                <div className="mt-2.5 p-2.5 bg-emerald-50 border border-emerald-200 rounded-[8px] text-xs text-emerald-800 flex items-start gap-2">
                  <Check size={14} className="mt-0.5 text-emerald-600 flex-shrink-0" />
                  <span>{locationResult}</span>
                </div>
              )}
            </div>

            <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-2.5">
              Active Doorstep Service Zones
            </h4>
            <div className="max-h-56 overflow-y-auto space-y-2 pr-1">
              {serviceAreas.map((area) => (
                <div
                  key={area.name}
                  className="flex items-center justify-between p-2.5 rounded-[8px] border border-[#E4E0D8] bg-white text-xs"
                >
                  <div>
                    <span className="font-semibold text-slate-900 block">{area.name}</span>
                    <span className="text-[11px] text-slate-400">{area.timing}</span>
                  </div>
                  <span className="inline-flex items-center gap-1 text-[11px] font-bold text-emerald-700 bg-emerald-50 border border-emerald-200 px-2 py-0.5 rounded-full">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                    {area.status}
                  </span>
                </div>
              ))}
            </div>

            <div className="mt-6 flex justify-end">
              <button
                onClick={() => setIsLocationModalOpen(false)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-800 text-xs font-bold rounded-[8px] transition cursor-pointer"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 2. TERMS AND CONDITIONS MODAL */}
      {isTermsModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-xs animate-in fade-in duration-150">
          <div className="w-full max-w-2xl bg-white rounded-[14px] border border-[#E4E0D8] shadow-2xl p-6 sm:p-8 relative max-h-[85vh] flex flex-col">
            <button
              onClick={() => setIsTermsModalOpen(false)}
              className="absolute top-5 right-5 text-slate-400 hover:text-slate-700 p-1 rounded-lg"
              aria-label="Close terms modal"
            >
              <X size={18} />
            </button>

            <div className="flex items-center gap-2.5 text-[#182C4F] mb-1">
              <FileText size={20} className="text-[#2563EB]" />
              <h3 className="text-xl font-bold text-slate-900">Terms and Conditions</h3>
            </div>
            <p className="text-xs text-slate-400 mb-4 pb-3 border-b border-[#E4E0D8]">
              Last updated: September 2026 · WashNLaundry Technologies Pvt Ltd
            </p>

            <div className="overflow-y-auto space-y-4 text-xs leading-relaxed text-slate-600 pr-2">
              <div>
                <h4 className="font-bold text-slate-900 text-sm mb-1">1. Scope of Service</h4>
                <p>
                  WashNLaundry provides doorstep pickup, fabric inspection, washing, dry cleaning, steam pressing, and return delivery services. Orders are processed based on the customer’s selected service categories and garment care instructions.
                </p>
              </div>

              <div>
                <h4 className="font-bold text-slate-900 text-sm mb-1">2. Garment Intake & Inspection</h4>
                <p>
                  All garments are physically inspected and tagged upon arrival at the care facility. Any pre-existing damage, stains, fabric tears, or loose buttons identified during intake will be documented and communicated before cleaning commences.
                </p>
              </div>

              <div>
                <h4 className="font-bold text-slate-900 text-sm mb-1">3. Care & Liability Policy</h4>
                <p>
                  We adhere strictly to manufacturer care labels. While utmost care is exercised with commercial-grade boilers and gentle solvents, we are not liable for intrinsic manufacturer defects, natural color migration in unlabelled garments, or tender aging fabrics.
                </p>
              </div>

              <div>
                <h4 className="font-bold text-slate-900 text-sm mb-1">4. Payment Terms</h4>
                <p>
                  No advance payment is required to book a pickup. Total billable amount is confirmed after garment intake count and weighing. Payment is due upon doorstep return via cash, UPI, or online card payment.
                </p>
              </div>

              <div>
                <h4 className="font-bold text-slate-900 text-sm mb-1">5. Cancellation & Rescheduling</h4>
                <p>
                  You may reschedule or cancel your pickup slot without any fee up to 1 hour prior to your designated collection window.
                </p>
              </div>
            </div>

            <div className="mt-6 pt-4 border-t border-[#E4E0D8] flex justify-end">
              <button
                onClick={() => setIsTermsModalOpen(false)}
                className="px-5 py-2.5 bg-[#182C4F] hover:bg-[#101E38] text-white text-xs font-bold rounded-[8px] transition cursor-pointer"
              >
                I Understand &amp; Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 3. COOKIES POLICY & PREFERENCES MODAL */}
      {isCookiesModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/60 backdrop-blur-xs animate-in fade-in duration-150">
          <div className="w-full max-w-md bg-white rounded-[14px] border border-[#E4E0D8] shadow-2xl p-6 sm:p-7 relative">
            <button
              onClick={() => setIsCookiesModalOpen(false)}
              className="absolute top-4 right-4 text-slate-400 hover:text-slate-700 p-1 rounded-lg"
              aria-label="Close cookies modal"
            >
              <X size={18} />
            </button>

            <div className="flex items-center gap-2.5 text-[#182C4F] mb-2">
              <Cookie size={20} className="text-amber-700" />
              <h3 className="text-lg font-bold text-slate-900">Cookie Preferences</h3>
            </div>
            <p className="text-xs text-slate-500 mb-4 leading-relaxed">
              We respect your privacy. Here is how we use cookies on this website:
            </p>

            <div className="space-y-3 mb-6">
              <div className="p-3 bg-[#F8F7F5] border border-[#E4E0D8] rounded-[8px]">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-slate-900">Essential Session Cookies</span>
                  <span className="text-[10px] font-bold text-slate-500 bg-slate-200 px-2 py-0.5 rounded">Always Active</span>
                </div>
                <p className="text-[11px] text-slate-500 mt-1">
                  Required for pickup request submission, form state persistence, and security verification.
                </p>
              </div>

              <div className="p-3 bg-[#F8F7F5] border border-[#E4E0D8] rounded-[8px]">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-slate-900">Location Cache</span>
                  <span className="text-[10px] font-bold text-emerald-700 bg-emerald-100 px-2 py-0.5 rounded">Active</span>
                </div>
                <p className="text-[11px] text-slate-500 mt-1">
                  Remembers your detected pickup cluster to confirm local service availability.
                </p>
              </div>
            </div>

            <div className="flex items-center justify-end gap-2">
              <button
                onClick={() => setIsCookiesModalOpen(false)}
                className="px-4 py-2 border border-[#E4E0D8] hover:bg-slate-50 text-slate-700 text-xs font-bold rounded-[8px] transition cursor-pointer"
              >
                Close
              </button>
              <button
                onClick={handleAcceptCookies}
                className="px-4 py-2 bg-[#182C4F] hover:bg-[#101E38] text-white text-xs font-bold rounded-[8px] transition cursor-pointer"
              >
                Save &amp; Accept
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 4. FLOATING COOKIE CONSENT BANNER */}
      {showCookieBanner && (
        <aside 
          aria-label="Cookie consent banner"
          className="fixed bottom-4 left-4 right-4 sm:left-auto sm:right-6 sm:max-w-md z-40 bg-white border border-[#E4E0D8] rounded-[12px] p-4 shadow-xl animate-in slide-in-from-bottom-5 duration-200"
        >
          <div className="flex items-start gap-3">
            <div className="w-8 h-8 rounded-[8px] bg-amber-50 text-amber-700 border border-amber-200 flex items-center justify-center flex-shrink-0">
              <Cookie size={16} />
            </div>
            <div className="flex-1">
              <p className="text-xs text-slate-700 leading-relaxed font-medium">
                We use cookies and approximate location data to verify local doorstep pickup availability in your area.
              </p>
              <div className="mt-3 flex items-center gap-2">
                <button
                  onClick={handleAcceptCookies}
                  className="px-3.5 py-1.5 bg-[#182C4F] hover:bg-[#101E38] text-white text-xs font-bold rounded-[6px] transition cursor-pointer shadow-xs"
                >
                  Accept Cookies
                </button>
                <button
                  onClick={() => setIsCookiesModalOpen(true)}
                  className="px-3 py-1.5 text-xs font-semibold text-slate-600 hover:text-slate-900 cursor-pointer"
                >
                  Preferences
                </button>
              </div>
            </div>
            <button
              onClick={() => setShowCookieBanner(false)}
              className="text-slate-400 hover:text-slate-600 p-1"
              aria-label="Dismiss cookie notice"
            >
              <X size={14} />
            </button>
          </div>
        </aside>
      )}
    </div>
  );
}
