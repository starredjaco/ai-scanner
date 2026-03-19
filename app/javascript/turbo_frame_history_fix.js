/**
 * Fix for Turbo Frame history restoration with data-turbo-action="advance".
 *
 * When using turbo-frames with data-turbo-action="advance", the browser's
 * back button shows stale content because Turbo's snapshot is captured
 * AFTER the frame content is replaced, not before.
 *
 * This patch captures the page snapshot BEFORE frame navigation, then
 * passes it to the visit so restoration works correctly.
 */

Turbo.FrameElement.delegateConstructor.prototype.proposeVisitIfNavigatedWithAction = function (frame, action = null) {
  this.action = action
  if (!this.action) return

  const pageSnapshot = Turbo.PageSnapshot.fromElement(frame).clone()
  const { visitCachedSnapshot } = frame.delegate

  frame.delegate.fetchResponseLoaded = (fetchResponse) => {
    if (frame.src) {
      const { statusCode, redirected } = fetchResponse
      const responseHTML = frame.ownerDocument.documentElement.outerHTML
      const response = { statusCode, redirected, responseHTML }
      const options = {
        response,
        visitCachedSnapshot,
        willRender: false,
        updateHistory: false,
        restorationIdentifier: this.restorationIdentifier,
        snapshot: pageSnapshot
      }
      if (this.action) options.action = this.action
      Turbo.session.visit(frame.src, options)
    }
  }
}
