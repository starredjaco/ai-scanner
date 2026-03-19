describe('Simple Scan Creation', () => {
  // Ignore known errors that don't affect test validity
  Cypress.on('uncaught:exception', (err, runnable) => {
    if (err.message.includes('Cannot read properties of undefined') && err.message.includes('push')) {
      return false
    }
    if (err.message.includes('outlet controller') && err.message.includes('probe-category')) {
      return false
    }
    return true
  })

  it('creates a scan with minimal configuration', () => {
    const timestamp = Date.now()
    const targetName = `Target ${timestamp}`
    const scanName = `Scan ${timestamp}`

    // First create a target via the wizard
    cy.visit('/targets/new')

    // Step 1: Select Custom Configuration
    cy.get('[data-provider="custom"]').click()

    // Step 2: Fill target details
    cy.get('#target_name').should('be.visible').type(targetName)
    cy.get('[data-target-wizard-target="modelTypeSelect"]').select('REST API (Generic)')
    cy.get('#target_model').type('test-model')

    // Add JSON config using mock LLM endpoint
    cy.getRestGeneratorConfig('test').then(config => {
      cy.get('#target_json_config').type(JSON.stringify(config), { parseSpecialCharSequences: false })
    })

    // Step 2 → Step 3
    cy.contains('button', 'Next: Review').click()

    // Step 3: Submit
    cy.contains('button[type="submit"]', 'Create Target').click()

    // Wait for redirect to target show page
    cy.location('pathname').should('match', /^\/targets\/\d+$/)

    // Track the created target for cleanup
    cy.trackResource({ type: 'target', name: targetName })

    // Wait for validation
    cy.wait(3000)
    cy.reload()

    // Now create a scan
    cy.visit('/scans/new')
    cy.wait(2000)

    // Fill scan name
    cy.get('#scan_name', { timeout: 10000 }).type(scanName)
    cy.wait(2000)

    // Select target and probe
    cy.selectTargetByName(targetName)
    cy.selectProbeByName('dan.Dan_11_0', 'dan')

    // Submit scan
    cy.contains('button[type="submit"]', 'Create Scan').click()

    // Verify creation
    cy.location('pathname').should('match', /^\/scans\/\d+$/)
    cy.contains(scanName).should('be.visible')

    // Track created scan
    cy.trackResource({ type: 'scan', name: scanName })

    // Verify that a report was created for this scan
    cy.verifyReportCreated(scanName, targetName)
  })
})
