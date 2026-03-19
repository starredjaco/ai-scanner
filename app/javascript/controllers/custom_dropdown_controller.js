import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
     static targets = ["menu", "hiddenInput"];
     get menu() {
         return this.menuTarget;
     }

    toggle(event) {
        event.preventDefault();
        event.stopPropagation();
        this.menu.classList.toggle("hidden");
    }

    select(event) {
        event.preventDefault();
        const value = event.currentTarget.dataset.value;
        const text = event.currentTarget.innerText.trim();
        this.setMenuText(text)
        this.updateCheckmarks(value);
        this.updateHiddenInput(value);
        this.menu.classList.add("hidden");

        this.performTargetAction(value);
    }

    updateHiddenInput(value) {
        if (this.hasHiddenInputTarget) {
            this.hiddenInputTarget.value = value;
        }
    }

    updateCheckmarks(selectedValue) {
        // Remove all checkmarks
        this.element.querySelectorAll('.dropdown-check').forEach(check => {
            check.classList.add('hidden');
        });

        // Add checkmark to selected item
        const selectedButton = this.element.querySelector(`[data-value="${selectedValue}"]`);
        if (selectedButton) {
            const check = selectedButton.querySelector('.dropdown-check');
            if (check) {
                check.classList.remove('hidden');
            }
        }

        // Update the selected value on the main button
        const mainButton = this.element.querySelector('[data-selected-value]');
        if (mainButton) {
            mainButton.dataset.selectedValue = selectedValue;
        }
    }

    setMenuText(text) {
        const customTextElement = this.element.querySelector(".custom-dropdown__text");
        if (customTextElement) {
            customTextElement.innerText = text;
        }
    }

    performTargetAction(value){
        const actionName = this.element.dataset.customDropdownAction;
        const dashboardController = this.getDashboardController();
        if (!dashboardController || !actionName || typeof dashboardController[actionName] !== 'function') {
            return;
        }

        dashboardController[actionName](value);
    }

    closeIfClickedAway(event) {
        if (!this.element.contains(event.target)) {
            this.menu.classList.add("hidden");
        }
    }

    getDashboardController() {
        return this.application.getControllerForElementAndIdentifier(
            document.querySelector('[data-controller="dashboard"]'),
            "dashboard"
        );
    }
}