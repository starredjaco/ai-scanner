import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "content"]

  filter(event) {
    const type = event.currentTarget.dataset.filterType
    const lines = this.contentTarget.querySelectorAll('.log-line')

    lines.forEach(line => {
      line.style.display = 'flex'

      if (type === 'pass' && !line.classList.contains('pass-line')) {
        line.style.display = 'none'
      }

      if (type === 'fail' && !line.classList.contains('fail-line')) {
        line.style.display = 'none'
      }
    })
  }

  resetFilter() {
    const lines = this.contentTarget.querySelectorAll('.log-line')
    lines.forEach(line => {
      line.style.display = 'flex'
      line.style.backgroundColor = ''
    })
  }

  search() {
    const query = this.searchTarget.value.toLowerCase()
    const lines = this.contentTarget.querySelectorAll('.log-line')

    if (query === '') {
      this.resetFilter()
      return
    }

    lines.forEach(line => {
      const text = line.textContent.toLowerCase()
      if (text.includes(query)) {
        line.style.display = 'flex'
        line.style.backgroundColor = 'rgba(255, 255, 0, 0.1)'
      } else {
        line.style.display = 'none'
      }
    })
  }
}
