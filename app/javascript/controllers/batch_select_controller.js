import { Controller } from "@hotwired/stimulus"

/**
 * Batch Select Controller
 *
 * Handles batch selection for table rows with:
 * - Select all / deselect all
 * - Individual checkbox toggling
 * - Automatic toolbar show/hide
 * - Selected count display
 * - Indeterminate state for partial selection
 * - Syncs selected IDs to external form via hidden inputs
 *
 * Usage:
 *   <form id="batch-form">
 *     <div data-batch-select-target="toolbar" class="hidden">
 *       <span data-batch-select-target="count">0</span> selected
 *       <button>Delete Selected</button>
 *     </div>
 *     <div data-batch-select-target="hiddenInputs"></div>
 *   </form>
 *
 *   <div data-controller="batch-select" data-batch-select-form-id-value="batch-form">
 *     <table>
 *       <thead>
 *         <tr>
 *           <th>
 *             <input type="checkbox"
 *                    data-batch-select-target="selectAll"
 *                    data-action="change->batch-select#toggleAll">
 *           </th>
 *         </tr>
 *       </thead>
 *       <tbody>
 *         <tr>
 *           <td>
 *             <input type="checkbox" value="123"
 *                    data-batch-select-target="checkbox"
 *                    data-action="change->batch-select#toggle">
 *           </td>
 *         </tr>
 *       </tbody>
 *     </table>
 *   </div>
 */
export default class extends Controller {
  static targets = ["checkbox", "selectAll", "toolbar", "count", "hiddenInputs"]
  static values = { formId: String }

  connect() {
    this.updateToolbar()
  }

  toggleAll() {
    const checked = this.selectAllTarget.checked
    this.checkboxTargets.forEach(cb => cb.checked = checked)
    this.updateToolbar()
    this.syncHiddenInputs()
  }

  toggle() {
    this.updateSelectAllState()
    this.updateToolbar()
    this.syncHiddenInputs()
  }

  clearAll() {
    this.checkboxTargets.forEach(cb => cb.checked = false)
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = false
    }
    this.updateToolbar()
    this.syncHiddenInputs()
  }

  updateSelectAllState() {
    if (!this.hasSelectAllTarget) return

    const allChecked = this.checkboxTargets.every(cb => cb.checked)
    const someChecked = this.checkboxTargets.some(cb => cb.checked)

    this.selectAllTarget.checked = allChecked
    this.selectAllTarget.indeterminate = someChecked && !allChecked
  }

  updateToolbar() {
    const count = this.checkboxTargets.filter(cb => cb.checked).length

    if (this.hasCountTarget) {
      this.countTarget.textContent = count
    }

    if (this.hasToolbarTarget) {
      if (count > 0) {
        this.toolbarTarget.classList.remove("hidden")
      } else {
        this.toolbarTarget.classList.add("hidden")
      }
    }
  }

  syncHiddenInputs() {
    if (!this.hasHiddenInputsTarget) return

    // Clear existing hidden inputs
    this.hiddenInputsTarget.innerHTML = ""

    // Add hidden input for each selected checkbox
    this.selectedIds.forEach(id => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "ids[]"
      input.value = id
      this.hiddenInputsTarget.appendChild(input)
    })
  }

  get selectedIds() {
    return this.checkboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
  }
}
