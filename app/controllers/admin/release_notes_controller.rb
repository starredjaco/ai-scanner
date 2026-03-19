# frozen_string_literal: true

module Admin
  class ReleaseNotesController < Admin::BaseController
    def show
      skip_authorization # Release notes are accessible to all authenticated users
      @page_title = "Release Notes"
      release_notes_path = Rails.root.join("RELEASE_NOTES.md")

      if File.exist?(release_notes_path)
        markdown_content = File.read(release_notes_path)
        @content = Kramdown::Document.new(markdown_content).to_html.html_safe
      else
        @content = "<p>No release notes available.</p>".html_safe
      end
    end
  end
end
