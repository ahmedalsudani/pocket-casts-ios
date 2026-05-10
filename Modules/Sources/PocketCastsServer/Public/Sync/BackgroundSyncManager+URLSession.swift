import Foundation

// Background-URLSession-driven sync used to live here. With the Pocket
// Casts sync subsystem removed, BackgroundSyncManager is a no-op shim
// (see BackgroundSyncManager.swift) and the URLSession delegate methods
// are no longer needed.
