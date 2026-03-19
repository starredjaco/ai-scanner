# frozen_string_literal: true

class SwitchCompanyController < ApplicationController
  def update
    company = current_user.companies.find_by(id: params[:id])

    if company
      current_user.update_column(:current_company_id, company.id)
      flash[:notice] = "Switched to #{company.name}"
    else
      flash[:alert] = "Company not found or access denied"
    end

    redirect_back(fallback_location: root_path)
  end
end
