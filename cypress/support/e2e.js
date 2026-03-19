// Import order matters: registry commands first, then the rest
import './resourceRegistry'
import './commands'

// Establish and cache login session before specs
before(() => {
  const email = Cypress.env('ADMIN_EMAIL')
  const password = Cypress.env('ADMIN_PASSWORD')
  if (!email || !password) return
  cy.loginSession(email, password, { cacheAcrossSpecs: true })
})

// Restore cached session before each test (fast, no re-login)
beforeEach(() => {
  const email = Cypress.env('ADMIN_EMAIL')
  const password = Cypress.env('ADMIN_PASSWORD')
  if (!email || !password) return
  cy.loginSession(email, password, { cacheAcrossSpecs: true })
})

// Mark failures so we can conditionally skip cleanup when any test fails
afterEach(function () {
  // Use function() to access Mocha context
  if (this.currentTest && this.currentTest.state === 'failed') {
    cy.task('failures:mark')
  }
})

// Alternatively you can use CommonJS syntax:
// require('./commands')
