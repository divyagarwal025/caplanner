// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

import Chartkick from "chartkick"
import { Chart, registerables } from "chart.js"
Chart.register(...registerables)
// This chartkick build detects the charting library via `window.Chart`
// (loadAdapters checks `"Chart" in window`), so expose it globally — not just
// via Chartkick.use — or every chart stays stuck on "Loading…".
window.Chart = Chart
Chartkick.use(Chart)
window.Chartkick = Chartkick
// application.js is a deferred ES module, so the per-chart inline scripts in the
// page run BEFORE it. They wait on a "chartkick:load" event when Chartkick isn't
// yet defined — dispatch it here or those charts stay stuck on "Loading…".
window.dispatchEvent(new Event("chartkick:load"))

// Theme-aware chart defaults (grid + text colours follow light/dark).
function applyChartTheme() {
  const dark = document.documentElement.getAttribute("data-theme") === "dark"
  Chart.defaults.color = dark ? "#8a97ac" : "#64748b"
  Chart.defaults.borderColor = dark ? "#27314a" : "#e9edf2"
  Chart.defaults.font.family = "Inter, system-ui, sans-serif"
}
applyChartTheme()

// On a Turbo navigation the body is swapped in but the inline chart scripts
// that already ran on the previous page do NOT re-run, so a chart rendered
// into the new page's container never gets created and stays on "Loading…".
// Re-draw every Chartkick chart after each Turbo page load.
function redrawCharts() {
  applyChartTheme()
  if (!window.Chartkick || !Chartkick.charts) return
  Object.values(Chartkick.charts).forEach(function(c) {
    try { c.redraw() } catch (e) {}
  })
}
document.addEventListener("turbo:load", redrawCharts)
document.addEventListener("turbo:render", redrawCharts)
