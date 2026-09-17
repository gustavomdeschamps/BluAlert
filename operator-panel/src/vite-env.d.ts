/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string;
  readonly VITE_SUPABASE_ANON_KEY: string;
  /** Provedor de tiles alternativo. Vazio usa o OpenStreetMap padrão. */
  readonly VITE_MAP_TILE_URL?: string;
  /** Atribuição do provedor configurado. Nunca pode ficar oculta na tela. */
  readonly VITE_MAP_ATTRIBUTION?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
