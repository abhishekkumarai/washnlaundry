# WashNLaundry â€” AI Developer Handbook (`llm.md`)

> [!IMPORTANT]
> **INSTRUCTION FOR THE LLM AGENT:**
> You are starting a session on the **WashNLaundry** repository. 
> To prevent unnecessary file reading, token waste, and context clutter, **read this file first**. It contains the exact business logic, configurations, and tech stack details of this project. Do not modify the existing values unless explicitly requested by the user. Always update this `llm.md` file at the end of your session if you make changes to the routing, dependencies, or key business details.

---

### 1. Project Profile & Links
*   **Business Name**: WashNLaundry (Digital laundry & dry cleaning service)
*   **Locality**: Patna, Bihar, India
*   **Primary Live URL**: [https://washnlaundry.com](https://washnlaundry.com)
*   **GitHub Repository**: [abhishekkumarai/WashNLaundry](https://github.com/abhishekkumarai/WashNLaundry) (GitHub username: `abhishekkumarai`)
*   **Vercel Project Scope**: `3abhishekkumar-3596s-projects/WashNLaundry` (Vercel account: `3abhishekkumar@gmail.com`)
*   **Vercel Deployment Region**: **Mumbai, India (`bom1`)** for both Edge Routing and Serverless/API Function Execution.
    > [!WARNING]
    > **Do not change the Vercel deployment region.** Keeping the serverless execution and edge routing in Mumbai (`bom1`) is critical to ensure minimum latency for our local Patna, Bihar user base.


---

## 2. Tech Stack & Architecture
*   **Core Framework**: Next.js App Router (version `16.2.6` â€” *Note: check Next.js 16 features in `node_modules/next/dist/docs/` before making major changes*).
*   **Languages**: TypeScript & React (`19.2.4`).
*   **Styling**: Pure CSS Modules & CSS variables (`src/app/globals.css`). **No TailwindCSS** (unless explicitly requested).
*   **Build Target**: Prerendered static pages (`npm run build` generates static html, serverless dynamic API endpoints).

---

## 3. Active Business Rules & Data Constants

### Service Location & Pincodes
*   **Active Pincodes**: `800025`, `801503`, `800001`, `800020`, `800013` (Patna, Bihar).
*   **Physical Address**: Bailey Road, near Shyama Apartment, Lohiya Path, Chotti Rukanpura, Patna, Bihar 800025.
*   **Support & Order Phone**: `08407000048`.

### Operations & Order Logistics
*   **Standard Delivery**: 24-hour turnaround.
*   **Express Delivery**: "Sprint Express" (4-hour turnaround, available at checkout).
*   **Delivery Rider Profile**: "WashNLaundry Personnel" (avatar initials: "FW", phone: `08407000048`).
*   **Order ID Prefix**: `FW-` followed by 6 digits (e.g., `FW-123456`).

---

## 4. Key Directory & Code Map

*   `src/app/`: Next.js App Router root.
    *   `layout.tsx`: Root layout, sets global metadata, embeds Vercel Analytics & Speed Insights, loads Google Analytics (GA4) dynamically, and loads the global cart provider.
    *   `page.tsx`: Home page with pincode checker, AEO/GEO FAQ Accordion UI, and embedded JSON-LD schemas.
    *   `sitemap.ts`: Generates `sitemap.xml`.
    *   `robots.ts`: Generates `robots.txt` (allows LLM search bots like `GPTBot`, `PerplexityBot`, `Google-Extended`, and `ClaudeBot` to crawl pages).
    *   `api/seo-cron/route.ts`: Secure serverless cron route to ping search engines.
    *   `services/`: Services catalog page.
    *   `book/`: Multi-step booking wizard (Cart $\rightarrow$ Schedule $\rightarrow$ Address $\rightarrow$ Confirm).
    *   `track/`: simulated order tracking dashboard with progress stepper.
    *   `about/`: Page about eco-friendly washing and water-saving statistics.
    *   `club-ultimate/`: subscription membership plans.
*   `src/context/CartContext.tsx`: Manages the global basket, services selected, and schedules. Saves cart items to browser `localStorage` using keys prefixed with `fw_` (e.g., `fw_cart`, `fw_address`).
*   `vercel.json`: Sets up Vercel daily Cron Job targeting `/api/seo-cron`.
*   `.env.example`: Documents environment variables (e.g., `NEXT_PUBLIC_GA_ID` for Google Analytics).

---

## 5. SEO & GEO (AI Search Engine Optimization) Specifics
*   **LocalBusiness Schema**: Structured JSON-LD defining WashNLaundry as a Patna-based `LaundryBusiness` with coordinates and hours is embedded in the homepage.
*   **FAQPage Schema**: Embedded JSON-LD mapping homepage FAQs to help AEO (Answer Engine Optimization) bots retrieve questions.
*   **Cron Job indexing**: Bing's sitemap ping URL is triggered daily at midnight. Requires setting the `CRON_SECRET` environment variable in Vercel to secure the endpoint.

