# frozen_string_literal: true

module PaymentProviderCustomers
  class MoneyhashService < BaseService
    include Customers::PaymentProviderFinder

    def initialize(moneyhash_customer = nil)
      @moneyhash_customer = moneyhash_customer

      super(nil)
    end

    def create
      result.moneyhash_customer = moneyhash_customer
      return result if moneyhash_customer.provider_customer_id?
      moneyhash_result = create_moneyhash_customer

      return result if !result.success?

      provider_customer_id = begin
        moneyhash_result["data"]["id"]
      rescue
        ""
      end

      moneyhash_customer.update!(
        provider_customer_id: provider_customer_id
      )
      deliver_success_webhook
      result.moneyhash_customer = moneyhash_customer
      result
    end

    def update
      result
    end

    def generate_checkout_url(send_webhook: true)
      result.not_allowed_failure!(code: "feature_not_supported")
    end

    def update_payment_method(organization_id:, customer_id:, payment_method_id:, metadata: {})
      customer = PaymentProviderCustomers::MoneyhashCustomer.find_by(customer_id: customer_id)
      return handle_missing_customer(organization_id, metadata) unless customer

      customer.payment_method_id = payment_method_id
      customer.save!

      result.moneyhash_customer = customer
      result
    rescue ActiveRecord::RecordInvalid => e
      result.record_validation_failure!(record: e.record)
    end

    private

    attr_accessor :moneyhash_customer, :customer

    delegate :customer, to: :moneyhash_customer

    def client
      @client || LagoHttpClient::Client.new("#{PaymentProviders::MoneyhashProvider.api_base_url}/api/v1.1/customers/")
    end

    def moneyhash_payment_provider
      @moneyhash_payment_provider ||= payment_provider(customer)
    end

    def create_moneyhash_customer
      customer_params = {
        type: customer&.customer_type&.upcase,
        first_name: customer&.firstname,
        last_name: customer&.lastname,
        email: customer&.email,
        phone_number: customer&.phone,
        tax_id: customer&.tax_identification_number,
        address: [customer&.address_line1, customer&.address_line2].compact.join(" "),
        contact_person_name: customer&.display_name.presence,
        company_name: customer&.legal_name,
        custom_fields: {
          lago_customer_id: moneyhash_customer.customer_id,
          lago_customer_external_id: moneyhash_customer.customer&.external_id,
          lago_organization_id: moneyhash_customer&.customer&.organization&.id,
          lago_mh_service: "PaymentProviderCustomers::MoneyhashService"
        }
      }.compact

      headers = {
        "Content-Type" => "application/json",
        "x-Api-Key" => moneyhash_payment_provider.api_key
      }

      response = client.post_with_response(customer_params, headers)
      JSON.parse(response.body)
    rescue LagoHttpClient::HttpError => e
      deliver_error_webhook(e)
      nil
    end

    def deliver_error_webhook(moneyhash_error)
      SendWebhookJob.perform_later(
        "customer.payment_provider_error",
        customer,
        provider_error: {
          message: moneyhash_error.message,
          error_code: moneyhash_error.error_code
        }
      )
    end

    def deliver_success_webhook
      SendWebhookJob.perform_later(
        "customer.payment_provider_created",
        customer
      )
    end

    def handle_missing_customer(organization_id, metadata)
      return result unless metadata&.key?("lago_customer_id")
      return result if Customer.find_by(id: metadata["lago_customer_id"], organization_id:).nil?

      result.not_found_failure!(resource: "moneyhash_customer")
    end
  end
end
