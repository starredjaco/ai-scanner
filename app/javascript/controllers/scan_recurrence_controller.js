import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recurrenceType", "hourlyOptions", "dailyOptions", "weeklyOptions", "monthlyOptions", "dayOfMonthInput", "timeInput", "minutesInput", "timeDropdown", "minutesDropdown", "minutesHelp", "timeHelp", "recurrenceInput", "frequencyButtons", "timeConfigSection"]
  static outlets = ["probe-category"]
  static values = { timezone: String }

  connect() {
    // Store bound handlers for cleanup
    this._dayLabelHandlers = new Map()

    this.initializeFromExistingData()
    this.updateVisibility()
    this.setupDaySelectors()
    this.updateFrequencyButtons()
    this.dispatchInitialSchedule()
  }

  disconnect() {
    // Clean up day selector event listeners
    if (this._dayLabelHandlers) {
      this._dayLabelHandlers.forEach((handler, label) => {
        label.removeEventListener('click', handler)
      })
      this._dayLabelHandlers.clear()
    }

    // Cancel any pending animation frame
    if (this._initialDispatchFrame) {
      cancelAnimationFrame(this._initialDispatchFrame)
    }
  }

  dispatchInitialSchedule() {
    // Use requestAnimationFrame to ensure DOM is ready, then dispatch
    // This is more reliable than setTimeout and can be properly cancelled
    this._initialDispatchFrame = requestAnimationFrame(() => {
      const type = this.recurrenceTypeTarget.value
      const runsPerMonth = this.calculateRunsPerMonth(type)
      this.dispatchScheduleChanged(runsPerMonth)
    })
  }

  initializeFromExistingData() {
    const recurrenceData = this.recurrenceInputTarget.value
    if (!recurrenceData) return

    const recurrence = JSON.parse(recurrenceData)

    if (recurrence.rule_type) {
      const uiType = this.getUIFriendlyFrequency(recurrence.rule_type)
      if (uiType) this.recurrenceTypeTarget.value = uiType
      if (recurrence.validations) {
        const utcHour = recurrence.validations.hour_of_day ? recurrence.validations.hour_of_day[0] : 0
        const utcMinute = recurrence.validations.minute_of_hour ? recurrence.validations.minute_of_hour[0] : 0

        if (uiType === "hourly") {
          this.minutesInputTarget.value = utcMinute.toString().padStart(2, '0')
        } else {
          const localTime = this.convertFromUTC(utcHour, utcMinute)
          this.timeInputTarget.value = `${localTime.hours.toString().padStart(2, '0')}:${localTime.minutes.toString().padStart(2, '0')}`
        }
      }
      else if (recurrence.start_time) {
        const startTime = new Date(recurrence.start_time)
        const hours = startTime.getHours().toString().padStart(2, '0')
        const minutes = startTime.getMinutes().toString().padStart(2, '0')
        this.timeInputTarget.value = `${hours}:${minutes}`
      }

      if (uiType === "monthly" && recurrence.validations && recurrence.validations.day_of_month) {
        const utcDayOfMonth = recurrence.validations.day_of_month[0]
        const utcHourM = recurrence.validations.hour_of_day ? recurrence.validations.hour_of_day[0] : 0
        const utcMinuteM = recurrence.validations.minute_of_hour ? recurrence.validations.minute_of_hour[0] : 0
        const localDayOfMonth = this.convertDayOfMonthFromUTC(utcDayOfMonth, utcHourM, utcMinuteM)
        this.dayOfMonthInputTarget.value = localDayOfMonth.toString()
      }

      if (uiType === "weekly" && recurrence.validations && recurrence.validations.day) {
        const utcDays = recurrence.validations.day
        const utcHour = recurrence.validations.hour_of_day ? recurrence.validations.hour_of_day[0] : 0
        const utcMinute = recurrence.validations.minute_of_hour ? recurrence.validations.minute_of_hour[0] : 0
        const userDays = this.convertDaysFromUTC(utcDays, utcHour, utcMinute)
        
        userDays.forEach(day => {
          const checkbox = document.getElementById(`weekday_${day}`)
          if (checkbox) {
            checkbox.checked = true
            const label = document.querySelector(`label[for="weekday_${day}"]`)
            if (label) this.applyDayButtonStyles(checkbox, label)
          }
        })
      }
    }
  }

  // Returns the offset in minutes between the display timezone and UTC
  // Positive = east of UTC (e.g., +60 for CET), negative = west (e.g., -360 for CST)
  getDisplayTimezoneOffset() {
    const tz = this.timezoneValue
    const now = new Date()
    const utcDate = new Date(now.toLocaleString('en-US', { timeZone: 'UTC' }))
    const tzDate = new Date(now.toLocaleString('en-US', { timeZone: tz }))
    return (tzDate - utcDate) / 60000
  }

  convertFromUTC(utcHours, utcMinutes) {
    const offset = this.getDisplayTimezoneOffset()
    let totalMinutes = utcHours * 60 + utcMinutes + offset
    return {
      hours: ((Math.floor(totalMinutes / 60) % 24) + 24) % 24,
      minutes: ((totalMinutes % 60) + 60) % 60
    }
  }

  convertDaysFromUTC(utcDays, utcHours, utcMinutes) {
    const offset = this.getDisplayTimezoneOffset()
    return utcDays.map(utcDay => {
      let totalMinutes = utcHours * 60 + utcMinutes + offset
      let dayShift = 0
      if (totalMinutes < 0) dayShift = -1
      if (totalMinutes >= 24 * 60) dayShift = 1
      return ((utcDay + dayShift) % 7 + 7) % 7
    }).filter((day, index, self) => self.indexOf(day) === index)
  }

  getUIFriendlyFrequency(type) {
    switch(type) {
      case "IceCube::HourlyRule": return "hourly";
      case "IceCube::DailyRule": return "daily";
      case "IceCube::WeeklyRule": return "weekly";
      case "IceCube::MonthlyRule": return "monthly";
      default: return null;
    }
  }

  updateVisibility() {
    const selectedType = this.recurrenceTypeTarget.value

    this.hideAllOptions()
    this.hideAllTimeInputs()
    this.configureVisibilityForType(selectedType)
  }

  configureVisibilityForType(type) {
    this.minutesHelpTarget.classList.add("hidden")
    this.timeHelpTarget.classList.add("hidden")

    // Hide time configuration section when none is selected
    if (type === "none") {
      if (this.hasTimeConfigSectionTarget) {
        this.timeConfigSectionTarget.classList.add("hidden")
      }
    } else {
      if (this.hasTimeConfigSectionTarget) {
        this.timeConfigSectionTarget.classList.remove("hidden")
      }
    }

    switch(type) {
      case 'hourly':
        this.hourlyOptionsTarget.classList.remove("hidden")
        this.minutesDropdownTarget.classList.remove("hidden")
        this.minutesHelpTarget.classList.remove("hidden")
        break
      case 'daily':
        this.dailyOptionsTarget.classList.remove("hidden")
        this.timeDropdownTarget.classList.remove("hidden")
        this.timeHelpTarget.classList.remove("hidden")
        break
      case 'weekly':
        this.weeklyOptionsTarget.classList.remove("hidden")
        this.timeDropdownTarget.classList.remove("hidden")
        this.timeHelpTarget.classList.remove("hidden")
        break
      case 'monthly':
        this.monthlyOptionsTarget.classList.remove("hidden")
        this.timeDropdownTarget.classList.remove("hidden")
        this.timeHelpTarget.classList.remove("hidden")
        break
    }
  }

  hideAllOptions() {
    this.hourlyOptionsTarget.classList.add("hidden")
    this.dailyOptionsTarget.classList.add("hidden")
    this.weeklyOptionsTarget.classList.add("hidden")
    this.monthlyOptionsTarget.classList.add("hidden")
  }

  hideAllTimeInputs() {
    this.timeDropdownTarget.classList.add("hidden")
    this.minutesDropdownTarget.classList.add("hidden")
  }

  setupDaySelectors() {
    const dayLabels = this.element.querySelectorAll('label[for^="weekday_"]')

    dayLabels.forEach(label => {
      // Create handler and store reference for cleanup
      const handler = (event) => {
        event.preventDefault()

        const checkboxId = label.getAttribute('for')
        const checkbox = document.getElementById(checkboxId)

        if (checkbox) {
          checkbox.checked = !checkbox.checked

          this.applyDayButtonStyles(checkbox, label)

          this.updateRecurrenceValue()
        }
      }

      label.addEventListener('click', handler)
      this._dayLabelHandlers.set(label, handler)

      // Apply initial styles
      const checkboxId = label.getAttribute('for')
      const checkbox = document.getElementById(checkboxId)
      if (checkbox) {
        this.applyDayButtonStyles(checkbox, label)
      }
    })
  }

  applyDayButtonStyles(checkbox, label) {
    if (checkbox.checked) {
      label.classList.add('day-button--selected')
      label.dataset.selected = 'true'
    } else {
      label.classList.remove('day-button--selected')
      delete label.dataset.selected
    }
  }

  updateRecurrenceValue() {
    const type = this.recurrenceTypeTarget.value
    if (type === "none") {
      this.recurrenceInputTarget.value = ""
      this.dispatchScheduleChanged(0)
      return
    }

    let recurrence = {
      rule_type: this.getIceCubeFriendlyFrequency(type),
      interval: 1,
      validations: {}
    }
    this.setTimeValidations(recurrence, type)

    if (type === "weekly") {
      this.setWeeklyDayValidations(recurrence)
    }

    if (type === "monthly") {
      const dayOfMonth = parseInt(this.dayOfMonthInputTarget.value, 10) || 1
      const { hours: localHours, minutes: localMinutes } = this.getLocalTimeFromInput()
      const utcDayOfMonth = this.convertDayOfMonthToUTC(dayOfMonth, localHours, localMinutes)
      recurrence.validations.day_of_month = [utcDayOfMonth]
    }

    this.recurrenceInputTarget.value = JSON.stringify(recurrence)

    // Calculate and dispatch runs per month
    const runsPerMonth = this.calculateRunsPerMonth(type)
    this.dispatchScheduleChanged(runsPerMonth)
  }

  calculateRunsPerMonth(type) {
    switch(type) {
      case 'hourly':
        return 24 * 30 // ~720 runs per month
      case 'daily':
        return 30 // 30 runs per month
      case 'weekly':
        const selectedDays = this.getSelectedWeekdays()
        return selectedDays.length * 4 // ~4 weeks per month
      case 'monthly':
        return 1
      default:
        return 0
    }
  }

  dispatchScheduleChanged(runsPerMonth) {
    // Guard: hasProbeCategoryOutlet checks element presence, not controller readiness.
    // probeCategoryOutlet throws if the element exists but its controller hasn't connected
    // yet (e.g. during initial rAF dispatch). Keep the accessor inside try-catch.
    if (!this.hasProbeCategoryOutlet) return
    try {
      this.probeCategoryOutlet.element.dispatchEvent(new CustomEvent('scheduleChanged', {
        detail: { runsPerMonth },
        bubbles: true
      }))
    } catch {
      // Outlet element present but controller not yet connected — safe to ignore
    }
  }

  setTimeValidations(recurrence, type) {
    if (type === "hourly") {
      const minutes = parseInt(this.minutesInputTarget.value, 10) || 0
      recurrence.validations.minute_of_hour = [minutes]
    } else {
      const { hours, minutes } = this.getUTCTimeFromInput()
      recurrence.validations.hour_of_day = [hours]
      recurrence.validations.minute_of_hour = [minutes]
    }
  }

  setWeeklyDayValidations(recurrence) {
    const selectedDays = this.getSelectedWeekdays()
    
    if (selectedDays.length > 0) {
      const { hours, minutes } = this.getLocalTimeFromInput()
      const utcDays = this.convertDaysToUTC(selectedDays, hours, minutes)
      recurrence.validations.day = utcDays
    } else {
      recurrence.validations.day = [1]
    }
  }

  getUTCTimeFromInput() {
    const { hours, minutes } = this.getLocalTimeFromInput()
    return this.convertToUTC(hours, minutes)
  }

  getLocalTimeFromInput() {
    const timeValue = this.timeInputTarget.value || "00:00"
    const [hours, minutes] = timeValue.split(":").map(num => parseInt(num, 10))
    return { hours, minutes }
  }

  getSelectedWeekdays() {
    return Array.from(
      this.element.querySelectorAll('input[name="weekday"]:checked')
    ).map(checkbox => parseInt(checkbox.value, 10))
  }

  convertToUTC(hours, minutes) {
    const offset = this.getDisplayTimezoneOffset()
    let totalMinutes = hours * 60 + minutes - offset
    return {
      hours: ((Math.floor(totalMinutes / 60) % 24) + 24) % 24,
      minutes: ((totalMinutes % 60) + 60) % 60
    }
  }

  convertDayOfMonthToUTC(dayOfMonth, hours, minutes) {
    const offset = this.getDisplayTimezoneOffset()
    let totalMinutes = hours * 60 + minutes - offset
    let dayShift = 0
    if (totalMinutes < 0) dayShift = -1
    if (totalMinutes >= 24 * 60) dayShift = 1
    return Math.max(1, Math.min(28, dayOfMonth + dayShift))
  }

  convertDayOfMonthFromUTC(utcDayOfMonth, utcHours, utcMinutes) {
    const offset = this.getDisplayTimezoneOffset()
    let totalMinutes = utcHours * 60 + utcMinutes + offset
    let dayShift = 0
    if (totalMinutes < 0) dayShift = -1
    if (totalMinutes >= 24 * 60) dayShift = 1
    return Math.max(1, Math.min(28, utcDayOfMonth + dayShift))
  }

  convertDaysToUTC(selectedDays, hours, minutes) {
    const offset = this.getDisplayTimezoneOffset()
    return selectedDays.map(day => {
      let totalMinutes = hours * 60 + minutes - offset
      let dayShift = 0
      if (totalMinutes < 0) dayShift = -1
      if (totalMinutes >= 24 * 60) dayShift = 1
      return ((day + dayShift) % 7 + 7) % 7
    }).filter((day, index, self) => self.indexOf(day) === index)
  }

  getIceCubeFriendlyFrequency(type) {
    switch(type) {
      case "hourly": return "IceCube::HourlyRule";
      case "daily": return "IceCube::DailyRule";
      case "weekly": return "IceCube::WeeklyRule";
      case "monthly": return "IceCube::MonthlyRule";
      default: return null;
    }
  }

  // Visual frequency selector methods
  selectFrequency(event) {
    event.preventDefault()
    const frequency = event.currentTarget.dataset.frequency
    this.recurrenceTypeTarget.value = frequency
    this.updateVisibility()
    this.updateFrequencyButtons()
    this.updateRecurrenceValue()
  }

  updateFrequencyButtons() {
    if (!this.hasFrequencyButtonsTarget) return

    const selectedType = this.recurrenceTypeTarget.value
    const buttons = this.frequencyButtonsTarget.querySelectorAll('.frequency-button')

    buttons.forEach(button => {
      const isSelected = button.dataset.frequency === selectedType
      if (isSelected) {
        button.classList.add('!bg-primary/10', '!border-primary')
        button.classList.remove('bg-backgroundSecondary', 'border-borderPrimary')
      } else {
        button.classList.remove('!bg-primary/10', '!border-primary')
        button.classList.add('bg-backgroundSecondary', 'border-borderPrimary')
      }
    })
  }
}
