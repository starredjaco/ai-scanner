import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "count"]
  static values = { max: Number }

  connect() {
    this.update()
  }

  update() {
    const currentLength = this.inputTarget.value.length
    this.countTarget.textContent = currentLength
    const parentSpan = this.countTarget.parentElement

    if (currentLength > this.maxValue) {
      this.countTarget.className = 'font-bold text-red-600 dark:text-red-400'
      if (parentSpan) {
        parentSpan.className = 'mt-1 text-right text-xs text-red-600 dark:text-red-400 font-semibold'
      }
    } else if (currentLength > this.maxValue * 0.9) {
      this.countTarget.className = 'text-red-500 dark:text-red-400'
      if (parentSpan) {
        parentSpan.className = 'mt-1 text-right text-xs text-red-500 dark:text-red-400'
      }
    } else if (currentLength > this.maxValue * 0.75) {
      this.countTarget.className = 'text-yellow-600 dark:text-yellow-400'
      if (parentSpan) {
        parentSpan.className = 'mt-1 text-right text-xs text-yellow-600 dark:text-yellow-400'
      }
    } else {
      this.countTarget.className = ''
      if (parentSpan) {
        parentSpan.className = 'mt-1 text-right text-xs text-gray-500 dark:text-gray-400'
      }
    }
  }
}
