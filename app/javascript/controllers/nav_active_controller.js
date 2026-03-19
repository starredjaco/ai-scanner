import { Controller } from "@hotwired/stimulus"

/**
 * Navigation Active State Controller
 *
 * Updates menu active state when Turbo Frame navigation occurs.
 * Since the menu is outside the turbo-frame, it doesn't re-render,
 * so we need to update the active state client-side.
 *
 * Usage:
 *   <div data-controller="nav-active">
 *     <a href="/targets" data-nav-active-target="item">Targets</a>
 *     <a href="/reports" data-nav-active-target="item">Reports</a>
 *   </div>
 */
export default class extends Controller {
  static targets = ["item"]

  // CSS classes for active/inactive states
  static values = {
    activeClasses: { type: String, default: "bg-zinc-900/40 text-orange-400 nav-active-indicator" },
    inactiveClasses: { type: String, default: "text-white hover:text-orange-400 hover:bg-zinc-900" }
  }

  connect() {
    this.updateActiveState()

    // Bind methods for event listeners
    this.boundHandleFrameLoad = this.handleFrameLoad.bind(this)
    this.boundUpdateActiveState = this.updateActiveState.bind(this)

    // Listen for Turbo Frame loads
    document.addEventListener("turbo:frame-load", this.boundHandleFrameLoad)

    // Handle browser back/forward
    window.addEventListener("popstate", this.boundUpdateActiveState)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.boundHandleFrameLoad)
    window.removeEventListener("popstate", this.boundUpdateActiveState)
  }

  handleFrameLoad(event) {
    if (event.target.id === "main-content") {
      this.updateActiveState()
      this.updatePageTitle(event.target)
    }
  }

  updateActiveState() {
    const currentPath = window.location.pathname

    this.itemTargets.forEach(item => {
      const itemPath = item.getAttribute("href")
      const isActive = this.pathMatches(currentPath, itemPath)
      const parentLi = item.closest("li")

      // Get the icon element if present
      const icon = item.querySelector("img")

      // Remove all active/inactive classes first
      this.activeClassesValue.split(" ").filter(Boolean).forEach(cls => item.classList.remove(cls))
      this.inactiveClassesValue.split(" ").filter(Boolean).forEach(cls => item.classList.remove(cls))

      if (isActive) {
        parentLi?.setAttribute("data-active", "")
        this.activeClassesValue.split(" ").filter(Boolean).forEach(cls => item.classList.add(cls))

        // Update icon for active state - change to orange
        if (icon) {
          icon.classList.add("nav-icon-active")
        }

        // Handle parent submenu expansion for nested items
        const parentSubmenu = parentLi?.closest("ul[role='list']")?.closest("li.group")
        if (parentSubmenu) {
          parentSubmenu.setAttribute("data-open", "")
        }
      } else {
        parentLi?.removeAttribute("data-active")
        this.inactiveClassesValue.split(" ").filter(Boolean).forEach(cls => item.classList.add(cls))

        // Update icon for inactive state - white
        if (icon) {
          icon.classList.remove("nav-icon-active")
        }
      }
    })
  }

  pathMatches(currentPath, itemPath) {
    if (!itemPath) return false

    // Normalize paths - remove trailing slashes and query strings
    const normalizedCurrent = currentPath.replace(/\/$/, "") || "/"
    const normalizedItem = itemPath.split("?")[0].replace(/\/$/, "") || "/"

    // Exact match for root/dashboard
    if (normalizedItem === "/" || normalizedItem === "") {
      return normalizedCurrent === "/" || normalizedCurrent === ""
    }

    // Check if current path exactly matches or starts with item path (for nested routes like /targets/123)
    return normalizedCurrent === normalizedItem ||
           normalizedCurrent.startsWith(normalizedItem + "/")
  }

  updatePageTitle(frameElement) {
    // Look for a page title data attribute in the frame content
    const titleElement = frameElement.querySelector("[data-page-title]")
    if (titleElement) {
      const pageTitle = titleElement.dataset.pageTitle
      document.title = `${pageTitle} - Scanner`
    }
  }
}
