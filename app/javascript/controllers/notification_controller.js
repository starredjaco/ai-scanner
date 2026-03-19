import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    timeout: { type: Number, default: 5300 } // 5s delay + 0.3s animation
  }

  connect() {
    // Fallback timeout in case CSS animation doesn't fire
    this.fallbackTimer = setTimeout(() => {
      this.remove()
    }, this.timeoutValue)
  }

  disconnect() {
    if (this.fallbackTimer) {
      clearTimeout(this.fallbackTimer)
    }
  }

  remove() {
    if (this.fallbackTimer) {
      clearTimeout(this.fallbackTimer)
    }
    this.element.remove()
  }

  close() {
    this.remove()
  }
}
