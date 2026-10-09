# Multi-Tenant Architecture & Data Isolation (Multi-Shop Support)

> **Jira Epic**: [KAN-132: [ARCH-MT] Multi-Tenant Architecture & Data Isolation](https://emailabhishek2.atlassian.net/browse/KAN-132)  
> **Status**: In Roadmap / Architectural Design  
> **Target Release**: WashNLaundry Multi-Store Core  

---

## 1. Executive Summary

WashNLaundry CRM is expanding from a single-shop operational model to a **multi-tenant, multi-store architecture**. This allows:
- A single centralized deployment serving multiple laundry and dry-cleaning store locations.
- Complete data isolation per shop tenant (customers, orders, inventory pricing, expenses, payroll, staff).
- Independent sequential order prefixing (e.g. `#CP-00001` vs `#GG-00001`).
- Multi-store owners managing multiple locations under a single login.
- Store-specific RBAC roles powered by Django Groups (`Owner`, `Staff`, `Customers`).

---

## 2. Jira Roadmap & Story Breakdown

| Key | Type | Summary | Scope |
| :--- | :---: | :--- | :--- |
| **[KAN-132](https://emailabhishek2.atlassian.net/browse/KAN-132)** | **Epic** | **[ARCH-MT] Multi-Tenant Architecture & Data Isolation (Multi-Shop Support)** | Overarching architectural initiative for complete shop isolation and multi-store operations. |
| **[KAN-133](https://emailabhishek2.atlassian.net/browse/KAN-133)** | Story | **Schema Migration & Tenant Foreign Keys (Shop-Scoped Data Isolation)** | Add `Shop` (Tenant) foreign keys across `Customer`, `Order`, `GarmentItem`, `Expense`, `Credit`, `Staff`, `Attendance`, and `TimeSlot`, backfilling existing data. |
| **[KAN-134](https://emailabhishek2.atlassian.net/browse/KAN-134)** | Story | **Tenant Context Resolution Middleware & Queryset Isolation** | Resolve active tenant from `X-Tenant-ID` header, subdomain, or user profile, automatically scoping all model querysets and writes to the tenant. |
| **[KAN-135](https://emailabhishek2.atlassian.net/browse/KAN-135)** | Story | **Multi-Tenant RBAC & Shop-Scoped Group Memberships** | Introduce `ShopMembership` model allowing users to hold different roles across different shops (e.g., Owner of Shop A, Staff of Shop B). |
| **[KAN-136](https://emailabhishek2.atlassian.net/browse/KAN-136)** | Story | **Tenant Provisioning & Self-Service Shop Onboarding Workflow** | Self-service registration enabling store owners to launch a new shop tenant, order prefix, tax configurations, and staff invitations. |
| **[KAN-137](https://emailabhishek2.atlassian.net/browse/KAN-137)** | Story | **CRM Frontend Multi-Tenant Context & Shop Switcher Integration** | Update Flutter Web CRM (`app.washnlaundry.com`) to inject `X-Tenant-ID` headers and provide a location/shop switcher in the top navigation bar. |

---

## 3. High-Level Architecture Diagram

```mermaid
flowchart TD
    subgraph Clients["Client Layer"]
        C1["Flutter Web CRM (app.washnlaundry.com)"]
        C2["Customer Portal (customer.washnlaundry.com)"]
        C3["Staff & Delivery Mobile Apps"]
    end

    subgraph Edge["Cloudflare Edge & Gateway"]
        CF["Cloudflare WAF & Edge Proxy"]
        TR["Tenant Routing (Subdomain / X-Tenant-ID Header)"]
    end

    subgraph Backend["Django 5 REST Backend"]
        MW["Tenant Context Middleware"]
        AUTH["Auth & RBAC Layer (Bearer Token + Groups)"]
        
        subgraph Scoping["Tenant Query Scoping Layer"]
            DRF["TenantViewSetMixin"]
            MGR["TenantManager (auto-filter shop_id)"]
        end
    end

    subgraph Data["Database Layer (PostgreSQL / SQLite)"]
        subgraph TenantA["Tenant: Shop 101 (Connaught Place)"]
            O1["Orders #CP-0001.."]
            CUST1["Customers & Addresses"]
            CAT1["Pricing & Garment Items"]
            EXP1["Expenses & Payroll"]
            STAFF1["Staff & Attendance"]
        end

        subgraph TenantB["Tenant: Shop 102 (Gurgaon DLF)"]
            O2["Orders #GG-0001.."]
            CUST2["Customers & Addresses"]
            CAT2["Pricing & Garment Items"]
            EXP2["Expenses & Payroll"]
            STAFF2["Staff & Attendance"]
        end
    end

    Clients --> CF
    CF --> TR
    TR --> MW
    MW --> AUTH
    AUTH --> Scoping
    Scoping --> TenantA
    Scoping --> TenantB
```

---

## 4. Multi-Tenant Request & Isolation Lifecycle

```mermaid
sequenceDiagram
    autonumber
    actor User as Store Owner / Staff
    participant App as Flutter CRM Web
    participant MW as TenantMiddleware
    participant DRF as DRF ViewSet & QuerySet
    participant DB as Database (Postgres)

    User->>App: Signs in & selects "Shop Connaught Place"
    App->>App: Stores activeShopId ("shop-101")
    User->>App: Navigates to Orders Screen
    App->>MW: GET /api/orders/ [Header: X-Tenant-ID: shop-101, Bearer Token]
    MW->>MW: Validate user has membership in shop-101
    alt User is unauthorized for this shop
        MW-->>App: 403 Forbidden (Not a member of this shop)
    else Authorized
        MW->>DRF: Attach request.shop = Shop(shop-101)
        DRF->>DB: SELECT * FROM api_order WHERE shop_id = 'shop-101'
        DB-->>DRF: Orders for shop-101 only
        DRF-->>App: 200 OK [JSON orders list]
        App-->>User: Renders Orders for Connaught Place
    end
```

---

## 5. Entity-Relationship & Tenancy Data Model

```mermaid
erDiagram
    Shop ||--o{ ShopMembership : "has members"
    User ||--o{ ShopMembership : "belongs to"
    ShopMembership }o--|| Group : "holds role (Owner, Staff, Customer)"

    Shop ||--o{ Order : "owns"
    Shop ||--o{ Customer : "serves"
    Shop ||--o{ GarmentItem : "prices"
    Shop ||--o{ Staff : "employs"
    Shop ||--o{ Expense : "incurs"
    Shop ||--o{ ServiceArea : "covers"
    Shop ||--o{ TimeSlot : "schedules"

    Customer ||--o{ Order : "places"
    Order ||--o{ OrderItem : "contains"
    Staff ||--o{ Attendance : "records"
    Staff ||--o{ SalaryPayment : "receives"

    Shop {
        uuid id PK
        string name
        string order_prefix
        float tax_rate
        string plan
    }

    ShopMembership {
        uuid id PK
        uuid shop_id FK
        int user_id FK
        int group_id FK
        boolean is_default
    }

    User {
        int id PK
        string email
        string password
    }

    Order {
        uuid id PK
        uuid shop_id FK
        string order_number
        string status
        float total_amount
    }
```

---

## 6. Core Tenancy Engineering Principles

### 1. Tenant Resolution Protocol
Every incoming request is resolved in `TenantMiddleware`:
1. **Header Inspection**: `X-Tenant-ID` header (primary mechanism for SPA & API calls).
2. **Subdomain Resolution**: `shop-subdomain.washnlaundry.com` (for public booking forms & customer portal).
3. **User Default Shop**: If no explicit header is provided, resolves to the user's default `ShopMembership`.
4. **Validation**: Confirms the authenticated user has an active membership for `request.shop`.

### 2. Zero-Leak Query Scoping (`TenantModel`)
All tenancy-scoped models inherit from `TenantModel`:
```python
class TenantModel(models.Model):
    shop = models.ForeignKey('Shop', on_delete=models.CASCADE, related_name='%(class)ss')
    
    objects = TenantManager()
    all_objects = models.Manager()

    class Meta:
        abstract = True
```
- `TenantManager.get_queryset()` automatically filters queries by the current thread's tenant context.
- Prevents cross-shop data leaks even if a view developer forgets to add `.filter(shop=...)`.

### 3. Tenant-Scoped RBAC & Role Hierarchy
Leverages Django Groups with tenant membership scoping:
```
Owner (rank 3)
   └── Staff (rank 2)
         └── Customer (rank 1)
   └── Customer (rank 1)
```
- Users can hold different roles in different shops (e.g., **Owner** of Location A, **Staff** of Location B).
- The `ShopMembership` model maps `(user, shop, group)`.
