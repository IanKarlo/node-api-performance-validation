const path = require('path');

/**
 * Detects the correct library extension based on the operating system.
 * Zig builds usually produce .node files for Node.js, but might use .dll/.dylib/.so
 * depending on the target configuration in build.zig.
 */
const libName = process.platform === 'win32' ? 'addon.dll' : 
                process.platform === 'darwin' ? 'addon.dylib' : 'addon.node';

const addonPath = path.join(__dirname, 'zig-out', 'lib', libName);

let addon;
try {
    addon = require(addonPath);
} catch (err) {
    try {
        // Fallback to a generic .node if the platform-specific extension failed
        addon = require(path.join(__dirname, 'zig-out', 'lib', 'addon.node'));
    } catch (e) {
        throw new Error(`Could not load Zig native module. Ensure it is built (zig build). Path: ${addonPath}. Error: ${err.message}`);
    }
}

module.exports = addon;
