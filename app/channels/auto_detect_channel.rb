class AutoDetectChannel < ApplicationCable::Channel
  def subscribed
    # Verify and authorize the signed session_id
    signed_session_id = params[:session_id]

    unless authorized_session?(signed_session_id)
      Rails.logger.warn "AutoDetectChannel: Unauthorized subscription attempt with session_id: #{signed_session_id}"
      reject
      return
    end

    # Subscribe to a unique stream for this detection session
    stream_from "auto_detect_#{signed_session_id}"
    Rails.logger.info "AutoDetectChannel subscribed: #{signed_session_id} for user: #{current_user.id}"
  end

  def unsubscribed
    # Stop streaming from this session to prevent memory leaks
    stop_all_streams
    Rails.logger.info "AutoDetectChannel unsubscribed and cleaned up: #{params[:session_id]}"
  end

  private

  # Verify the cryptographically signed session_id and check user authorization
  # @param signed_session_id [String] the signed session ID from the client
  # @return [Boolean] true if the session is valid and belongs to the current user
  def authorized_session?(signed_session_id)
    return false if signed_session_id.blank?

    begin
      # Verify the signature and extract [user_id, uuid]
      verifier = Rails.application.message_verifier(:auto_detect_session)
      user_id, _uuid = verifier.verify(signed_session_id)

      # Check that the session was created for the current user
      user_id == current_user.id
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      # Signature verification failed - session was tampered with
      Rails.logger.warn "AutoDetectChannel: Invalid signature for session_id: #{signed_session_id}"
      false
    rescue StandardError => e
      # Unexpected error during verification
      Rails.logger.error "AutoDetectChannel: Error verifying session: #{e.message}"
      false
    end
  end
end
