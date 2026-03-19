# frozen_string_literal: true

module Admin
  class MetadataController < Admin::BaseController
    before_action :set_metadatum, only: [ :show, :edit, :update, :destroy ]

    def index
      authorize Metadatum
      @q = Metadatum.ransack(params[:q])
      @pagy, @metadata = pagy(@q.result.order(created_at: :desc))
    end

    def show
      authorize @metadatum
    end

    def new
      @metadatum = Metadatum.new
      authorize @metadatum
    end

    def create
      @metadatum = Metadatum.new(metadatum_params)
      authorize @metadatum
      if @metadatum.save
        redirect_to metadatum_path(@metadatum), notice: "Metadata was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @metadatum
    end

    def update
      authorize @metadatum
      if @metadatum.update(metadatum_params)
        redirect_to metadatum_path(@metadatum), notice: "Metadata was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @metadatum
      @metadatum.destroy
      redirect_to metadata_path, notice: "Metadata was successfully deleted.", status: :see_other
    end

    private

    def set_metadatum
      @metadatum = Metadatum.find(params[:id])
    end

    def metadatum_params
      params.require(:metadatum).permit(:key, :value)
    end

    def set_page_title
      @page_title = "Metadata"
    end
  end
end
