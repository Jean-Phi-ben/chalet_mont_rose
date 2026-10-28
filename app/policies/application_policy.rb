# frozen_string_literal: true

# Base des autorisations : tout le back-office est réservé aux administrateurs
# (User#admin?, liste blanche ADMIN_EMAILS). Les policies concrètes ouvrent
# chaque action avec `admin?` et, au besoin, une condition sur l'état du record.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?   = false
  def show?    = false
  def create?  = false
  def new?     = create?
  def update?  = false
  def edit?    = update?
  def destroy? = false

  # Un administrateur voit tout ; les autres rien.
  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      user&.admin? ? scope.all : scope.none
    end

    private

    attr_reader :user, :scope
  end

  private

  def admin?
    user&.admin?
  end
end
