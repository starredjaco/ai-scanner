import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]

  toggle() {
    const field = this.fieldTarget
    const eyeIcon = this.element.querySelector('[data-password-visibility-target="eyeIcon"]')
    const eyeSlashIcon = this.element.querySelector('[data-password-visibility-target="eyeSlashIcon"]')

    if (field.type === 'password') {
      field.type = 'text'
      if (eyeIcon) eyeIcon.classList.add('hidden')
      if (eyeSlashIcon) eyeSlashIcon.classList.remove('hidden')
    } else {
      field.type = 'password'
      if (eyeIcon) eyeIcon.classList.remove('hidden')
      if (eyeSlashIcon) eyeSlashIcon.classList.add('hidden')
    }
  }
}
