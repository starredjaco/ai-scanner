# frozen_string_literal: true

module Admin
  class GlossaryController < Admin::BaseController
    def show
      skip_authorization # Glossary is accessible to all authenticated users
      @page_title = "Glossary"
    end
  end
end
