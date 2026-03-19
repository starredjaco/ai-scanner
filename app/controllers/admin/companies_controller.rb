# frozen_string_literal: true

module Admin
  class CompaniesController < Admin::BaseController
    before_action :set_company, only: [ :show, :edit, :update, :destroy ]

    def index
      authorize Company
      @page_title = "Companies"
      @q = Company.ransack(params[:q])
      @q.sorts = "name asc" if @q.sorts.empty?
      @pagy, @companies = pagy(@q.result.includes(:users))

      # Load filter options
      @filter_tiers = Company.tiers.map { |k, v| [ k.titleize, v ] }
    end

    def show
      authorize @company
      @page_title = "Company: #{@company.name}"

      # Get users for this company (User doesn't use acts_as_tenant, query directly)
      @users = @company.users.order(:email)

      # Get stats within tenant context
      @stats = ActsAsTenant.with_tenant(@company) do
        {
          users_count: @company.users.count,  # User doesn't use acts_as_tenant
          targets_count: Target.count,
          scans_count: Scan.count,
          reports_count: Report.count
        }
      end
    end

    def new
      @company = Company.new
      authorize @company
      @page_title = "New Company"
    end

    def create
      @company = Company.new(company_params)
      authorize @company

      if @company.save
        redirect_to company_path(@company), notice: "Company was successfully created."
      else
        @page_title = "New Company"
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @company
      @page_title = "Edit Company: #{@company.name}"
    end

    def update
      authorize @company

      if @company.update(company_params)
        redirect_to company_path(@company), notice: "Company was successfully updated."
      else
        @page_title = "Edit Company: #{@company.name}"
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @company
      if @company.destroy
        redirect_to companies_path, notice: "Company was successfully deleted.", status: :see_other
      else
        redirect_to company_path(@company), alert: "Company could not be deleted."
      end
    end

    private

    def set_company
      @company = policy_scope(Company).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to companies_path, alert: "Company not found."
    end

    def company_params
      params.require(:company).permit(:name, :tier)
    end
  end
end
