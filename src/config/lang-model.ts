/**
 * Language Model Configuration
 * Controls whether to use Rust or TypeScript implementations
 */

export type LangModel = 'TS' | 'RS';

export interface LangModelConfig {
  model: LangModel;
  useRust: boolean;
  rustAvailable: boolean;
}

/**
 * Gets the current language model configuration
 */
export function getLangModelConfig(): LangModelConfig {
  const model = (process.env.LANG_MODEL as LangModel) || 'TS';

  if (model !== 'TS' && model !== 'RS') {
    console.warn(`Invalid LANG_MODEL value: ${model}. Defaulting to 'TS'`);
    return { model: 'TS', useRust: false, rustAvailable: false };
  }

  let rustAvailable = false;
  if (model === 'RS') {
    try {
      // Test if Rust module can be loaded
      require('@native-rust');
      rustAvailable = true;
    } catch (error) {
      console.warn('Rust native module not available, falling back to TypeScript implementation');
      rustAvailable = false;
    }
  }

  return {
    model,
    useRust: model === 'RS' && rustAvailable,
    rustAvailable,
  };
}

/**
 * Logs the current language model being used
 */
export function logLangModelUsage(endpoint: string): void {
  const config = getLangModelConfig();
  const implementation = config.useRust ? 'Rust' : 'TypeScript';
  console.log(`[${endpoint}] Using ${implementation} implementation (LANG_MODEL=${config.model})`);
}