import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["targetsSelect", "nameInput", "timeEstimate", "timeEstimateContainer", "unmeasuredWarning"]
  static outlets = ["probe-category"]
  static values = {
    parallelLimit: { type: Number, default: 5 }
  }

  connect() {
    this.initializeChoices()

    // Listen for probe selection changes from probe_category_controller
    // Stimulus dispatch prefixes events with controller identifier
    this._probeChangeHandler = this.handleProbeSelectionChanged.bind(this)
    this.element.addEventListener('probe-category:probeSelectionChanged', this._probeChangeHandler)
  }

  disconnect() {
    if (this._probeChangeHandler) {
      this.element.removeEventListener('probe-category:probeSelectionChanged', this._probeChangeHandler)
    }
  }

  // Stimulus outlet callback — fires when probe-category controller is ready
  probeCategoryOutletConnected() {
    this.updateTimeEstimate()
  }

  // Stimulus action for target select changes
  targetsChanged() {
    this.updateTimeEstimate()
  }

  // Handle event from probe-category controller with totalTokens in detail
  handleProbeSelectionChanged(event) {
    this.updateTimeEstimate(event.detail?.totalTokens)
  }

  updateTimeEstimate(totalTokensFromEvent = null) {
    if (!this.hasTimeEstimateTarget || !this.hasTimeEstimateContainerTarget) return

    const selectedTargets = this.getSelectedTargets()
    const totalInputTokens = totalTokensFromEvent ?? this.getTotalInputTokensFromOutlet()

    if (selectedTargets.length === 0 || totalInputTokens === 0) {
      this.hideTimeEstimate()
      return
    }

    // Filter out webchat targets and targets without rate
    const apiTargets = selectedTargets.filter(t =>
      t.type !== 'webchat' && t.tokensPerSecond > 0
    )

    if (apiTargets.length === 0) {
      this.hideTimeEstimate()
      return
    }

    // Count unmeasured API targets
    const unmeasuredCount = selectedTargets.filter(t =>
      t.type !== 'webchat' && t.tokensPerSecond === 0
    ).length

    // Calculate time for each target (seconds)
    // Multiply by 2 to account for unpredictable output token generation
    const estimatedTotalTokens = totalInputTokens * 2
    const targetTimes = apiTargets.map(t => estimatedTotalTokens / t.tokensPerSecond)

    // With parallelism: total sequential time / parallel limit
    const totalSequentialTime = targetTimes.reduce((a, b) => a + b, 0)
    const estimatedSeconds = totalSequentialTime / this.parallelLimitValue

    this.showTimeEstimate(estimatedSeconds, unmeasuredCount)
  }

  getSelectedTargets() {
    if (!this.hasTargetsSelectTarget) return []

    const select = this.targetsSelectTarget
    const selected = Array.from(select.selectedOptions)

    return selected.map(option => ({
      id: option.value,
      tokensPerSecond: parseFloat(option.dataset.tokensPerSecond) || 0,
      type: option.dataset.targetType || 'api'
    }))
  }

  // Get total tokens from probe-category outlet (Stimulus best practice)
  getTotalInputTokensFromOutlet() {
    if (!this.hasProbeCategoryOutlet) return 0
    return this.probeCategoryOutlet.totalTokens || 0
  }

  showTimeEstimate(seconds, unmeasuredCount = 0) {
    this.timeEstimateContainerTarget.classList.remove('hidden')
    this.timeEstimateContainerTarget.classList.add('flex')
    this.timeEstimateTarget.textContent = this.formatDuration(seconds)

    if (this.hasUnmeasuredWarningTarget) {
      if (unmeasuredCount > 0) {
        const label = unmeasuredCount === 1 ? 'target' : 'targets'
        this.unmeasuredWarningTarget.textContent = `(excludes ${unmeasuredCount} unmeasured ${label})`
        this.unmeasuredWarningTarget.classList.remove('hidden')
      } else {
        this.unmeasuredWarningTarget.classList.add('hidden')
      }
    }
  }

  hideTimeEstimate() {
    this.timeEstimateContainerTarget.classList.add('hidden')
    this.timeEstimateContainerTarget.classList.remove('flex')
    if (this.hasUnmeasuredWarningTarget) {
      this.unmeasuredWarningTarget.classList.add('hidden')
    }
  }

  formatDuration(seconds) {
    if (!Number.isFinite(seconds) || seconds <= 0) return '0m'

    const days = Math.floor(seconds / 86400)
    const hours = Math.floor((seconds % 86400) / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)

    const parts = []
    if (days > 0) parts.push(`${days}d`)
    if (hours > 0) parts.push(`${hours}h`)
    if (minutes > 0 || parts.length === 0) parts.push(`${minutes}m`)

    return parts.join(' ')
  }

  async initializeChoices() {
    const { default: Choices } = await import("/js/choices.js")

    if (this.hasTargetsSelectTarget) {
      const choicesInstance = new Choices(this.targetsSelectTarget, {
        removeItemButton: true,
        searchEnabled: true,
        searchPlaceholderValue: 'Search targets...',
        placeholder: true,
        placeholderValue: 'Select targets...',
        itemSelectText: ''
      })

      const urlParams = new URLSearchParams(window.location.search)
      const targetId = urlParams.get('target_id')

      if (targetId) {
        const selectOptions = Array.from(this.targetsSelectTarget.options)
        let targetName = ''

        selectOptions.forEach(option => {
          if (option.value === targetId) {
            choicesInstance.setChoiceByValue(targetId)
            targetName = option.textContent
          }
        })

        if (targetName && this.hasNameInputTarget) {
          if (!this.nameInputTarget.value) {
            const now = new Date()
            const formattedDate = now.toLocaleDateString('en-US', {
              month: 'short',
              day: 'numeric',
              year: 'numeric'
            }) + ' at ' + now.toLocaleTimeString('en-US', {
              hour: 'numeric',
              minute: '2-digit',
              hour12: true
            })
            this.nameInputTarget.value = `${targetName} - ${formattedDate}`
          }
        }
      }
    }
  }
}
