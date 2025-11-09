export type AppConfig = {
  SYNCFUSION_API_BASE?: string;
  SYNCFUSION_LICENSE_KEY?: string;
};

declare global {
  interface Window {
    __APP_CONFIG__?: AppConfig;
  }
}

export async function loadConfig(): Promise<void> {
  try {
    const resp = await fetch('/app-config.json', { cache: 'no-store' });
    if (resp.ok) {
      const json = (await resp.json()) as AppConfig;
      window.__APP_CONFIG__ = json;
    } else {
      // Leave config undefined; code will fall back to build-time env/defaults
    }
  } catch {
    // Ignore fetch errors in POC; fall back to defaults
  }
}

export function getConfig(): AppConfig {
  return window.__APP_CONFIG__ ?? {};
}

