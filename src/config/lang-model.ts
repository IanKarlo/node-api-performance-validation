/**
 * Language Model Configuration
 * Controls whether to use Rust, Zig, or TypeScript implementations
 */

export type LangModel = 'TS' | 'RS' | 'ZG';

export interface LangModelConfig {
  model: LangModel;
  useRust: boolean;
  useZig: boolean;
  rustAvailable: boolean;
  zigAvailable: boolean;
}

/**
 * Gets the current language model configuration
 */
export function getLangModelConfig(): LangModelConfig {
  const model = (process.env.LANG_MODEL as LangModel) || 'TS';

  if (model !== 'TS' && model !== 'RS' && model !== 'ZG') {
    console.warn(`Invalid LANG_MODEL value: ${model}. Defaulting to 'TS'`);
    return {
      model: 'TS',
      useRust: false,
      useZig: false,
      rustAvailable: false,
      zigAvailable: false,
    };
  }

  let rustAvailable = false;
  if (model === 'RS') {
    try {
      require('@native-rust');
      rustAvailable = true;
    } catch (error) {
      console.warn('Rust native module not available, falling back to TypeScript implementation');
      rustAvailable = false;
    }
  }

  let zigAvailable = false;
  if (model === 'ZG') {
    try {
      require('@native-zig');
      zigAvailable = true;
    } catch (error) {
      console.warn('Zig native module not available, falling back to TypeScript implementation');
      zigAvailable = false;
    }
  }

  return {
    model,
    useRust: model === 'RS' && rustAvailable,
    useZig: model === 'ZG' && zigAvailable,
    rustAvailable,
    zigAvailable,
  };
}

/**
 * Logs the current language model being used
 */
export function logLangModelUsage(endpoint: string): void {
  const config = getLangModelConfig();
  let implementation = 'TypeScript';
  if (config.useRust) {
    implementation = 'Rust';
  } else if (config.useZig) {
    implementation = 'Zig';
  }
  console.log(`[${endpoint}] Using ${implementation} implementation (LANG_MODEL=${config.model})`);
}