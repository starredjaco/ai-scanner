import { Controller } from "@hotwired/stimulus"

// Masks sensitive values with toggle to show/hide
// Usage:
//   <div data-controller="value-masking">
//     <code data-value-masking-target="mask">••••••••</code>
//     <code data-value-masking-target="value" class="hidden">secret</code>
//     <button data-action="value-masking#toggle" data-value-masking-target="icon">
//       <svg>...</svg>
//     </button>
//   </div>
export default class extends Controller {
  static targets = ["value", "mask", "icon"]
  static values = { masked: { type: Boolean, default: true } }

  // SVG icons for show/hide states
  static eyeIcon = '<span class="icon icon-sm icon-eye"></span>'
  static eyeOffIcon = '<span class="icon icon-sm icon-eye-slash"></span>'

  toggle() {
    this.maskedValue = !this.maskedValue
  }

  maskedValueChanged() {
    // Use 'invisible' instead of 'hidden' to preserve layout and prevent table jumping
    this.valueTarget.classList.toggle("invisible", this.maskedValue)
    this.maskTarget.classList.toggle("invisible", !this.maskedValue)

    // Update icon if present
    if (this.hasIconTarget) {
      this.iconTarget.innerHTML = this.maskedValue ? this.constructor.eyeIcon : this.constructor.eyeOffIcon
    }
  }
}
