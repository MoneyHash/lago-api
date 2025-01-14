# frozen_string_literal: true

module Types
  module PaymentProviders
    class UpdateInput < BaseInputObject
      description 'Update input arguments'

      argument :code, String, required: false
      argument :id, ID, required: true
      argument :name, String, required: false
      argument :success_redirect_url, String, required: false
      argument :failed_redirect_url, String, required: false
      argument :pending_redirect_url, String, required: false
      argument :webhook_redirect_url, String, required: false
    end
  end
end
