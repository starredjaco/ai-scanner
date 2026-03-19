require 'rails_helper'

RSpec.describe "Release Notes", type: :request do
  let!(:user) { create(:user) }
  let(:release_notes_filepath) { Rails.root.join("RELEASE_NOTES.md") }

  after do
    File.delete(release_notes_filepath) if File.exist?(release_notes_filepath)
  end

  describe "GET /admin/release_notes" do
    before { sign_in user }

    context "when RELEASE_NOTES.md exists" do
      let(:markdown_content) do
        <<~MARKDOWN
          ## 1.0.0 (2025-12-03)

          ### Features

          * add a new feature
          * **scanner:** add a new feature

          ### Bug Fixes

          * fix a bug
          * **scanner:** fix a bug

        MARKDOWN
      end

      before do
        File.write(release_notes_filepath, markdown_content)
      end

      it "renders the release notes page successfully" do
        get release_notes_path

        expect(response).to have_http_status(:success)
      end

      it "converts markdown to HTML" do
        get release_notes_path

        expect(response.body).to include("<h3 id=\"features\">Features</h3>")
        expect(response.body).to include("<h2 id=\"section\">1.0.0 (2025-12-03)</h2>")
        expect(response.body).to include("<h3 id=\"bug-fixes\">Bug Fixes</h3>")
      end

      it "renders markdown formatting correctly" do
        get release_notes_path

        expect(response.body).to include("<strong>scanner:</strong>")
        expect(response.body).to include("<li>add a new feature</li>")
      end
    end

    context "when RELEASE_NOTES.md does not exist" do
      before do
        File.delete(release_notes_filepath) if File.exist?(release_notes_filepath)
      end

      it "renders the page successfully" do
        get release_notes_path

        expect(response).to have_http_status(:success)
      end

      it "displays a message indicating no release notes are available" do
        get release_notes_path

        expect(response.body).to include("No release notes available.")
      end
    end

    it "displays the configured version number in the footer" do
      get root_path

      expect(response.body).to include(Rails.application.config.version)
      expect(response.body).to include(release_notes_path)
    end
  end
end
