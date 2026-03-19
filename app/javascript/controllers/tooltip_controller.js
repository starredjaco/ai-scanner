import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["popup"]

  connect() {
    this.boundClose = this.close.bind(this)
  }

  disconnect() {
    document.removeEventListener('click', this.boundClose)
  }

  toggle(event) {
    event.stopPropagation()

    // Close all other open tooltips first
    this.closeAllOtherTooltips()

    if (this.popupTarget.classList.contains('hidden')) {
      this.open()
    } else {
      this.close()
    }
  }

  show() {
    // Close all other open tooltips first
    this.closeAllOtherTooltips()
    this.open()
  }

  hide() {
    this.close()
  }

  closeAllOtherTooltips() {
    // Find all tooltip controllers and close their popups
    document.querySelectorAll('[data-controller*="tooltip"]').forEach(element => {
      if (element !== this.element) {
        const popup = element.querySelector('[data-tooltip-target="popup"]')
        if (popup && !popup.classList.contains('hidden')) {
          popup.classList.add('hidden')
        }
      }
    })
  }

  open() {
    // Position the tooltip intelligently
    const rect = this.element.getBoundingClientRect()
    const viewportWidth = window.innerWidth
    const tooltipWidth = 256 // w-64 = 16rem = 256px

    // Check if tooltip would go off-screen on the right
    if (rect.right + tooltipWidth > viewportWidth - 20) {
      // Position to the left of the icon
      this.popupTarget.classList.remove('left-0')
      this.popupTarget.classList.add('right-0')
    } else {
      // Position to the right of the icon (default)
      this.popupTarget.classList.remove('right-0')
      this.popupTarget.classList.add('left-0')
    }

    this.popupTarget.classList.remove('hidden')
    // Close when clicking outside
    setTimeout(() => {
      document.addEventListener('click', this.boundClose)
    }, 0)
  }

  close() {
    this.popupTarget.classList.add('hidden')
    document.removeEventListener('click', this.boundClose)
  }

  stopPropagation(event) {
    event.stopPropagation()
  }
}
