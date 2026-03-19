# frozen_string_literal: true

module Admin
  class OutputServersController < Admin::BaseController
    before_action :set_output_server, only: [ :show, :edit, :update, :destroy, :test ]

    def index
      authorize OutputServer
      @page_title = "Integrations"

      @q = OutputServer.ransack(params[:q])
      @q.sorts = "created_at desc" if @q.sorts.empty?
      @pagy, @output_servers = pagy(@q.result)

      # Load filter options
      @filter_server_types = OutputServer.available_server_types.map { |t| [ t.humanize, t ] }
      @filter_protocols = OutputServer.protocols.keys.map { |p| [ p.upcase, p ] }
      @filter_enabled = [ [ "Yes", true ], [ "No", false ] ]
    end

    def show
      authorize @output_server
    end

    def new
      @output_server = OutputServer.new
      authorize @output_server
    end

    def create
      @output_server = OutputServer.new(output_server_params)
      authorize @output_server
      if @output_server.save
        redirect_to output_server_path(@output_server), notice: "Integration was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @output_server
    end

    def update
      authorize @output_server
      if @output_server.update(output_server_params)
        redirect_to output_server_path(@output_server), notice: "Integration was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @output_server
      @output_server.destroy
      redirect_to output_servers_path, notice: "Integration was successfully deleted.", status: :see_other
    end

    def test
      authorize @output_server
      result = OutputServers::ConnectionTest.new(@output_server).call

      if result[:success]
        redirect_to output_server_path(@output_server), notice: result[:message]
      else
        redirect_to output_server_path(@output_server), alert: result[:message]
      end
    end

    private

    def set_output_server
      @output_server = OutputServer.find(params[:id])
    end

    def output_server_params
      params.require(:output_server).permit(
        :name, :server_type, :host, :port, :protocol, :endpoint_path,
        :access_token, :api_key, :username, :password,
        :additional_settings, :enabled, :description
      )
    end

    def set_page_title
      @page_title = "Integrations"
    end

    # Helper method to get available server types (engine may extend via class_attribute)
    def available_server_types
      OutputServer.available_server_types
    end
    helper_method :available_server_types
  end
end
