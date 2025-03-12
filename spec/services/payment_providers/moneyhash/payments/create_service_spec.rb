# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentProviders::Moneyhash::Payments::CreateService do
  let(:organization) { create(:organization) }
  let(:moneyhash_provider) { create(:moneyhash_provider, organization:) }
  let(:customer) { create(:customer, organization:) }
  let(:moneyhash_customer) { create(:moneyhash_customer, customer:) }

  let(:reference) { "1234567890" }
  let(:metadata) { {} }

  let(:one_off_payment) { create(:payment, payable: one_off_invoice, payment_provider: moneyhash_provider) }
  let(:one_off_invoice) { create(:invoice, organization:, customer:, invoice_type: :one_off) }

  let(:subscription_invoice) { create(:invoice, organization:, customer:, invoice_type: :subscription) }
  let(:subscription_payment) { create(:payment, payable: subscription_invoice, payment_provider: moneyhash_provider) }

  let(:request_payload) { JSON.parse(File.read("spec/fixtures/moneyhash/recurring_mit_payment_payload.json")) }
  let(:failure_response) { JSON.parse(File.read("spec/fixtures/moneyhash/recurring_mit_payment_failure_response.json")) }
  let(:success_response) { JSON.parse(File.read("spec/fixtures/moneyhash/recurring_mit_payment_success_response.json")) }

  describe "#call" do
    it "fails for non-subscription invoices" do
      result = described_class.call(payment: one_off_payment, reference:, metadata:)
      expect(result).to be_failure
      expect(result.error).to eq("Moneyhash supports automatic payments only for subscription invoices.")
    end

    it "succeeds for a successful payment of subscription invoices" do
      allow_any_instance_of(described_class).to receive(:create_moneyhash_payment).and_return(success_response) # rubocop:disable RSpec/AnyInstance
      result = described_class.call(payment: subscription_payment, reference:, metadata:)
      expect(result).to be_success
      expect(result.payment.status).to eq("PROCESSED") # TODO: payment.status is not an enum, look what you should do here
      expect(result.payment.provider_payment_id).to eq(success_response.dig("data", "id"))
      expect(result.payment.payable_payment_status).to eq("succeeded")
    end

    it "fails for subscription invoices if error raised" do
      allow_any_instance_of(described_class).to receive(:moneyhash_payment_provider).and_return(moneyhash_provider) # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(LagoHttpClient::Client).to receive(:post_with_response).and_raise(LagoHttpClient::HttpError.new(400, failure_response, "")) # rubocop:disable RSpec/AnyInstance
      result = described_class.call(payment: subscription_payment, reference:, metadata:)
      expect(result).to be_failure
      expect(result.error_code).to eq(400)
      expect(result.error_message).to eq(failure_response)
      # subscription_payment.reload
      # expect(subscription_payment.status).to eq("failed")
      # expect(subscription_payment.payable_payment_status).to eq("failed")
    end
  end
end
