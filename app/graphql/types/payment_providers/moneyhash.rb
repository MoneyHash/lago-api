# frozen_string_literal: true

module Types
  module PaymentProviders
    class Moneyhash < Types::BaseObject
      graphql_name 'MoneyhashProvider'

      field :code, String, null: false
      field :id, ID, null: false
      field :name, String, null: false
      field :api_key, String, null: true, permission: 'organization:integrations:view'
      field :flow_id, String, null: true, permission: 'organization:integrations:view'

      # NOTE: Api key is a sensitive information. It should not be sent back to the
      #       front end application. Instead we send an obfuscated value
      def api_key
        "#{"•" * 8}…#{object.api_key[-3..]}"
      end

      # def redirect_url
      #   # Logic to generate or return the redirect URL
      #   # "https://example.com/redirect"
      #   object.redirect_url
      # end
      #
      # def flow_id
      #   object.flow_id
      # end
    end
  end
end
