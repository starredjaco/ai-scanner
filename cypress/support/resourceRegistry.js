// Generic batch delete helper for admin index pages
Cypress.Commands.add('batchDeleteByNames', (indexPath, names, maxPages = 5) => {
  if (!Array.isArray(names) || names.length === 0) return cy.wrap(null)
  const remaining = new Set(names.filter(Boolean))

  const selectOnPage = () => {
    return cy.get('body').then(($body) => {
      const $rows = $body.find('table tbody tr')
      if (!$rows.length) return cy.wrap([])

      const found = []
      const namesToFind = Array.from(remaining)

      // Find matching rows using jQuery (synchronous)
      namesToFind.forEach((name) => {
        const matchedRow = $rows.filter((i, el) => {
          const txt = (el.innerText || el.textContent || '').toLowerCase()
          return txt.includes((name || '').toLowerCase())
        }).first()
        if (matchedRow && matchedRow.length) {
          found.push({ name, row: matchedRow })
        }
      })

      if (found.length === 0) return cy.wrap([])

      // Select checkboxes sequentially using proper Cypress chaining
      let chain = cy.wrap(null)
      found.forEach(({ row }) => {
        chain = chain.then(() => {
          return cy.wrap(row).find('input[type="checkbox"]').first().check({ force: true })
        })
      })

      return chain.then(() => cy.wrap(found.map(f => f.name)))
    })
  }

  const openBatchMenuAndDelete = () => {
    cy.on('window:confirm', () => true)

    // Wait for the batch toolbar to become visible (Turbo/Rails 7+ style)
    // The toolbar appears when checkboxes are selected
    cy.get('[data-batch-select-target="toolbar"]', { timeout: 4000 })
      .should('be.visible')
      .within(() => {
        // Click the Delete button (button with name="batch_action" and value="destroy")
        cy.get('button[name="batch_action"][value="destroy"]').click({ force: true })
      })

    // Wait for Turbo to process and reload the page
    cy.wait(1000)
    return cy.reload()
  }

  const runAcrossPages = (pageNum = 1) => {
    if (remaining.size === 0 || pageNum > maxPages) return cy.wrap(null)
    // Try to select any remaining names on this page
    return selectOnPage().then((selectedNames) => {
      if (selectedNames.length > 0) {
        // Perform batch delete for the selected rows
        return openBatchMenuAndDelete().then(() => {
          // Remove selected from remaining and try again on the same page (list changed)
          selectedNames.forEach((n) => remaining.delete(n))
          return runAcrossPages(pageNum)
        })
      }
      // Nothing selected on this page; go to next page if available
      return cy.get('body').then(($body) => {
        const nextSel = $body.find('a[rel="next"], .pagination a:contains("Next"), a:contains("Next")').first()
        if (nextSel.length) {
          cy.wrap(nextSel).click({ force: true })
          return runAcrossPages(pageNum + 1)
        }
        // No more pages
        return cy.wrap(null)
      })
    })
  }

  // Start navigation on the provided indexPath first page
  return cy.visit(indexPath)
    .then(() => cy.get('table tbody', { timeout: 10000 }).should('exist'))
    .then(() => runAcrossPages(1))
})

// Thin wrappers for resource-specific convenience
Cypress.Commands.add('batchDeleteScansByNames', (names, maxPages = 5) => {
  return cy.batchDeleteByNames('/scans?scope=all', names, maxPages)
})

Cypress.Commands.add('batchDeleteReportsByNames', (names, maxPages = 5) => {
  return cy.batchDeleteByNames('/reports?scope=all', names, maxPages)
})

// Commands to track resources created by tests and clean them up later

Cypress.Commands.add('trackResource', (resource) => {
  // resource: { type: 'scan'|'target'|'envVar'|'report', name?: string, scanName?: string }
  if (!resource || (!resource.name && !resource.scanName)) return cy.wrap(null)
  return cy.task('registry:add', resource)
})

Cypress.Commands.add('getTrackedResources', () => {
  return cy.task('registry:get')
})

Cypress.Commands.add('clearTrackedResources', () => {
  return cy.task('registry:clear')
})

