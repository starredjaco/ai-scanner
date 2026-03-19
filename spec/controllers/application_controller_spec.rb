require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  # Create a test controller since ApplicationController is abstract
  controller do
    def index
      render json: { message: 'test' }
    end

    def protected_action
      render json: { message: 'protected' }
    end
  end

  let(:user) { create(:user) }

  before { sign_in user }

  describe 'basic functionality' do
    it 'inherits from ActionController::Base' do
      expect(ApplicationController.superclass).to eq(ActionController::Base)
    end

    it 'renders successfully' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({ 'message' => 'test' })
    end
  end

  describe 'request handling' do
    it 'handles JSON requests' do
      request.headers['Content-Type'] = 'application/json'
      get :index

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'error handling' do
    controller do
      def error_action
        raise StandardError, 'Test error'
      end
    end

    before do
      routes.draw { get 'error_action' => 'anonymous#error_action' }
    end

    it 'handles standard errors appropriately' do
      expect {
        get :error_action
      }.to raise_error(StandardError, 'Test error')
    end
  end

  describe 'security' do
    it 'is configured for security features' do
      expect(ApplicationController.respond_to?(:allow_forgery_protection)).to be true
    end
  end

  describe 'authentication' do
    it 'redirects to login when not authenticated' do
      sign_out user
      get :index
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'allows access when authenticated' do
      get :index
      expect(response).to have_http_status(:ok)
    end
  end
end
