import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "indicator", "status", "validation", "counter"]

  connect() {
    this.updateCounter()
    if (this.textareaTarget.value.trim()) {
      this.validateJson()
    }
  }

  validateJson() {
    const value = this.textareaTarget.value.trim()

    if (!value) {
      this.clearValidation()
      return
    }

    try {
      JSON.parse(value)
      this.showValid()
    } catch (error) {
      this.showInvalid(error.message)
    }
  }

  showValid() {
    this.indicatorTarget.classList.remove('hidden')
    this.statusTarget.className = 'inline-flex items-center px-2 py-1 text-xs font-medium rounded-full bg-green-100 text-green-800 dark:bg-green-800 dark:text-green-200'
    this.statusTarget.innerHTML = `
      <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
      </svg>
      Valid JSON
    `
    this.validationTarget.classList.add('hidden')
    this.validationTarget.textContent = ''
  }

  showInvalid(message) {
    this.indicatorTarget.classList.remove('hidden')
    this.statusTarget.className = 'inline-flex items-center px-2 py-1 text-xs font-medium rounded-full bg-red-100 text-red-800 dark:bg-red-800 dark:text-red-200'
    this.statusTarget.innerHTML = `
      <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
      </svg>
      Invalid JSON
    `
    this.validationTarget.classList.remove('hidden')
    // Basic sanitization - remove potential HTML characters
    const simpleMessage = message
      .replace(/JSON\.parse:\s*/i, '')
      .replace(/at position \d+/i, '')
      .replace(/[<>]/g, '')
    this.validationTarget.textContent = `Error: ${simpleMessage}`
  }

  clearValidation() {
    this.indicatorTarget.classList.add('hidden')
    this.validationTarget.classList.add('hidden')
    this.validationTarget.textContent = ''
  }

  updateCounter() {
    const count = this.textareaTarget.value.length
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${count} characters`

      if (count > 10000) {
        this.counterTarget.className = 'ml-auto text-red-500 dark:text-red-400 text-xs'
      } else if (count > 5000) {
        this.counterTarget.className = 'ml-auto text-yellow-600 dark:text-yellow-400 text-xs'
      } else {
        this.counterTarget.className = 'ml-auto text-gray-500 dark:text-gray-400 text-xs'
      }
    }
  }

  onFocus() {
    this.textareaTarget.classList.add('ring-4', 'ring-indigo-300', 'dark:ring-indigo-600')
  }

  disconnect() {
    if (this.hasTextareaTarget) {
      this.textareaTarget.classList.remove('ring-4', 'ring-indigo-300', 'dark:ring-indigo-600')
    }
  }
}
