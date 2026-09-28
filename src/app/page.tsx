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
  CheckCircle2,
  ArrowUp
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

const coverageAreas = [
  { name: "Boring Road", sub: "Canal Rd · Nageshwar", timing: "08:00 AM – 08:00 PM" },
  { name: "Patliputra", sub: "Colony · Industrial", timing: "08:00 AM – 08:00 PM" },
  { name: "Bailey Road", sub: "Raja Bazar · Pillar 50-80", timing: "08:00 AM – 08:00 PM" },
  { name: "Kankarbagh", sub: "Main Rd · Doctors Colony", timing: "09:00 AM – 07:00 PM" },
  { name: "Danapur Cantt", sub: "Saguna More · Station", timing: "09:00 AM – 07:00 PM" },
  { name: "Ashiana Nagar", sub: "Phases 1-2 · Ram Nagari", timing: "08:00 AM – 08:00 PM" },
  { name: "Rajendra Nagar", sub: "Stadium · Kadamkuan", timing: "09:00 AM – 07:00 PM" },
  { name: "SK Puri", sub: "Anandpuri · Children Park", timing: "08:00 AM – 08:00 PM" },
  { name: "Exhibition Road", sub: "Dak Bunglow · Frazer Rd", timing: "09:00 AM – 07:00 PM" },
  { name: "Anisabad", sub: "Golambar · Phulwari", timing: "09:00 AM – 07:00 PM" },
  { name: "Gola Road", sub: "RPS More · Vivekananda", timing: "09:00 AM – 07:00 PM" },
  { name: "Shastri Nagar", sub: "AG Colony · Rajbansi", timing: "08:00 AM – 08:00 PM" },
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

  // Floating action controls & scroll detection
  const [showScrollTop, setShowScrollTop] = useState(false);

  useEffect(() => {
    const cookieConsent = localStorage.getItem("wnl_cookie_consent");
    if (!cookieConsent) {
      setShowCookieBanner(true);
    }

    const handleScroll = () => {
      setShowScrollTop(window.scrollY > 300);
    };
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  const scrollToTop = () => {
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const trackAction = (actionName: string, meta?: Record<string, any>) => {
    if (typeof window !== "undefined" && (window as any).gtag) {
      (window as any).gtag("event", actionName, meta || {});
    }
  };

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
          <a href="#home" className="flex items-center gap-4 group">
            <img 
              src="/brand-logo.png" 
              alt="WashNLaundry Emblem" 
              className="h-20 w-20 sm:h-24 sm:w-24 object-contain rounded-full border-2 border-[#E4E0D8] bg-white p-1.5 group-hover:scale-105 transition-transform shadow-md flex-shrink-0" 
            />
            <div className="flex flex-col">
              <span className="text-2xl sm:text-[28px] font-black tracking-tight text-slate-900 leading-tight">
                Wash<span className="text-[#2563EB]">N</span>Laundry
              </span>
              <span className="text-xs sm:text-[13px] font-bold uppercase tracking-wider text-slate-500 mt-1">
                Give your dirty work to us
              </span>
            </div>
          </a>

          {/* Nav links */}
          <div className="hidden items-center gap-7 text-[13px] font-semibold text-[#64748B] md:flex">
            <a href="#services" className="transition-colors hover:text-[#182C4F]">
              Services
            </a>
            <a href="#standard" className="transition-colors hover:text-[#182C4F]">
              Our standard
            </a>
            <a href="#coverage" className="transition-colors hover:text-[#182C4F]">
              Areas
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
            <a 
              href="tel:08407000048" 
              onClick={() => trackAction("phone_call_click", { source: "header_desktop" })}
              className="transition-colors hover:text-[#182C4F] flex items-center gap-1.5"
            >
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
              <a href="#coverage" onClick={() => setIsMenuOpen(false)}>Servicing Areas</a>
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
              <a 
                href="tel:08407000048" 
                onClick={() => trackAction("phone_call_click", { source: "header_mobile" })}
                className="text-[#2563EB] flex items-center gap-1.5"
              >
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
            
            {/* Circular Official Seal Badge */}
            <div className="absolute top-5 right-5 sm:top-6 sm:right-6 z-20 w-24 h-24 sm:w-32 sm:h-32 rounded-full bg-white p-2 shadow-2xl backdrop-blur-xs flex items-center justify-center border-2 border-white/90 group-hover:scale-105 group-hover:rotate-6 transition-all duration-500">
              <img src="/brand-logo.png" alt="WashNLaundry Official Seal" className="w-full h-full object-contain" />
            </div>
            
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

        {/* Coverage & Servicing Areas - Square Box Grid */}
        <section id="coverage" className="border-t border-[#E4E0D8] bg-[#F8F7F5] py-20">
          <div className="mx-auto max-w-[1240px] px-5 lg:px-8">
            <div className="flex flex-col md:flex-row md:items-end justify-between gap-6 mb-10">
              <div>
                <div className="eyebrow mb-3">
                  <span className="h-1.5 w-1.5 rounded-full bg-[#2563EB]" />
                  <span>DOORSTEP COVERAGE DIRECTORY</span>
                </div>
                <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight text-[#182C4F]">
                  Servicing Areas &amp; <span className="font-serif italic font-normal text-slate-700">Active Clusters</span>
                </h2>
                <p className="mt-2 text-sm text-slate-600 max-w-xl">
                  Daily morning and evening pickup routes scheduled across primary neighborhoods with zero collection surcharge.
                </p>
              </div>

              <button
                onClick={() => {
                  setIsLocationModalOpen(true);
                  handleTrackCurrentLocation();
                }}
                className="inline-flex items-center gap-2 self-start md:self-auto rounded-[8px] border border-[#182C4F] bg-white px-4 py-2.5 text-xs font-bold text-[#182C4F] hover:bg-[#182C4F] hover:text-white transition shadow-xs cursor-pointer"
              >
                <Navigation size={13} className="text-[#2563EB]" />
                <span>Verify Your Neighborhood</span>
              </button>
            </div>

            {/* The Main Square Box Container */}
            <div className="rounded-[16px] border border-[#E4E0D8] bg-white p-6 sm:p-8 shadow-xs">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-6 mb-6 border-b border-[#ECE9E2]">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-[10px] bg-[#182C4F] flex items-center justify-center text-white">
                    <MapPin size={20} className="text-sky-400" />
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-slate-900">Patna Urban Coverage Hubs</h3>
                    <p className="text-xs text-slate-500">Tap any zone box to select it for your pickup booking</p>
                  </div>
                </div>

                <div className="flex items-center gap-2 text-[11px] font-semibold text-slate-700 bg-[#F8F7F5] border border-[#E4E0D8] px-3 py-1.5 rounded-[8px]">
                  <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                  <span>12 Active Daily Routes</span>
                </div>
              </div>

              {/* Grid of Square Area Boxes */}
              <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3.5 sm:gap-4">
                {coverageAreas.map((area, idx) => (
                  <div
                    key={area.name}
                    onClick={() => {
                      setFormData({ ...formData, address: area.name });
                      const formElement = document.getElementById("book");
                      if (formElement) formElement.scrollIntoView({ behavior: "smooth" });
                    }}
                    className="group relative flex flex-col justify-between aspect-square rounded-[12px] border border-[#E4E0D8] bg-[#F8F7F5] p-3.5 sm:p-4 hover:border-[#182C4F] hover:bg-white hover:shadow-md transition-all duration-200 cursor-pointer text-left"
                  >
                    <div className="flex items-center justify-between w-full">
                      <span className="text-[10px] font-bold text-slate-400 font-mono group-hover:text-[#2563EB] transition-colors">
                        ZONE {String(idx + 1).padStart(2, "0")}
                      </span>
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" title="Active Daily Pickup" />
                    </div>

                    <div className="my-auto py-1">
                      <span className="block text-xs sm:text-sm font-bold text-[#182C4F] leading-tight group-hover:text-[#2563EB] transition-colors">
                        {area.name}
                      </span>
                      <span className="block text-[10px] text-slate-500 mt-1 font-medium leading-tight">
                        {area.sub}
                      </span>
                    </div>

                    <div className="pt-2 border-t border-[#ECE9E2] flex items-center justify-between text-[10px] text-slate-500">
                      <span className="text-[9.5px] font-medium text-slate-500 truncate">{area.timing}</span>
                      <span className="text-[#2563EB] font-bold opacity-0 group-hover:opacity-100 transition-opacity">
                        Select →
                      </span>
                    </div>
                  </div>
                ))}
              </div>

              {/* Box Footer Note */}
              <div className="mt-6 pt-5 border-t border-[#ECE9E2] flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs text-slate-500">
                <p className="flex items-center gap-2">
                  <Clock3 size={13} className="text-[#182C4F]" />
                  <span>Doorstep collection available 7 days a week. Same-day pickup for requests before 1:00 PM.</span>
                </p>
                <span className="text-[11px] text-slate-400">
                  Dispatch Helpline: <a 
                    href="tel:08407000048" 
                    onClick={() => trackAction("phone_call_click", { source: "servicing_areas_helpline" })}
                    className="font-semibold text-[#182C4F] hover:underline"
                  >
                    08407 000 048
                  </a>
                </span>
              </div>
            </div>
          </div>
        </section>
      </main>

      {/* Clean Footer with Terms, Cookies & Location Links */}
      <footer className="border-t border-[#E4E0D8] bg-[#F0EEE9] py-12 text-xs text-[#64748B]">
        <div className="mx-auto flex max-w-[1240px] flex-col justify-between gap-8 px-5 lg:px-8">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div>
              <div className="flex items-center gap-4">
                <img 
                  src="/brand-logo.png" 
                  alt="WashNLaundry Official Emblem" 
                  className="h-18 w-18 sm:h-22 sm:w-22 object-contain rounded-full border-2 border-[#E4E0D8] bg-white p-1.5 shadow-sm flex-shrink-0" 
                />
                <div>
                  <span className="font-black text-slate-900 text-xl sm:text-2xl block leading-tight">WashNLaundry</span>
                  <span className="text-xs sm:text-[13px] font-bold text-slate-500 uppercase tracking-wider block mt-1">Give your dirty work to us</span>
                </div>
              </div>
              <p className="mt-2 text-xs text-slate-500 max-w-sm">
                Premium laundry and dry cleaning, collected and delivered with care across verified neighborhood service zones.
              </p>
            </div>

            <div className="flex flex-wrap gap-x-8 gap-y-2 text-xs font-semibold text-slate-600">
              <a href="#services" className="hover:text-slate-900">Services</a>
              <a href="#standard" className="hover:text-slate-900">Our standard</a>
              <a href="#coverage" className="hover:text-slate-900">Servicing Areas</a>
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
              <a 
                href="tel:08407000048" 
                onClick={() => trackAction("phone_call_click", { source: "footer" })}
                className="hover:text-slate-900"
              >
                08407 000 048
              </a>
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

      {/* Floating Quick Action Buttons: Scroll-to-Top, Call, WhatsApp */}
      <aside aria-label="Quick contact actions" className="fixed bottom-6 right-5 sm:right-6 z-40 flex flex-col items-end gap-3.5 pointer-events-none">
        {/* Scroll to Top Button */}
        {showScrollTop && (
          <button
            onClick={scrollToTop}
            aria-label="Scroll to top of page"
            className="pointer-events-auto flex items-center justify-center w-12 h-12 rounded-full bg-white hover:bg-slate-100 text-[#182C4F] border border-[#E4E0D8] shadow-xl hover:shadow-2xl transition-all duration-200 hover:-translate-y-0.5 cursor-pointer group"
            title="Scroll to top"
          >
            <ArrowUp size={20} className="transition-transform group-hover:-translate-y-0.5" />
          </button>
        )}

        {/* Call Floating Button */}
        <a
          href="tel:08407000048"
          onClick={() => trackAction("phone_call_click", { source: "floating_fab" })}
          aria-label="Call Dispatch 08407 000 048"
          className="pointer-events-auto flex items-center gap-2.5 px-4 h-13 rounded-full bg-[#182C4F] hover:bg-[#101E38] text-white shadow-xl hover:shadow-2xl transition-all duration-200 hover:-translate-y-0.5 group"
          title="Call 08407 000 048"
        >
          <div className="w-8.5 h-8.5 rounded-full bg-white/10 flex items-center justify-center group-hover:scale-110 transition-transform">
            <Phone size={16} className="text-white" />
          </div>
          <span className="text-sm font-bold tracking-tight pr-1 hidden sm:inline">08407 000 048</span>
        </a>

        {/* WhatsApp Floating Button */}
        <a
          href="https://wa.me/918407000048?text=Hi%20WashNLaundry%2C%20I%20would%20like%20to%20inquire%20about%20a%20doorstep%20pickup"
          target="_blank"
          rel="noopener noreferrer"
          onClick={() => trackAction("whatsapp_click", { source: "floating_fab" })}
          aria-label="Chat with WashNLaundry on WhatsApp"
          className="pointer-events-auto flex items-center gap-2.5 px-4 h-13 rounded-full bg-[#25D366] hover:bg-[#20ba59] text-white shadow-xl hover:shadow-2xl transition-all duration-200 hover:-translate-y-0.5 group"
          title="Chat on WhatsApp"
        >
          <div className="w-8.5 h-8.5 rounded-full bg-white/20 flex items-center justify-center group-hover:scale-110 transition-transform">
            <svg className="w-4.5 h-4.5 fill-white" viewBox="0 0 24 24">
              <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z"/>
            </svg>
          </div>
          <span className="text-sm font-bold tracking-tight pr-1 hidden sm:inline">WhatsApp</span>
        </a>
      </aside>
    </div>
  );
}
