.pragma library

// The settings a layout entry hands its widget, as a deep copy. Entries reach
// WidgetSlot through a Repeater's modelData, which turns nested arrays into list
// wrappers that fail Array.isArray. A widget treating that as "not configured"
// can overwrite its own saved settings, as Elsewhen's first-run seeding did.
function fromEntry(entry) {
  var settings = JSON.parse(JSON.stringify(entry))
  delete settings.id
  return settings
}
