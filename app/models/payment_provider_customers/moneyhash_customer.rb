# frozen_string_literal: true

module PaymentProviderCustomers
  class MoneyhashCustomer < BaseCustomer
    settings_accessors :payment_method_id

    # extract MoneyHash's billing data from customer
    def mh_billing_data
      {}.tap do |billing_data|
        billing_data[:name] = customer.name if customer.name.present?
        billing_data[:first_name] = customer.firstname if customer.firstname.present?
        billing_data[:last_name] = customer.lastname if customer.lastname.present?
        billing_data[:email] = customer.email if customer.email.present?
        billing_data[:phone_number] = customer.phone if customer.phone.present?
        billing_data[:address] = customer.address_line1 if customer.address_line1.present?
        billing_data[:address1] = customer.address_line2 if customer.address_line2.present?
        billing_data[:city] = customer.city if customer.city.present?
        billing_data[:state] = customer.state if customer.state.present?
        billing_data[:country] = customer.country if customer.country.present?
        billing_data[:postal_code] = customer.zipcode if customer.zipcode.present?
      end
    end
  end
end

# == Schema Information
#
# Table name: payment_provider_customers
#
#  id                   :uuid             not null, primary key
#  deleted_at           :datetime
#  settings             :jsonb            not null
#  type                 :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  customer_id          :uuid             not null
#  payment_provider_id  :uuid
#  provider_customer_id :string
#
# Indexes
#
#  index_payment_provider_customers_on_customer_id_and_type  (customer_id,type) UNIQUE WHERE (deleted_at IS NULL)
#  index_payment_provider_customers_on_payment_provider_id   (payment_provider_id)
#  index_payment_provider_customers_on_provider_customer_id  (provider_customer_id)
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (payment_provider_id => payment_providers.id)
#
