'use client';

import { createContext, useCallback, useContext, useEffect, useState } from 'react';

const CLIENT_ID = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID ?? '';
const KEY = 'wnl_google_token';

type Profile = { email: string; name: string };
type Auth = { token: string | null; profile: Profile | null; ready: boolean; signOut: () => void };

declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (cfg: { client_id: string; callback: (r: { credential: string }) => void }) => void;
          renderButton: (el: HTMLElement, opts: Record<string, unknown>) => void;
        };
      };
    };
  }
}

const AuthCtx = createContext<Auth>({ token: null, profile: null, ready: false, signOut: () => {} });
export const useAuth = () => useContext(AuthCtx);

function decode(token: string): (Profile & { exp: number }) | null {
  try {
    const bytes = Uint8Array.from(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));
    const p = JSON.parse(new TextDecoder().decode(bytes));
    return { email: p.email, name: p.name ?? p.email, exp: p.exp };
  } catch {
    return null;
  }
}

function stored(): string | null {
  try {
    const t = sessionStorage.getItem(KEY);
    const p = t && decode(t);
    return t && p && p.exp * 1000 > Date.now() ? t : null;
  } catch {
    return null;
  }
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setToken] = useState<string | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    // sessionStorage only exists after mount, so hydrating state here is intentional.
    // washnlaundry.com/login hands the Google ID token over in the URL fragment
    // (#t=...), which never reaches a server or log. Take it once, then clear it.
    const handed = new URLSearchParams(window.location.hash.slice(1)).get('t');
    if (handed) {
      const p = decode(handed);
      if (p && p.exp * 1000 > Date.now()) {
        try { sessionStorage.setItem(KEY, handed); } catch {}
      }
      history.replaceState(null, '', window.location.pathname + window.location.search);
    }
    setToken(stored());
    setReady(true);
    const onSignIn = (e: Event) => setToken((e as CustomEvent<string>).detail);
    window.addEventListener('wnl-signin', onSignIn);
    return () => window.removeEventListener('wnl-signin', onSignIn);
  }, []);

  const signOut = useCallback(() => {
    try { sessionStorage.removeItem(KEY); } catch {}
    setToken(null);
  }, []);

  const profile = token ? decode(token) : null;
  return <AuthCtx.Provider value={{ token, profile, ready, signOut }}>{children}</AuthCtx.Provider>;
}

/** Renders Google's own button into `el` and stores the ID token it returns. */
export function mountGoogleButton(el: HTMLElement) {
  const init = () => {
    window.google!.accounts.id.initialize({
      client_id: CLIENT_ID,
      callback: ({ credential }) => {
        try { sessionStorage.setItem(KEY, credential); } catch {}
        window.dispatchEvent(new CustomEvent('wnl-signin', { detail: credential }));
      },
    });
    window.google!.accounts.id.renderButton(el, { theme: 'outline', size: 'large', text: 'continue_with', width: 300 });
  };
  if (window.google) return init();
  const s = document.createElement('script');
  s.src = 'https://accounts.google.com/gsi/client';
  s.async = true;
  s.onload = init;
  document.head.appendChild(s);
}

export const googleConfigured = CLIENT_ID !== '';
