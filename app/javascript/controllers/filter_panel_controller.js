import { Controller } from "@hotwired/stimulus";

/**
 * Filter Panel Controller
 *
 * Controls an expandable filter panel with:
 * - Auto-expand when filters are active (URL has q[] params)
 * - Smooth slide animation for expand/collapse
 * - Badge showing active filter count
 * - Mobile slide-in drawer behavior
 * - Clear filters functionality
 */
export default class extends Controller {
  static targets = ["panel", "toggleIcon", "badge", "backdrop"];
  static values = {
    expanded: { type: Boolean, default: false },
    mobileBreakpoint: { type: Number, default: 768 },
  };

  connect() {
    // Count active filters from URL
    const activeCount = this.countActiveFilters();

    // Update badge
    this.updateBadge(activeCount);

    // Auto-expand if filters are active
    if (activeCount > 0) {
      this.expandedValue = true;
    }

    // Handle resize for mobile/desktop transitions
    this.handleResize = this.handleResize.bind(this);
    window.addEventListener("resize", this.handleResize);
  }

  disconnect() {
    window.removeEventListener("resize", this.handleResize);
  }

  toggle() {
    this.expandedValue = !this.expandedValue;
  }

  close() {
    this.expandedValue = false;
  }

  expandedValueChanged() {
    if (this.hasPanelTarget) {
      const isMobile = window.innerWidth < this.mobileBreakpointValue;

      if (isMobile) {
        // Mobile: slide-in drawer from right
        this.panelTarget.classList.toggle("translate-x-full", !this.expandedValue);
        this.panelTarget.classList.toggle("translate-x-0", this.expandedValue);

        // Show/hide backdrop
        if (this.hasBackdropTarget) {
          this.backdropTarget.classList.toggle("hidden", !this.expandedValue);
          this.backdropTarget.classList.toggle("opacity-0", !this.expandedValue);
          this.backdropTarget.classList.toggle("opacity-100", this.expandedValue);
        }

        // Prevent body scroll when drawer is open
        document.body.classList.toggle("overflow-hidden", this.expandedValue);
      } else {
        // Desktop: expand/collapse panel
        if (this.expandedValue) {
          this.panelTarget.classList.remove("hidden");
          // Trigger reflow for animation
          this.panelTarget.offsetHeight;
          this.panelTarget.classList.remove("max-h-0", "opacity-0");
          this.panelTarget.classList.add("max-h-96", "opacity-100");
        } else {
          this.panelTarget.classList.add("max-h-0", "opacity-0");
          this.panelTarget.classList.remove("max-h-96", "opacity-100");
          // Hide after animation completes
          setTimeout(() => {
            if (!this.expandedValue) {
              this.panelTarget.classList.add("hidden");
            }
          }, 300);
        }
      }
    }

    // Rotate toggle icon
    if (this.hasToggleIconTarget) {
      this.toggleIconTarget.classList.toggle("rotate-180", this.expandedValue);
    }
  }

  handleResize() {
    const isMobile = window.innerWidth < this.mobileBreakpointValue;

    if (this.hasPanelTarget) {
      // Reset classes when crossing breakpoint
      if (isMobile) {
        this.panelTarget.classList.remove("max-h-0", "max-h-96", "opacity-0", "opacity-100", "hidden");
        this.panelTarget.classList.add("translate-x-full");
        if (this.expandedValue) {
          this.panelTarget.classList.remove("translate-x-full");
          this.panelTarget.classList.add("translate-x-0");
        }
      } else {
        this.panelTarget.classList.remove("translate-x-full", "translate-x-0");
        document.body.classList.remove("overflow-hidden");
        if (this.hasBackdropTarget) {
          this.backdropTarget.classList.add("hidden");
        }
        if (this.expandedValue) {
          this.panelTarget.classList.remove("hidden", "max-h-0", "opacity-0");
          this.panelTarget.classList.add("max-h-96", "opacity-100");
        } else {
          this.panelTarget.classList.add("hidden", "max-h-0", "opacity-0");
        }
      }
    }
  }

  countActiveFilters() {
    const params = new URLSearchParams(window.location.search);
    let count = 0;

    for (const [key, value] of params) {
      // Count q[*] params that have non-empty values, excluding sort param q[s]
      if (key.startsWith("q[") && key !== "q[s]" && value && value.trim() !== "") {
        count++;
      }
    }

    return count;
  }

  updateBadge(count) {
    if (this.hasBadgeTarget) {
      this.badgeTarget.textContent = count;
      this.badgeTarget.classList.toggle("hidden", count === 0);
    }
  }

  clearFilters(event) {
    event.preventDefault();

    // Get current URL and remove q[] params, keep scope/order
    const url = new URL(window.location.href);
    const keysToRemove = [];

    for (const key of url.searchParams.keys()) {
      if (key.startsWith("q[")) {
        keysToRemove.push(key);
      }
    }

    keysToRemove.forEach((key) => url.searchParams.delete(key));

    // Also reset to page 1
    url.searchParams.delete("page");

    window.location.href = url.toString();
  }
}
