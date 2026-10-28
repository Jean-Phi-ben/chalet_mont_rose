class PagesController < ApplicationController
  include HomePage
  allow_unauthenticated_access only: %i[home privacy legal terms]

  def home
    prepare_home
  end

  def privacy
  end

  def legal
  end

  def terms
  end

  private

  def indexable?
    true
  end
end