// UI deletion helper:
// - Opens the index page
// - Deletes ALL rows whose text contains the label (case-insensitive) across up to maxPages
// - Clicks common Delete link variants and accepts confirm dialogs
Cypress.Commands.add('deleteByNameOnIndex', (indexPath, label, maxPages = 5) => {
  if (!label) return cy.wrap(false)

  const deleteOnThisPageOnce = () => {
    // Use jQuery scanning to avoid throwing when not found
    return cy.get('body').then(($body) => {
      const $rows = $body.find('table tbody tr')
      if (!$rows.length) return cy.wrap(false)
      const target = (label || '').toLowerCase()
      let idx = -1
      $rows.each((i, el) => {
        const txt = (el.innerText || el.textContent || '').toLowerCase()
        if (idx === -1 && txt.includes(target)) idx = i
      })
      if (idx === -1) return cy.wrap(false)
      const row = $rows.eq(idx)
      cy.on('window:confirm', () => true)

      // Check what delete actions exist in this row before trying to click them
      return cy.wrap(row).then(($row) => {
        // 1) Look for button/link with title containing "Delete" (modern style, case-insensitive)
        const $deleteByTitle = $row.find('button[title], a[title]').filter((i, el) => {
          const title = el.getAttribute('title') || ''
          return /delete/i.test(title)
        })
        if ($deleteByTitle.length > 0) {
          return cy.wrap($deleteByTitle.first()).click({ force: true }).then(() => true)
        }

        // 2) Look for data-method="delete" or data-action="destroy" (Rails UJS)
        const $deleteByData = $row.find('[data-method="delete"], [data-action="destroy"]')
        if ($deleteByData.length > 0) {
          return cy.wrap($deleteByData.first()).click({ force: true }).then(() => true)
        }

        // 3) Look for text containing "Delete" (fallback)
        const $deleteByText = $row.find('button, a').filter((i, el) => {
          const text = el.textContent || el.innerText || ''
          return /delete/i.test(text)
        })
        if ($deleteByText.length > 0) {
          return cy.wrap($deleteByText.first()).click({ force: true }).then(() => true)
        }

        // No delete button found in this row
        return cy.wrap(false)
      })
    })
  }

  const deleteUntilGoneOnPage = () => {
    return deleteOnThisPageOnce().then((deleted) => {
      if (!deleted) return cy.wrap(false)
      return cy.reload().then(() => deleteUntilGoneOnPage())
    })
  }

  const goNextPageIfAny = (pageNum) => {
    return cy.get('body').then(($body) => {
      const nextSelCandidates = [
        'a[rel="next"]',
        '.pagination a:contains("Next")',
        'a:contains("Next")',
      ]
      for (const sel of nextSelCandidates) {
        const el = $body.find(sel).first()
        if (el.length) {
          cy.wrap(el).click({ force: true })
          return cy.wrap(true)
        }
      }
      return cy.wrap(false)
    })
  }

  const runAcrossPages = (pageNum = 1) => {
    return deleteUntilGoneOnPage().then(() => {
      if (pageNum >= maxPages) return cy.wrap(null)
      return goNextPageIfAny(pageNum).then((moved) => {
        if (!moved) return cy.wrap(null)
        return runAcrossPages(pageNum + 1)
      })
    })
  }

  // Start on first page
  return cy.visit(indexPath)
    .then(() => cy.get('table tbody', { timeout: 10000 }).should('exist'))
    .then(() => runAcrossPages(1))
})

// Batch delete helper for Targets using shared generic helper
Cypress.Commands.add('batchDeleteTargetsByNames', (names, maxPages = 5) => {
  return cy.batchDeleteByNames('/targets', names, maxPages)
})


// Clean up tracked resources in safe order
Cypress.Commands.add('cleanupTrackedResources', () => {
  return cy.getTrackedResources().then((all) => {
    if (!Array.isArray(all) || all.length === 0) return cy.wrap(null)

    const byType = (t) => all.filter(x => x.type === t)

    // 1) Reports (by scan name), 2) Scans, 3) Targets, 4) Env Vars
    const reports = byType('report')
    const scans   = byType('scan')
    const targets = byType('target')
    const envVars = byType('envVar')

    // Build report-name set from tracked reports and tracked scans (their reports often block scan deletion)
    const reportScanNames = Array.from(new Set([
      ...reports.filter(r => !!r.scanName).map(r => r.scanName),
      ...scans.filter(s => !!s.name).map(s => s.name),
    ]))

    const deleteReports = () => {
      if (reportScanNames.length === 0) return cy.wrap(null)
      // Reports index uses batch actions only; delete by scan name
      return cy.batchDeleteReportsByNames(reportScanNames)
    }

    const deleteScans = () => {
      if (scans.length === 0) return cy.wrap(null)
      const names = scans.map(s => s.name).filter(Boolean)
      // Scans index uses batch actions only; include scheduled + one-off via scope=all
      return cy.batchDeleteScansByNames(names)
    }

    const deleteTargets = () => {
      if (targets.length === 0) return cy.wrap(null)
      // Targets can only be deleted from the show page, not index
      const named = targets.filter(t => !!t.name)
      return cy.wrap(named, { log: false }).each((t) => {
        // Visit targets index and find the target by name
        cy.visit('/targets')
        cy.get('table tbody', { timeout: 10000 }).should('exist')
        cy.get('body').then(($body) => {
          const $rows = $body.find('table tbody tr')
          const target = (t.name || '').toLowerCase()
          const matchedRow = $rows.filter((i, el) => {
            const txt = (el.innerText || el.textContent || '').toLowerCase()
            return txt.includes(target)
          }).first()

          if (matchedRow && matchedRow.length) {
            // Click on the target name link to go to show page
            cy.wrap(matchedRow).find('a').first().click()
            cy.on('window:confirm', () => true)
            // Click Delete Target button on show page
            cy.get('button, a').then($buttons => {
              const deleteBtn = Array.from($buttons).find(el =>
                /delete\s*target/i.test(el.textContent || '') ||
                /delete/i.test(el.getAttribute('title') || '')
              )
              if (deleteBtn) {
                cy.wrap(deleteBtn).click({ force: true })
                cy.wait(500) // Wait for deletion to process
              }
            })
          }
        })
      })
    }

    const deleteEnvVars = () => {
      if (envVars.length === 0) return cy.wrap(null)
      const named = envVars.filter(v => !!v.name)
      return cy.wrap(named, { log: false }).each((v) => {
        return cy.deleteByNameOnIndex('/environment_variables', v.name)
      })
    }

    // Ensure strict ordering: reports → scans → targets → env vars
    return cy.wrap(null)
      .then(deleteReports)
      .then(deleteScans)
      .then(deleteTargets)
      .then(deleteEnvVars)
      .then(() => cy.clearTrackedResources())
  })
})
