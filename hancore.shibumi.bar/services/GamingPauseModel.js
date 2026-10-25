.pragma library

// Optional, read-only integration with arch-setups' versioned gaming journal.
// This hint never owns media playback or desktop/session lifecycle.
function decorationsPaused(raw, signature) {
  if (typeof raw !== "string" || raw.length === 0 || raw.length > 65536
      || typeof signature !== "string" || signature.length === 0) return false
  try {
    const state = JSON.parse(raw)
    return state !== null && typeof state === "object" && !Array.isArray(state)
      && state.schemaVersion === 1 && state.signature === signature
      && state.pauseDecorations === true
  } catch (error) {
    return false
  }
}
