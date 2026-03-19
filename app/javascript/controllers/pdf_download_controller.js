import { Controller } from "@hotwired/stimulus"
import { showToast } from "utils"

export default class extends Controller {
  static targets = ['button', 'text', 'icon']
  static values = {
    reportId: String,
    url: String
  }

  connect() {
    // Listen for Turbo stream updates to pdf-status div
    // We need to observe the parent because Turbo's replace action removes and re-adds the element
    const statusDiv = document.getElementById(`pdf-status-${this.reportIdValue}`)
    if (statusDiv && statusDiv.parentElement) {
      this.observer = new MutationObserver((mutations) => {
        // Check if the status div was replaced
        const updatedStatusDiv = document.getElementById(`pdf-status-${this.reportIdValue}`)
        if (updatedStatusDiv) {
          this.checkPdfStatus(updatedStatusDiv)
        }
      })
      // Observe the parent element for childList changes
      this.observer.observe(statusDiv.parentElement, {
        childList: true,
        subtree: true
      })
    }
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  async downloadPdf(event) {
    event.preventDefault()
    
    // Get URL from button's data attribute, controller value, or href
    const button = event.currentTarget
    const url = button.dataset.pdfDownloadUrlValue || this.urlValue || button.href
    
    if (!url) {
      console.error('No PDF URL found')
      this.showError('PDF URL not configured')
      return
    }
    
    // Show loading state
    this.setLoading(true)
    
    try {
      const response = await fetch(url, {
        method: 'HEAD',
        headers: {
          'Accept': 'application/pdf,application/json'
        }
      })
      
      if (response.status === 200 && response.headers.get('Content-Type')?.includes('application/pdf')) {
        // PDF is ready, trigger download via direct navigation
        window.location.href = url
        this.setLoading(false)
      } else if (response.status === 202) {
        // PDF generation in progress - need to GET to read JSON body
        const getResponse = await fetch(url, {
          headers: {
            'Accept': 'application/json'
          }
        })
        const data = await getResponse.json()
        this.showGenerating(data.message || 'Generating PDF...')
      } else {
        // Error - need to GET to read error message
        const getResponse = await fetch(url, {
          headers: {
            'Accept': 'application/json'
          }
        })
        const data = await getResponse.json()
        this.showError(data.message || 'Failed to generate PDF')
      }
    } catch (error) {
      console.error('PDF download error:', error)
      this.showError('Failed to download PDF')
    }
  }

  checkPdfStatus(statusDiv) {
    const status = statusDiv.dataset.pdfStatus
    const downloadUrl = statusDiv.dataset.downloadUrl
    
    if (status === 'ready' && downloadUrl) {
      // PDF is ready, trigger download
      window.location.href = downloadUrl
      this.setLoading(false)
    }
  }

  setLoading(loading) {
    if (!this.hasButtonTarget) return
    
    if (loading) {
      this.buttonTarget.classList.add('opacity-50', 'pointer-events-none')
      if (this.hasTextTarget) {
        this.originalText = this.textTarget.textContent
        this.textTarget.textContent = 'Preparing...'
      } else {
        // For links without text target, store original and update label
        this.originalText = this.buttonTarget.textContent.trim()
        // Find text nodes (not icon spans) and update them
        Array.from(this.buttonTarget.childNodes).forEach(node => {
          if (node.nodeType === Node.TEXT_NODE && node.textContent.trim()) {
            node.textContent = ' Preparing...'
          }
        })
      }
    } else {
      this.buttonTarget.classList.remove('opacity-50', 'pointer-events-none')
      if (this.hasTextTarget) {
        this.textTarget.textContent = this.originalText || 'Download PDF'
      } else {
        // Restore original text for links
        Array.from(this.buttonTarget.childNodes).forEach(node => {
          if (node.nodeType === Node.TEXT_NODE && node.textContent.trim()) {
            // Extract just the label part from originalText (remove icon text)
            const labelOnly = this.originalText ? this.originalText.replace(/^\s+/, ' ') : ' Download PDF'
            node.textContent = labelOnly
          }
        })
      }
    }
  }

  showGenerating(message) {
    if (this.hasTextTarget) {
      this.textTarget.textContent = message
    }
    // Keep loading state
  }

  showError(message) {
    if (this.hasTextTarget) {
      this.textTarget.textContent = 'Download PDF'
    }
    this.setLoading(false)
    console.error('PDF download error:', message)
    showToast(message, 'error')
  }

}
