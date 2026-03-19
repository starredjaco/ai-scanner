# frozen_string_literal: true

module Admin
  class UsersController < Admin::BaseController
    before_action :authenticate_user!
    before_action :set_user, only: [ :show, :edit, :update, :destroy ]

    # UsersController uses policy_scope for custom scoping (super admins see all users)
    # This verification ensures we don't accidentally remove the policy_scope call
    after_action :verify_policy_scoped, only: :index

    def index
      @page_title = "Users"
      authorize User  # Checks UserPolicy#index? - required by verify_authorized
      @users = policy_scope(User)  # Filters collection - required by verify_policy_scoped
      @q = @users.ransack(params[:q])
      @q.sorts = "created_at desc" if @q.sorts.empty?
      @pagy, @users = pagy(@q.result)

      # Load filter options
      @filter_super_admin = [ [ "Yes", true ], [ "No", false ] ]
      @filter_companies = Company.order(:name).pluck(:name, :id) if policy(User).see_company_column?
    end

    def show
      authorize @user
    end

    def new
      @user = User.new
      authorize @user
      # Pre-assign company for non-super admins
      @user.company = current_user.company unless policy(User).manage_company?
    end

    def create
      @user = User.new(user_params)
      authorize @user

      # Non-super admins can only create users in their own company
      @user.company = current_user.company unless policy(User).manage_company?

      if @user.save
        redirect_to user_path(@user), notice: "User was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @user
    end

    def update
      authorize @user

      update_params = user_params

      # Remove password fields if blank
      if update_params[:password].blank?
        update_params = update_params.except(:password, :password_confirmation)
      end

      if @user.update(update_params)
        redirect_to user_path(@user), notice: "User was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @user
      @user.destroy
      redirect_to users_path, notice: "User was successfully deleted.", status: :see_other
    end

    private

    def set_user
      # Use policy scope to find user - handles super_admin bypass
      @user = policy_scope(User).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to users_path, alert: "User not found."
    end

    def set_page_title
      @page_title = "Users"
    end

    def user_params
      permitted = [ :email, :password, :password_confirmation, :time_zone ]
      permitted << :super_admin if policy(User).manage_super_admin_flag?
      permitted << :current_company_id if policy(User).manage_company?
      params.require(:user).permit(permitted)
    end
  end
end
